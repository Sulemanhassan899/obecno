import 'dart:async';

import 'package:Obecno/core/api/api_client.dart';
import 'package:Obecno/core/services/network_checker.dart';
import 'package:Obecno/core/services/token_service.dart';
import 'package:Obecno/features/clock/repositories/clock_attendance_repository.dart';
import 'package:Obecno/features/clock/services/sync_service.dart';
import 'package:Obecno/shared/location/data/location_model.dart';
import 'package:Obecno/shared/location/service/attendance_connectivity_service.dart';
import 'package:Obecno/shared/location/service/attendance_payload_model.dart';
import 'package:Obecno/shared/location/service/geofence_helper.dart';
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

ApiClient _unusedClient() => ApiClient(
      networkChecker: _FakeNetwork(),
      tokenService: TokenService(),
    );

/// Real subtype so SyncService accepts it; only [sendQueuedPayload] is used.
class _RecordingRepo extends AttendanceRepository {
  _RecordingRepo({
    this.delay = Duration.zero,
    this.throwBusiness = false,
  }) : super(_unusedClient(), _AlwaysOnline(), InMemoryLocalQueue());

  final Duration delay;
  final bool throwBusiness;
  final List<String> sentRequestIds = [];

  @override
  Future<String?> sendQueuedPayload(
    AttendancePayloadModel payload, {
    dynamic cancelToken,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (throwBusiness) {
      throw AttendanceBusinessException('not allowed');
    }
    sentRequestIds.add(payload.requestId);
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

    test('session epoch change mid-sync does not fire onSyncCompleted', () async {
      var epoch = 1;
      final queue = InMemoryLocalQueue()..currentUserId = 'emp-1';
      final fakeRepo = _RecordingRepo(delay: const Duration(milliseconds: 40));
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
    });

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
  });
}
