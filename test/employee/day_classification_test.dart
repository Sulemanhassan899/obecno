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

    test('marks worked vs on leave', () {
      final day = DateTime(2026, 8, 17); // Monday
      final worked = DayClassificationEngine.classifyDay(
        date: day,
        workingWeekdays: working,
        attendanceDates: {DateTime(2026, 8, 17)},
        holidays: const [],
      );
      final leave = DayClassificationEngine.classifyDay(
        date: day,
        workingWeekdays: working,
        attendanceDates: {},
        holidays: const [],
      );
      expect(worked.type, DayCardType.worked);
      expect(leave.type, DayCardType.onLeave);
    });
  });
}
