import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:obecno/features/employee_module/attendance/data/models/employee_leave.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmployeeLeave', () {
    test('parses approved sick leave ranges from the employee leaves API', () {
      final leaves = EmployeeLeave.listFrom({
        'data': {
          'leaves': [
            {
              'id': 3,
              'leave_type': 'Sick leave',
              'status': 'approved',
              'from_date': '2026-09-08',
              'to_date': '2026-09-09',
            },
            {
              'id': 4,
              'leave_type': 'Annual',
              'status': 'pending',
              'from_date': '2026-09-14',
              'to_date': '2026-09-15',
            },
          ],
        },
      });

      expect(leaves, hasLength(2));
      expect(leaves.first.isApproved, isTrue);
      expect(leaves.last.isApproved, isFalse);

      final dates = EmployeeLeaveDates.approvedDates(leaves);
      expect(dates, {DateTime(2026, 9, 8), DateTime(2026, 9, 9)});
    });
  });

  group('EmployeeLeaveDates.overlay', () {
    test('keeps punches on a leave day and marks the day as leave', () {
      final punched = AttendanceDay(
        date: DateTime(2026, 9, 8),
        checkIns: const ['14:04:00'],
      );

      final overlayed = EmployeeLeaveDates.overlay(
        [punched],
        {DateTime(2026, 9, 8), DateTime(2026, 9, 9)},
      );

      final eighth = overlayed.firstWhere((day) => day.date.day == 8);
      final ninth = overlayed.firstWhere((day) => day.date.day == 9);

      expect(eighth.isLeave, isTrue);
      expect(eighth.checkIns, ['14:04:00']);
      expect(ninth.isLeave, isTrue);
      expect(ninth.checkIns, isEmpty);
    });
  });

  group('AttendanceCalendarData leave dates', () {
    test('reads leave status from calendar day entries', () {
      final calendar = AttendanceCalendarData.fromJson({
        'month_label': 'September 2026',
        'attendance_dates': [
          {'date': '2026-09-08', 'day_status': 'leave', 'is_leave': true},
          {'date': '2026-09-07', 'day_status': 'present'},
        ],
      });

      expect(calendar.leaveDates, [DateTime(2026, 9, 8)]);
      expect(calendar.attendanceDates, hasLength(2));
    });
  });
}
