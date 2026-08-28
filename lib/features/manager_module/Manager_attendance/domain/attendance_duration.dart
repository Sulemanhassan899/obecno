class AttendanceDuration {
  AttendanceDuration._();

  /// Working hours for a single day: checkout − check-in, or elapsed time
  /// when the shift is still open today.
  static String label({
    required DateTime day,
    String? checkIn,
    String? checkOut,
    String? hoursWorked,
    String? actualHours,
    int? actualMinutes,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final start = combine(day, checkIn);
    final end = combine(day, checkOut);

    if (start != null && end != null && !end.isBefore(start)) {
      return format(end.difference(start));
    }

    if (start != null && end == null && _isSameDay(day, clock)) {
      final elapsed = clock.difference(start);
      if (!elapsed.isNegative) return format(elapsed);
    }

    final fromWorked = fromClock(hoursWorked);
    if (fromWorked != null && fromWorked != '0h 00m') return fromWorked;

    final fromActual = fromClock(actualHours);
    if (fromActual != null && fromActual != '0h 00m') return fromActual;

    if (actualMinutes != null && actualMinutes > 0) {
      return format(Duration(minutes: actualMinutes));
    }

    if (fromWorked != null) return fromWorked;
    if (fromActual != null) return fromActual;
    return '0h 00m';
  }

  static String format(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final hours = safe.inHours;
    final minutes = safe.inMinutes.remainder(60);
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  static String? fromClock(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (RegExp(r'^\d+h\s*\d+m$').hasMatch(value)) return value;

    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hours = int.tryParse(parts[0].trim());
    final minutes = int.tryParse(parts[1].trim());
    if (hours == null || minutes == null) return null;
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  static DateTime? combine(DateTime day, String? raw) {
    final minutes = parseMinutes(raw);
    if (minutes == null) return null;
    return DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
  }

  static int? parseMinutes(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;

    final ampm = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (ampm != null) {
      var hour = int.parse(ampm.group(1)!);
      final minute = int.parse(ampm.group(2)!);
      final period = ampm.group(4)!.toUpperCase();
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return hour * 60 + minute;
    }

    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
