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
    this.isHoliday = false,
    this.isLeave = false,
    this.holidayName,
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
  final bool isHoliday;
  final bool isLeave;
  final String? holidayName;

  /// Earliest check-in of the day (immutable session start). Never use a
  /// later re-check-in as the day header check-in.
  String? get firstCheckIn {
    if (checkIns.isEmpty) return null;
    final sorted = [...checkIns]..sort();
    return sorted.first;
  }

  /// Latest check-out of the day. Intermediate check-outs are superseded.
  String? get lastCheckOut {
    if (checkOuts.isEmpty) return null;
    final sorted = [...checkOuts]..sort();
    return sorted.last;
  }

  String? get firstCheckInLocation {
    if (checkIns.isEmpty || checkInLocations.isEmpty) return null;
    final pairs = [
      for (var i = 0; i < checkIns.length; i++)
        (checkIns[i], i < checkInLocations.length ? checkInLocations[i] : null),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return pairs.first.$2;
  }

  String? get lastCheckOutLocation {
    if (checkOuts.isEmpty || checkOutLocations.isEmpty) return null;
    final pairs = [
      for (var i = 0; i < checkOuts.length; i++)
        (
          checkOuts[i],
          i < checkOutLocations.length ? checkOutLocations[i] : null,
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return pairs.last.$2;
  }

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

    // Keep lists chronologically ordered so consumers that index `.first` /
    // `.last` (and local DB writes) always see earliest in / latest out.
    _sortTimeLocationPairs(checkIns, checkInLocations);
    _sortTimeLocationPairs(checkOuts, checkOutLocations);

    final dayStatus = (json['day_status'] ?? json['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final holidayTitle = _normalizedTime(
      json['holiday_name'] ?? json['holiday_title'] ?? json['holiday'],
    );

    return AttendanceDay(
      date: DateTime(date.year, date.month, date.day),
      recordId: _parseId(json['id']),
      checkIns: checkIns,
      checkOuts: checkOuts,
      checkInLocations: checkInLocations,
      checkOutLocations: checkOutLocations,
      breaks: breaks,
      isEdited: false,
      isHoliday: _asBool(json['is_holiday']) || dayStatus == 'holiday',
      isLeave: _asBool(json['is_leave']) || dayStatus == 'leave',
      holidayName: holidayTitle,
    );
  }

  static bool _asBool(dynamic raw) {
    return raw == true || raw == 1 || raw == '1' || raw == 'true';
  }

  static void _sortTimeLocationPairs(
    List<String> times,
    List<String?> locations,
  ) {
    if (times.length <= 1) return;
    final pairs = [
      for (var i = 0; i < times.length; i++)
        (times[i], i < locations.length ? locations[i] : null),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    times
      ..clear()
      ..addAll(pairs.map((p) => p.$1));
    locations
      ..clear()
      ..addAll(pairs.map((p) => p.$2));
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
    this.holidays = const [],
  });

  final String monthLabel;
  final List<DateTime> attendanceDates;
  final List<({DateTime date, String name})> holidays;

  factory AttendanceCalendarData.fromJson(Map<String, dynamic> json) {
    final label = (json['month_label'] ?? json['month'] ?? '').toString();

    final dates = <DateTime>[];
    final holidays = <({DateTime date, String name})>[];
    final rawDates = json['attendance_dates'] ?? json['dates'] ?? json['days'];
    if (rawDates is List) {
      for (final d in rawDates) {
        if (d is Map) {
          final map = Map<String, dynamic>.from(d);
          final parsed = AttendanceDay._parseDate(
            map['date'] ?? map['day'] ?? map['attendance_date'],
          );
          if (parsed == null) continue;
          final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
          dates.add(dateOnly);
          final status = (map['day_status'] ?? map['status'] ?? map['type'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final isHoliday =
              map['is_holiday'] == true ||
              map['is_holiday'] == 1 ||
              map['is_holiday'] == '1' ||
              status == 'holiday';
          if (isHoliday) {
            final name =
                (map['holiday_name'] ??
                        map['name'] ??
                        map['title'] ??
                        map['label'] ??
                        'Public Holiday')
                    .toString()
                    .trim();
            holidays.add((
              date: dateOnly,
              name: name.isEmpty ? 'Public Holiday' : name,
            ));
          }
        } else {
          final parsed = AttendanceDay._parseDate(d);
          if (parsed != null) {
            dates.add(DateTime(parsed.year, parsed.month, parsed.day));
          }
        }
      }
    }

    return AttendanceCalendarData(
      monthLabel: label,
      attendanceDates: dates,
      holidays: holidays,
    );
  }
}
