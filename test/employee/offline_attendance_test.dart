import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/core/services/network_checker.dart';
import 'package:obecno/core/services/token_service.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:obecno/features/employee_module/attendance/repositories/attendance_repository.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';
import 'package:obecno/features/more/data/models/employee_profile_model.dart';
import 'package:obecno/features/manager_module/Manager_overview/domain/overview_summary.dart';
import 'package:obecno/shared/location/data/location_model.dart';
import 'package:obecno/shared/location/service/attendance_connectivity_service.dart';
import 'package:obecno/shared/location/service/attendance_payload_model.dart';
import 'package:obecno/features/clock/repositories/clock_attendance_repository.dart';

import 'helpers/in_memory_local_queue.dart';

class _OfflineNetwork implements NetworkChecker {
  @override
  Future<bool> get isConnected async => false;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

class _AlwaysOffline implements AttendanceConnectivityService {
  @override
  Future<bool> isOnline() async => false;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

HistoryAttendanceRepository _historyRepo() {
  return HistoryAttendanceRepository(
    AttendanceService(
      ApiClient(
        networkChecker: _OfflineNetwork(),
        tokenService: TokenService(),
      ),
    ),
    userIdProvider: () => 'user-1',
    joiningDateProvider: () => DateTime(2026, 1, 1),
  );
}

void main() {
  group('Offline attendance month cards', () {
    test('builds day tiles for the elapsed month without network', () {
      final result = _historyRepo().monthFromLocalDays(
        DateTime(2026, 9, 1),
        today: DateTime(2026, 9, 14),
      );

      expect(result.records, isNotEmpty);
      expect(result.records.length, 14);
      expect(result.summary.totalDays, greaterThan(0));
      expect(
        result.records.any(
          (record) =>
              record.status == AttendanceDayStatus.absent ||
              record.status == AttendanceDayStatus.weekend,
        ),
        isTrue,
      );
    });

    test('keeps a locally recorded check-in in the fallback month', () {
      final result = _historyRepo().monthFromLocalDays(
        DateTime(2026, 9, 1),
        today: DateTime(2026, 9, 14),
        days: [
          AttendanceDay(
            date: DateTime(2026, 9, 14),
            checkIns: const ['08:56:00'],
          ),
        ],
      );

      final today = result.records.firstWhere(
        (record) =>
            record.date.year == 2026 &&
            record.date.month == 9 &&
            record.date.day == 14,
      );
      expect(today.checkIn, isNotNull);
      expect(today.status, isNot(AttendanceDayStatus.absent));
    });
  });

  group('Offline clock queue', () {
    test('queues a check-in when the device has no internet', () async {
      final queue = InMemoryLocalQueue()..currentUserId = 'user-1';
      final repo = AttendanceRepository(
        ApiClient(
          networkChecker: _OfflineNetwork(),
          tokenService: TokenService(),
        ),
        _AlwaysOffline(),
        queue,
      );

      final result = await repo.submitAttendance(
        AttendancePayloadModel(
          action: AttendanceAction.checkIn,
          capturedAt: DateTime(2026, 9, 14, 8, 56),
          location: const LocationModel(lat: 31.52, lon: 74.35),
          requestId: 'offline-checkin-1',
        ),
      );

      expect(result.synced, isFalse);
      expect(await queue.getPending(), hasLength(1));
      expect(
        (await queue.getPending()).single.payload.action,
        AttendanceAction.checkIn,
      );
    });
  });

  group('Offline profile + manager empty cards', () {
    test('profile cache json keeps photo url and address', () {
      const profile = EmployeeProfileModel(
        id: '22',
        name: 'Naveed Ramzan',
        email: 'naveed@naxovatetechnologies.com',
        photoUrl: 'https://cdn.example.com/naveed.jpg',
        phone: '+923335430621',
        employeeCode: '22',
        address: 'House 70, Street 28, Phase 1, Pakistan Town, Islamabad',
      );

      final restored = EmployeeProfileModel.fromJson(profile.toCacheJson());
      expect(restored.name, 'Naveed Ramzan');
      expect(restored.photoUrl, 'https://cdn.example.com/naveed.jpg');
      expect(restored.address, contains('Pakistan Town'));
      expect(restored.phone, '+923335430621');
    });

    test('manager overview empty summary still has zeroed card values', () {
      expect(OverviewSummary.empty.presentToday, 0);
      expect(OverviewSummary.empty.totalTeamMembers, 0);
      expect(OverviewSummary.empty.active, 0);
      expect(OverviewSummary.empty.onBreak, 0);
      expect(OverviewSummary.empty.lateCheckIn, 0);
      expect(OverviewSummary.empty.absent, 0);
    });
  });
}
