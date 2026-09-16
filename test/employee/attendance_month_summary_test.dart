import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/services/network_checker.dart';
import 'package:obecno/core/services/token_service.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:obecno/features/employee_module/attendance/repositories/attendance_repository.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_employee_attendance_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/employee_attendance_history_mapper.dart';

class _OfflineNetwork implements NetworkChecker {
  @override
  Future<bool> get isConnected async => false;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

HistoryAttendanceRepository _repo() {
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
  group('Employee month working-days summary', () {
    test('Sept 1–14 2026 Mon–Fri is 10 expected days and ignores weekend punches', () {
      final result = _repo().monthFromLocalDays(
        DateTime(2026, 9, 1),
        today: DateTime(2026, 9, 14),
        days: [
          for (final day in [1, 2, 3, 4, 7, 8, 9, 10, 11, 14])
            AttendanceDay(
              date: DateTime(2026, 9, day),
              checkIns: const ['09:00:00'],
              checkOuts: const ['18:00:00'],
            ),
          AttendanceDay(
            date: DateTime(2026, 9, 12),
            checkIns: const ['10:00:00'],
            checkOuts: const ['14:00:00'],
          ),
        ],
      );

      expect(result.summary.totalDays, 10);
      expect(result.summary.workingDays, 10);
      expect(result.summary.workingDays, lessThanOrEqualTo(result.summary.totalDays));
      expect(result.summary.absentOrLeaves, 0);
    });

    test('placeholder mint punches do not count as working days', () {
      final result = _repo().monthFromLocalDays(
        DateTime(2026, 9, 1),
        today: DateTime(2026, 9, 14),
        days: [
          AttendanceDay(
            date: DateTime(2026, 9, 14),
            checkIns: const ['00:00:00'],
            checkOuts: const ['00:01:00'],
            isEdited: true,
          ),
        ],
      );

      expect(result.summary.totalDays, 10);
      expect(result.summary.workingDays, 0);
      expect(result.summary.absentOrLeaves, 10);
    });

    test('absent weekdays increase absent count, not working days', () {
      final result = _repo().monthFromLocalDays(
        DateTime(2026, 9, 1),
        today: DateTime(2026, 9, 14),
        days: [
          AttendanceDay(
            date: DateTime(2026, 9, 14),
            checkIns: const ['09:00:00'],
            checkOuts: const ['18:00:00'],
          ),
        ],
      );

      expect(result.summary.totalDays, 10);
      expect(result.summary.workingDays, 1);
      expect(result.summary.absentOrLeaves, 9);
    });
  });

  group('Manager employee history working-days summary', () {
    test('weekend punches do not inflate working days past expected weekdays', () {
      final month = ManagerEmployeeHistoryMapper.build(
        month: DateTime(2026, 8, 1),
        history: [
          for (final day in [10, 11, 12, 13, 14, 15, 16])
            ManagerEmployeeAttendanceDay(
              date: DateTime(2026, 8, day),
              checkin: '09:00:00',
              checkout: '18:00:00',
            ),
        ],
      );

      expect(month.summary.workingDays, 5);
      expect(month.summary.workingDays, lessThanOrEqualTo(month.summary.totalDays));
      expect(month.summary.totalDays, greaterThan(month.summary.workingDays));
    });
  });
}
