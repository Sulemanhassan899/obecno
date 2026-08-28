import 'dart:async';

import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/services/network_checker.dart';
import 'package:obecno/core/services/token_service.dart';
import 'package:obecno/features/clock/repositories/clock_attendance_repository.dart';
import 'package:obecno/features/clock/services/sync_service.dart';
import 'package:obecno/shared/location/data/location_model.dart';
import 'package:obecno/shared/location/service/attendance_connectivity_service.dart';
import 'package:obecno/shared/location/service/attendance_payload_model.dart';
import 'package:obecno/shared/location/service/geofence_helper.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/in_memory_local_queue.dart';

class _AlwaysOnline implements AttendanceConnectivityService {
  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

class _FakeNetwork implements NetworkChecker {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

ApiClient _unusedClient() =>
    ApiClient(networkChecker: _FakeNetwork(), tokenService: TokenService());

/// Real subtype so SyncService accepts it; only [sendQueuedPayload] is used.
class _RecordingRepo extends AttendanceRepository {
  _RecordingRepo({
    this.delay = Duration.zero,
    this.throwBusiness = false,
    this.throwNetworkOnIds = const {},
  }) : super(_unusedClient(), _AlwaysOnline(), InMemoryLocalQueue());

  final Duration delay;
  final bool throwBusiness;
  final Set<String> throwNetworkOnIds;
  final List<String> sentRequestIds = [];
  final List<AttendancePayloadModel> sentPayloads = [];

