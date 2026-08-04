
class BreakSession {
  const BreakSession({
    required this.breakIn,
    required this.breakOut,
    this.breakInLocation,
    this.breakOutLocation,
  });

  /// Raw "HH:mm:ss" (or "HH:mm") time string, 24-hour, as returned by the API.
  final String breakIn;
  final String breakOut;

  /// Raw "lat,lon" string for each side of the break, if the API provided one.
  final String? breakInLocation;
  final String? breakOutLocation;

  @override
  String toString() => 'BreakSession($breakIn -> $breakOut)';
}

class AttendanceDay {
  const AttendanceDay({
    required this.date,
    this.recordId,
    this.checkIns = const [],
    this.checkOuts = const [],
    this.checkInLocations = const [],
    this.checkOutLocations = const [],
    this.breaks = const [],
    this.isEdited = false,
  });

  final DateTime date;
  final int? recordId;
  final List<String> checkIns;
  final List<String> checkOuts;

  /// Raw "lat,lon" strings, index-aligned with [checkIns] / [checkOuts].
  final List<String?> checkInLocations;
  final List<String?> checkOutLocations;
  final List<BreakSession> breaks;

  final bool isEdited;

  String? get firstCheckIn => checkIns.isEmpty ? null : checkIns.first;
  String? get lastCheckOut => checkOuts.isEmpty ? null : checkOuts.last;

  String? get firstCheckInLocation =>
      checkInLocations.isEmpty ? null : checkInLocations.first;
  String? get lastCheckOutLocation =>
      checkOutLocations.isEmpty ? null : checkOutLocations.last;

  bool get hasCheckIn => firstCheckIn != null;
  bool get hasCheckOut => lastCheckOut != null;

  bool get isComplete => hasCheckIn && hasCheckOut;

  bool get hasMissingData => !hasCheckIn || !hasCheckOut;

  factory AttendanceDay.fromApiHistoryItem(Map<String, dynamic> json) {
    final date = _parseDate(json['date']) ?? DateTime.now();

    final detailsRaw = json['attendance_details'];
    final hasDetails = detailsRaw is List && detailsRaw.isNotEmpty;

    final checkIns = <String>[];
    final checkInLocations = <String?>[];
    final checkOuts = <String>[];
    final checkOutLocations = <String?>[];
    final breaks = <BreakSession>[];

    if (hasDetails) {
      String? pendingBreakOutTime;
      String? pendingBreakOutLocation;

      for (final raw in detailsRaw) {
        if (raw is! Map) continue;
        final detail = Map<String, dynamic>.from(raw);
        final time = _normalizedTime(detail['attendance_time']);
        if (time == null) continue;
        final location = _normalizedLocation(detail['current_location']);

        switch ((detail['type'] as String?)?.trim().toLowerCase()) {
          case 'check in':
            checkIns.add(time);
            checkInLocations.add(location);
            break;
          case 'check out':
            checkOuts.add(time);
            checkOutLocations.add(location);
            break;
          case 'break out':
            pendingBreakOutTime = time;
            pendingBreakOutLocation = location;
            break;
          case 'break in':
            if (pendingBreakOutTime != null) {
              breaks.add(
                BreakSession(
                  breakIn: time,
                  breakOut: pendingBreakOutTime,
                  breakInLocation: location,
                  breakOutLocation: pendingBreakOutLocation,
                ),
              );
              pendingBreakOutTime = null;
              pendingBreakOutLocation = null;
            }
            break;
        }
      }
    } else {
      // No per-event breakdown (e.g. "today_attendance") -- fall back to the
      // single top-level fields, all sharing the one reported location.
      final checkin = _normalizedTime(json['checkin']);
      final checkout = _normalizedTime(json['checkout']);
      final breakin = _normalizedTime(json['breakin']);
      final breakout = _normalizedTime(json['breakout']);
      final location = _normalizedLocation(json['current_location']);

      if (checkin != null) {
        checkIns.add(checkin);
        checkInLocations.add(location);
      }
      if (checkout != null) {
        checkOuts.add(checkout);
        checkOutLocations.add(location);
      }
      if (breakin != null && breakout != null) {
        breaks.add(
          BreakSession(
            breakIn: breakin,
            breakOut: breakout,
            breakInLocation: location,
            breakOutLocation: location,
          ),
        );
      }
    }

    return AttendanceDay(
      date: DateTime(date.year, date.month, date.day),
      recordId: _parseId(json['id']),
      checkIns: checkIns,
      checkOuts: checkOuts,
      checkInLocations: checkInLocations,
      checkOutLocations: checkOutLocations,
      breaks: breaks,
      isEdited: false,
    );
  }

  static int? _parseId(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static String? _normalizedTime(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Normalizes the API's "lat,lon" location string. Treats "0,0" (a common
  /// "no fix" sentinel) and empty/null the same as no location at all.
  static String? _normalizedLocation(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (s == '0,0' || s == '0.0,0.0') return null;
    return s;
  }

  @override
  String toString() =>
      'AttendanceDay(date: $date, in: $checkIns, out: $checkOuts, breaks: $breaks)';
}

class AttendanceHistoryData {
  const AttendanceHistoryData({
    this.today,
    this.todayAttendance,
    this.history = const [],
  });

  final DateTime? today;
  final AttendanceDay? todayAttendance;
  final List<AttendanceDay> history;

  factory AttendanceHistoryData.fromJson(Map<String, dynamic> json) {
    final today = AttendanceDay._parseDate(json['today']);

    AttendanceDay? todayAttendance;
    final todayRaw = json['today_attendance'];
    if (todayRaw is Map) {
      todayAttendance = AttendanceDay.fromApiHistoryItem(
        Map<String, dynamic>.from(todayRaw),
      );
    }

    final history = <AttendanceDay>[];
    final historyRaw = json['history'];
    if (historyRaw is List) {
      for (final item in historyRaw) {
        if (item is Map) {
          try {
            history.add(
              AttendanceDay.fromApiHistoryItem(Map<String, dynamic>.from(item)),
            );
          } catch (_) {}
        }
      }
    }

    return AttendanceHistoryData(
      today: today,
      todayAttendance: todayAttendance,
      history: history,
    );
  }
}

class AttendanceCalendarData {
  const AttendanceCalendarData({
    this.monthLabel = '',
    this.attendanceDates = const [],
  });

  final String monthLabel;
  final List<DateTime> attendanceDates;

  factory AttendanceCalendarData.fromJson(Map<String, dynamic> json) {
    final label = (json['month_label'] ?? '').toString();

    final dates = <DateTime>[];
    final rawDates = json['attendance_dates'];
    if (rawDates is List) {
      for (final d in rawDates) {
        final parsed = AttendanceDay._parseDate(d);
        if (parsed != null) {
          dates.add(DateTime(parsed.year, parsed.month, parsed.day));
        }
      }
    }

    return AttendanceCalendarData(monthLabel: label, attendanceDates: dates);
  }
}