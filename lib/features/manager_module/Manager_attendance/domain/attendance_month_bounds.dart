class AttendanceMonthBounds {
  AttendanceMonthBounds._();

  static DateTime monthOnly(DateTime date) => DateTime(date.year, date.month);

  static DateTime? dateOnly(DateTime? date) {
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day);
  }

  /// First selectable attendance month (the month containing [joiningDate]).
  static DateTime? minimumMonth(DateTime? joiningDate) {
    final join = dateOnly(joiningDate);
    if (join == null) return null;
    return DateTime(join.year, join.month);
  }

  static bool canGoPrevious({
    required DateTime selectedMonth,
    DateTime? joiningDate,
  }) {
    final min = minimumMonth(joiningDate);
    if (min == null) return true;
    return monthOnly(selectedMonth).isAfter(min);
  }

  static bool canGoNext({required DateTime selectedMonth, DateTime? now}) {
    return monthOnly(selectedMonth).isBefore(monthOnly(now ?? DateTime.now()));
  }

  static DateTime clampMonth({
    required DateTime selectedMonth,
    DateTime? joiningDate,
    DateTime? now,
  }) {
    var target = monthOnly(selectedMonth);
    final currentMonth = monthOnly(now ?? DateTime.now());
    if (target.isAfter(currentMonth)) target = currentMonth;

    final min = minimumMonth(joiningDate);
    if (min != null && target.isBefore(min)) target = min;
    return target;
  }
}