  @override
  Future<String?> sendQueuedPayload(
    AttendancePayloadModel payload, {
    dynamic cancelToken,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (throwBusiness) {
      throw AttendanceBusinessException('not allowed');
    }
    if (throwNetworkOnIds.contains(payload.requestId)) {
      throw AttendanceApiException('connection lost');
    }
    sentRequestIds.add(payload.requestId);
    sentPayloads.add(payload);
    return 'synced';
  }
}

void main() {
  group('Employee offline queue scoping', () {
    test('punch is rejected when no user is signed in', () async {
      final queue = InMemoryLocalQueue();
      final punch = AttendancePayloadModel(
        action: AttendanceAction.checkIn,
        capturedAt: DateTime(2026, 8, 20, 9),
        location: const LocationModel(lat: 33.67, lon: 73.07),
        requestId: 'req-1',
        deviceDetails: 'Test | Android',
      );
      expect(await queue.insert(punch), isFalse);
    });

    test('User B never sees User A pending punches', () async {
      final queue = InMemoryLocalQueue()..currentUserId = 'emp-A';
      await queue.insert(
        AttendancePayloadModel(
          action: AttendanceAction.checkIn,
          capturedAt: DateTime(2026, 8, 20, 9),
          location: const LocationModel(lat: 33.67, lon: 73.07),
          requestId: 'a-1',
          deviceDetails: 'A',
        ),
      );

      queue.currentUserId = 'emp-B';
      expect(await queue.getPending(), isEmpty);

      queue.currentUserId = 'emp-A';
      expect(await queue.getPending(), hasLength(1));
    });

    test('clearAll on logout wipes offline punches', () async {
      final queue = InMemoryLocalQueue()..currentUserId = 'emp-1';
      await queue.insert(
        AttendancePayloadModel(
          action: AttendanceAction.checkIn,
          capturedAt: DateTime(2026, 8, 20, 9),
          requestId: 'wipe-1',
          deviceDetails: 'Test',
        ),
      );
      await queue.clearAll();
      expect(await queue.getPending(), isEmpty);
    });
  });

  group('Employee geofence gate before clock', () {
    test('in-office vs out-of-office', () {
      const office = GeoPoint(lat: 33.67, lon: 73.07);
      final inside = GeofenceHelper.evaluate(
        companyLocation: office,
        user: const GeoPoint(lat: 33.67005, lon: 73.07005),
        radiusMeters: 100,
      );
      final outside = GeofenceHelper.evaluate(
        companyLocation: office,
        user: const GeoPoint(lat: 34.0, lon: 74.0),
        radiusMeters: 50,
      );
      expect(inside.isInside, isTrue);
      expect(outside.isInside, isFalse);
    });
  });

  group('Employee sync after reconnect', () {
    test('online sync sends queued check-in once and drains queue', () async {
      final queue = InMemoryLocalQueue()..currentUserId = 'emp-1';
      final fakeRepo = _RecordingRepo();
      await queue.insert(
        AttendancePayloadModel(
          action: AttendanceAction.checkIn,
          capturedAt: DateTime(2026, 8, 20, 10),
          location: const LocationModel(lat: 33.67, lon: 73.07),
          requestId: 'harness-1',
          deviceDetails: 'Test',
        ),
      );

      final sync = SyncService(
        fakeRepo,
        _AlwaysOnline(),
        queue,
        sessionEpochProvider: () => 7,
        userIdProvider: () => 'emp-1',
      );

      await sync.syncPendingData();

      expect(fakeRepo.sentRequestIds, ['harness-1']);
      expect(await queue.getPending(), isEmpty);
      expect(sync.state, SyncState.idle);
    });

    test(
      'session epoch change mid-sync does not fire onSyncCompleted',
      () async {
        var epoch = 1;
        final queue = InMemoryLocalQueue()..currentUserId = 'emp-1';
        final fakeRepo = _RecordingRepo(
          delay: const Duration(milliseconds: 40),
        );
        await queue.insert(
          AttendancePayloadModel(
            action: AttendanceAction.checkOut,
            capturedAt: DateTime(2026, 8, 20, 18),
            location: const LocationModel(lat: 33.67, lon: 73.07),
            requestId: 'epoch-1',
            deviceDetails: 'Test',
          ),
        );

        var completed = false;
        final sync = SyncService(
          fakeRepo,
          _AlwaysOnline(),
          queue,
          sessionEpochProvider: () => epoch,
          userIdProvider: () => 'emp-1',
        )..onSyncCompleted = () => completed = true;

        final future = sync.syncPendingData();
        epoch = 2;
        await future;

        expect(completed, isFalse);
      },
    );

    test('business rejection dead-letters the punch', () async {
      final queue = InMemoryLocalQueue()..currentUserId = 'emp-1';
      final fakeRepo = _RecordingRepo(throwBusiness: true);
      await queue.insert(
        AttendancePayloadModel(
          action: AttendanceAction.breakStart,
          capturedAt: DateTime(2026, 8, 20, 13),
          location: const LocationModel(lat: 33.67, lon: 73.07),
          requestId: 'dead-1',
          deviceDetails: 'Test',
        ),
      );

      final sync = SyncService(
        fakeRepo,
        _AlwaysOnline(),
        queue,
        sessionEpochProvider: () => 1,
        userIdProvider: () => 'emp-1',
      );

      await sync.syncPendingData();

      expect(await queue.getPending(), isEmpty);
      expect(await queue.getDeadLetterCount(), 1);
    });
  });

  group('Employee clock payload (login device → API)', () {
    test('API body includes action, device, datetime, lat/lon', () {
      final payload = AttendancePayloadModel(
        action: AttendanceAction.checkIn,
        capturedAt: DateTime(2026, 8, 20, 9, 15, 30),
        location: const LocationModel(lat: 33.5, lon: 73.1),
        requestId: 'body-1',
        deviceDetails: 'Pixel | Android 14',
      );
      final json = payload.toApiJson();
      expect(json['action'], 'checkin');
      expect(json['device_details'], 'Pixel | Android 14');
      expect(json['datetime'], '2026-08-20 09:15:30');
      expect(json['lat'], 33.5);
      expect(json['lon'], 73.1);
    });

    test('queue round-trip keeps original wall-clock, not parse-as-UTC', () {
      final original = AttendancePayloadModel(
        action: AttendanceAction.checkIn,
        capturedAt: DateTime(2026, 8, 21, 9, 0, 45),
        requestId: 'round-1',
        deviceDetails: 'Test',
      );
      final row = original.toQueueMap();
      // Simulate a UTC created_at that would shift the hour if trusted alone.
      row['created_at'] = DateTime.utc(2026, 8, 21, 4, 0, 45).toIso8601String();

      final restored = AttendancePayloadModel.fromQueueMap(row);
      expect(restored.date, '2026-08-21');
      expect(restored.time, '09:00');
      expect(restored.datetime, '2026-08-21 09:00:45');
      expect(restored.toApiJson()['datetime'], '2026-08-21 09:00:45');
    });
  });

  group('Offline multi-day queue and date-aware sync', () {
    AttendancePayloadModel punch({
      required String action,
      required DateTime at,
      required String requestId,
    }) {
      return AttendancePayloadModel(
        action: action,
        capturedAt: at,
        location: const LocationModel(lat: 33.67, lon: 73.07),
        requestId: requestId,
        deviceDetails: 'Test',
      );
    }

    test(
      'later days append and never overwrite earlier pending days',
      () async {
        final queue = InMemoryLocalQueue()..currentUserId = 'emp-1';

        await queue.insert(
          punch(
            action: AttendanceAction.checkIn,
            at: DateTime(2026, 8, 21, 9),
            requestId: 'd21-in',
          ),
        );
        await queue.insert(
          punch(
            action: AttendanceAction.checkOut,
            at: DateTime(2026, 8, 21, 18),
            requestId: 'd21-out',
          ),
        );
        await queue.insert(
          punch(
            action: AttendanceAction.checkIn,
            at: DateTime(2026, 8, 22, 9),
            requestId: 'd22-in',
          ),
        );

        final pending = await queue.getPending();
        expect(pending, hasLength(3));
        expect(pending.map((e) => e.payload.requestId).toList(), [
          'd21-in',
          'd21-out',
          'd22-in',
        ]);
        expect(pending[0].payload.date, '2026-08-21');
        expect(pending[2].payload.date, '2026-08-22');
      },
    );

    test('duplicate request_id is not inserted twice', () async {
      final queue = InMemoryLocalQueue()..currentUserId = 'emp-1';
      final first = punch(
        action: AttendanceAction.checkIn,
        at: DateTime(2026, 8, 21, 9),
        requestId: 'same-id',
      );
      expect(await queue.insert(first), isTrue);
      expect(await queue.insert(first), isTrue);
      expect(await queue.getPending(), hasLength(1));
    });

    test('sync sends original dates after a later reconnect day', () async {
      final queue = InMemoryLocalQueue()..currentUserId = 'emp-1';
      final fakeRepo = _RecordingRepo();

      for (var day = 21; day <= 27; day++) {
        await queue.insert(
          punch(
            action: AttendanceAction.checkIn,
            at: DateTime(2026, 8, day, 9),
            requestId: 'aug$day-in',
          ),
        );
        await queue.insert(
          punch(
            action: AttendanceAction.checkOut,
            at: DateTime(2026, 8, day, 18),
            requestId: 'aug$day-out',
          ),
        );
      }

      final sync = SyncService(
        fakeRepo,
        _AlwaysOnline(),
        queue,
        sessionEpochProvider: () => 1,
        userIdProvider: () => 'emp-1',
      );
      await sync.syncPendingData();

      expect(fakeRepo.sentPayloads, hasLength(14));
      expect(fakeRepo.sentPayloads.map((p) => p.datetime).toList(), [
        for (var day = 21; day <= 27; day++) ...[
          '2026-08-$day 09:00:00',
          '2026-08-$day 18:00:00',
        ],
      ]);
      expect(fakeRepo.sentPayloads.any((p) => p.date == '2026-08-28'), isFalse);
      expect(await queue.getPending(), isEmpty);
    });

    test('partial failure keeps only the failed record pending', () async {
      final queue = InMemoryLocalQueue()..currentUserId = 'emp-1';
      final fakeRepo = _RecordingRepo(throwNetworkOnIds: {'r4'});

      for (var i = 1; i <= 5; i++) {
        await queue.insert(
          punch(
            action: AttendanceAction.checkIn,
            at: DateTime(2026, 1, i, 9),
            requestId: 'r$i',
          ),
        );
      }

      final sync = SyncService(
        fakeRepo,
        _AlwaysOnline(),
        queue,
        sessionEpochProvider: () => 1,
        userIdProvider: () => 'emp-1',
      );
      await sync.syncPendingData();

      final pending = await queue.getPending();
      expect(pending, hasLength(1));
      expect(pending.single.payload.requestId, 'r4');
      expect(pending.single.payload.date, '2026-01-04');
      expect(fakeRepo.sentRequestIds, ['r1', 'r2', 'r3', 'r5']);
      expect(await queue.getDeadLetterCount(), 0);
    });

    test('retryable network errors stay pending, not dead-lettered', () async {
      final queue = InMemoryLocalQueue()..currentUserId = 'emp-1';
      final fakeRepo = _RecordingRepo(throwNetworkOnIds: {'net-1'});
      await queue.insert(
        punch(
          action: AttendanceAction.checkIn,
          at: DateTime(2026, 8, 21, 9),
          requestId: 'net-1',
        ),
      );

      final sync = SyncService(
        fakeRepo,
        _AlwaysOnline(),
        queue,
        sessionEpochProvider: () => 1,
        userIdProvider: () => 'emp-1',
      );

      await sync.syncPendingData();

      expect(await queue.getPending(), hasLength(1));
      expect(await queue.getDeadLetterCount(), 0);
    });

    test('months of pending rows keep their own dates', () async {
      final queue = InMemoryLocalQueue()..currentUserId = 'emp-1';
      final fakeRepo = _RecordingRepo();

      await queue.insert(
        punch(
          action: AttendanceAction.checkIn,
          at: DateTime(2026, 1, 15, 9),
          requestId: 'jan',
        ),
      );
      await queue.insert(
        punch(
          action: AttendanceAction.checkIn,
          at: DateTime(2026, 4, 15, 9),
          requestId: 'apr',
        ),
      );

      final sync = SyncService(
        fakeRepo,
        _AlwaysOnline(),
        queue,
        sessionEpochProvider: () => 1,
        userIdProvider: () => 'emp-1',
      );
      await sync.syncPendingData();

      expect(fakeRepo.sentPayloads.map((p) => p.date).toList(), [
        '2026-01-15',
        '2026-04-15',
      ]);
    });
  });
}
