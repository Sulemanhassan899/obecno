import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkingDaysParser', () {
    test('parses weekday names', () {
      final days = WorkingDaysParser.parse('Mon, Tue, Wed, Thu, Fri');
      expect(days, containsAll([DateTime.monday, DateTime.friday]));
      expect(days.contains(DateTime.sunday), isFalse);
    });
  });

  group('DayClassificationEngine', () {
    final working = {DateTime.monday, DateTime.tuesday, DateTime.wednesday,
        DateTime.thursday, DateTime.friday};

    test('marks weekend', () {
      final sat = DateTime(2026, 8, 15); // Saturday
      final result = DayClassificationEngine.classifyDay(
        date: sat,
        workingWeekdays: working,
        attendanceDates: {},
        holidays: const [],
      );
      expect(result.type, DayCardType.weekend);
    });

    test('marks holiday over weekend', () {
      final day = DateTime(2026, 8, 14); // Friday
      final result = DayClassificationEngine.classifyDay(
        date: day,
        workingWeekdays: working,
        attendanceDates: {},
        holidays: [HolidayInfo(date: day, name: 'Independence')],
      );
      expect(result.type, DayCardType.holiday);
      expect(result.holidayName, 'Independence');
    });

    test('marks worked vs absent', () {
      final day = DateTime(2026, 8, 17); // Monday
      final worked = DayClassificationEngine.classifyDay(
        date: day,
        workingWeekdays: working,
        attendanceDates: {DateTime(2026, 8, 17)},
        holidays: const [],
      );
      final absent = DayClassificationEngine.classifyDay(
        date: day,
        workingWeekdays: working,
        attendanceDates: {},
        holidays: const [],
      );
      expect(worked.type, DayCardType.worked);
      expect(absent.type, DayCardType.absent);
    });

    test('marks approved leave separately from absent', () {
      final day = DateTime(2026, 8, 17);
      final result = DayClassificationEngine.classifyDay(
        date: day,
        workingWeekdays: working,
        attendanceDates: {},
        holidays: const [],
        leaveDates: {DateTime(2026, 8, 17)},
      );
      expect(result.type, DayCardType.onLeave);
    });
  });

  group('AttendanceListGrouping', () {
    test('keeps holidays as their own cards and only groups weekends', () {
      final grouped = AttendanceListGrouping.groupConsecutiveWeekends([
        AttendanceDayRecord(
          day: 14,
          weekday: 'Fri',
          date: DateTime(2026, 8, 14),
          status: AttendanceDayStatus.holiday,
          weekendLabel: 'National Day',
        ),
        AttendanceDayRecord(
          day: 15,
          weekday: 'Sat',
          date: DateTime(2026, 8, 15),
          status: AttendanceDayStatus.weekend,
        ),
        AttendanceDayRecord(
          day: 16,
          weekday: 'Sun',
          date: DateTime(2026, 8, 16),
          status: AttendanceDayStatus.weekend,
        ),
      ]);

      expect(grouped, hasLength(2));
      expect(grouped.last.status, AttendanceDayStatus.holiday);
      expect(grouped.last.weekendLabel, 'National Day');
      expect(grouped.first.status, AttendanceDayStatus.weekend);
      expect(grouped.first.weekendLabel, 'Weekend, 15 Aug 2026 - 16 Aug 2026');
    });
  });
}
