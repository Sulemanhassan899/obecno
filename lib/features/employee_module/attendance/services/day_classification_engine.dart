enum DayCardType { holiday, worked, onLeave, weekend, absent }

class HolidayInfo {
  final DateTime date;
  final String name;

  const HolidayInfo({required this.date, required this.name});

  DateTime get _dateOnly => DateTime(date.year, date.month, date.day);
}

class DayClassification {
  final DateTime date;
  final DayCardType type;

  final String? holidayName;

  const DayClassification({
    required this.date,
    required this.type,
    this.holidayName,
  });

  bool get isHoliday => type == DayCardType.holiday;
  bool get isOnLeave => type == DayCardType.onLeave;
  bool get isWeekend => type == DayCardType.weekend;
  bool get isWorked => type == DayCardType.worked;
  bool get isAbsent => type == DayCardType.absent;

  @override
  String toString() =>
      'DayClassification(${date.toIso8601String().split('T').first}, '
      '$type${holidayName != null ? ", $holidayName" : ""})';
}

class WorkingDaysParser {
  static const Map<String, int> _weekdayNames = {
    'monday': DateTime.monday,
    'mon': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'tue': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'wed': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'thu': DateTime.thursday,
    'friday': DateTime.friday,
    'fri': DateTime.friday,
    'saturday': DateTime.saturday,
    'sat': DateTime.saturday,
    'sunday': DateTime.sunday,
    'sun': DateTime.sunday,
  };

  static Set<int> parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <int>{};
    return raw
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .map((s) => _weekdayNames[s])
        .whereType<int>()
        .toSet();
  }
}

class DayClassificationEngine {
  DayClassificationEngine._();

  static DayClassification classifyDay({
    required DateTime date,
    required Set<int> workingWeekdays,
    required Set<DateTime> attendanceDates,
    required List<HolidayInfo> holidays,
    Set<DateTime> leaveDates = const {},
  }) {
    final dateOnly = DateTime(date.year, date.month, date.day);

    for (final holiday in holidays) {
      if (holiday._dateOnly == dateOnly) {
        return DayClassification(
          date: dateOnly,
          type: DayCardType.holiday,
          holidayName: holiday.name,
        );
      }
    }

    if (!workingWeekdays.contains(dateOnly.weekday)) {
      return DayClassification(date: dateOnly, type: DayCardType.weekend);
    }

    if (leaveDates.contains(dateOnly)) {
      return DayClassification(date: dateOnly, type: DayCardType.onLeave);
    }

    final hasAttendance = attendanceDates.contains(dateOnly);
    return DayClassification(
      date: dateOnly,
      type: hasAttendance ? DayCardType.worked : DayCardType.absent,
    );
  }

  static List<DayClassification> classifyWeek({
    required DateTime weekStart,
    required Set<int> workingWeekdays,
    required Set<DateTime> attendanceDates,
    required List<HolidayInfo> holidays,
    Set<DateTime> leaveDates = const {},
  }) {
    final monday = weekStart.subtract(
      Duration(days: weekStart.weekday - DateTime.monday),
    );
    final mondayOnly = DateTime(monday.year, monday.month, monday.day);

    return List.generate(7, (i) {
      final day = mondayOnly.add(Duration(days: i));
      return classifyDay(
        date: day,
        workingWeekdays: workingWeekdays,
        attendanceDates: attendanceDates,
        holidays: holidays,
        leaveDates: leaveDates,
      );
    });
  }
}
