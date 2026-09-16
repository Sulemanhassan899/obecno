import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';

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
    final sorted = [...checkIns]
      ..sort((a, b) => _clockSortKey(a).compareTo(_clockSortKey(b)));
    return sorted.first;
  }

  /// Latest check-out of the day. Intermediate check-outs are superseded.
  String? get lastCheckOut {
    if (checkOuts.isEmpty) return null;
    final sorted = [...checkOuts]
      ..sort((a, b) => _clockSortKey(a).compareTo(_clockSortKey(b)));
    return sorted.last;
  }

  String? get firstCheckInLocation {
    if (checkIns.isEmpty || checkInLocations.isEmpty) return null;
    final pairs = [
      for (var i = 0; i < checkIns.length; i++)
        (checkIns[i], i < checkInLocations.length ? checkInLocations[i] : null),
    ]..sort((a, b) => _clockSortKey(a.$1).compareTo(_clockSortKey(b.$1)));
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
    ]..sort((a, b) => _clockSortKey(a.$1).compareTo(_clockSortKey(b.$1)));
    return pairs.last.$2;
  }

  bool get hasCheckIn => firstCheckIn != null;
  bool get hasCheckOut => lastCheckOut != null;

  bool get isComplete => hasCheckIn && hasCheckOut;

  bool get hasMissingData => !hasCheckIn || !hasCheckOut;

  AttendanceDay copyWith({
    DateTime? date,
    int? recordId,
    List<String>? checkIns,
    List<String>? checkOuts,
    List<String?>? checkInLocations,
    List<String?>? checkOutLocations,
    List<BreakSession>? breaks,
    bool? isEdited,
    bool? isHoliday,
    bool? isLeave,
    String? holidayName,
  }) {
    return AttendanceDay(
      date: date ?? this.date,
      recordId: recordId ?? this.recordId,
      checkIns: checkIns ?? this.checkIns,
      checkOuts: checkOuts ?? this.checkOuts,
      checkInLocations: checkInLocations ?? this.checkInLocations,
      checkOutLocations: checkOutLocations ?? this.checkOutLocations,
      breaks: breaks ?? this.breaks,
      isEdited: isEdited ?? this.isEdited,
      isHoliday: isHoliday ?? this.isHoliday,
      isLeave: isLeave ?? this.isLeave,
      holidayName: holidayName ?? this.holidayName,
    );
  }

  factory AttendanceDay.fromApiHistoryItem(Map<String, dynamic> json) {
    final nestedRaw = json['attendance'];
    final nested = nestedRaw is Map
        ? Map<String, dynamic>.from(nestedRaw)
        : const <String, dynamic>{};
    final merged = {...nested, ...json};

    final date =
        _parseDate(merged['date'] ?? merged['attendance_date']) ??
        DateTime.now();

    final detailsRaw =
        merged['attendance_details'] ?? nested['attendance_details'];
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
        final time = _normalizedTime(
          detail['attendance_time'] ?? detail['time'],
        );
        if (time == null) continue;
        final location = _normalizedLocation(detail['current_location']);

        switch (_eventKind(detail['type'])) {
          case 'check in':
          case 'checkin':
            checkIns.add(time);
            checkInLocations.add(location);
            break;
          case 'check out':
          case 'checkout':
            checkOuts.add(time);
            checkOutLocations.add(location);
            break;
          case 'break out':
          case 'breakout':
          case 'break start':
            pendingBreakOutTime = time;
            pendingBreakOutLocation = location;
            break;
          case 'break in':
          case 'breakin':
          case 'break end':
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
    }

    // Fall back to the flattened day fields when details are missing or
    // used an unrecognized type, so history rows still get check-in/out.
    if (checkIns.isEmpty && checkOuts.isEmpty && breaks.isEmpty) {
      final checkin = _normalizedTime(
        merged['checkin'] ?? merged['check_in'] ?? merged['check_in_time'],
      );
      final checkout = _normalizedTime(
        merged['checkout'] ?? merged['check_out'] ?? merged['check_out_time'],
      );
      final breakin = _normalizedTime(merged['breakin'] ?? merged['break_in']);
      final breakout = _normalizedTime(
        merged['breakout'] ?? merged['break_out'],
      );
      final location = _normalizedLocation(merged['current_location']);

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

    final dayStatus = (merged['day_status'] ?? merged['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final holidayTitle = _normalizedTime(
      merged['holiday_name'] ?? merged['holiday_title'] ?? merged['holiday'],
    );

    return AttendanceDay(
      date: DateTime(date.year, date.month, date.day),
      recordId: _parseId(merged['attendance_id'] ?? merged['id']),
      checkIns: checkIns,
      checkOuts: checkOuts,
      checkInLocations: checkInLocations,
      checkOutLocations: checkOutLocations,
      breaks: breaks,
      isEdited: false,
      isHoliday: _asBool(merged['is_holiday']) || dayStatus == 'holiday',
      isLeave: _asBool(merged['is_leave']) || dayStatus == 'leave',
      holidayName: holidayTitle,
    );
  }

  static String _eventKind(dynamic raw) {
    return raw
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('_', ' ');
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
    if (raw is double && raw == raw.roundToDouble()) return raw.toInt();
    return int.tryParse(raw.toString()) ??
        double.tryParse(raw.toString())?.round();
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  /// 12:25 AM (hour 0) sorts before 8:00 AM and 8:00 PM.
  static int _clockSortKey(String raw) {
    final parsed = AttendanceEditRequest.parseClockTime(
      raw,
      date: DateTime(2000, 1, 1),
    );
    if (parsed == null) return 0;
    return parsed.hour * 3600 + parsed.minute * 60 + parsed.second;
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
    final todayRaw = json['today_attendance'] ?? json['todayAttendance'];
    if (todayRaw is Map) {
      todayAttendance = AttendanceDay.fromApiHistoryItem(
        Map<String, dynamic>.from(todayRaw),
      );
    }

    final history = <AttendanceDay>[];
    final seen = <String>{};

    void addDays(dynamic raw) {
      if (raw is! List) return;
      for (final item in raw) {
        if (item is! Map) continue;
        try {
          final day = AttendanceDay.fromApiHistoryItem(
            Map<String, dynamic>.from(item),
          );
          final key =
              '${day.date.year}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}';
          if (!seen.add(key)) continue;
          history.add(day);
        } catch (_) {}
      }
    }

    addDays(json['history']);
    addDays(json['attendances']);
    addDays(json['records']);
    addDays(json['days']);

    if (todayAttendance != null) {
      final key =
          '${todayAttendance.date.year}-${todayAttendance.date.month.toString().padLeft(2, '0')}-${todayAttendance.date.day.toString().padLeft(2, '0')}';
      final index = history.indexWhere(
        (day) =>
            day.date.year == todayAttendance!.date.year &&
            day.date.month == todayAttendance.date.month &&
            day.date.day == todayAttendance.date.day,
      );
      if (index < 0) {
        seen.add(key);
        history.insert(0, todayAttendance);
      } else if (history[index].checkIns.isEmpty &&
          todayAttendance.checkIns.isNotEmpty) {
        history[index] = todayAttendance;
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
    this.leaveDates = const [],
  });

  final String monthLabel;
  final List<DateTime> attendanceDates;
  final List<({DateTime date, String name})> holidays;
  final List<DateTime> leaveDates;

  factory AttendanceCalendarData.fromJson(Map<String, dynamic> json) {
    final label = (json['month_label'] ?? json['month'] ?? '').toString();

    final dates = <DateTime>[];
    final holidays = <({DateTime date, String name})>[];
    final leaveDates = <DateTime>{};
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
          final status =
              (map['day_status'] ?? map['status'] ?? map['type'] ?? '')
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
          if (_isLeaveStatus(status, map['is_leave'])) {
            leaveDates.add(dateOnly);
          }
        } else {
          final parsed = AttendanceDay._parseDate(d);
          if (parsed != null) {
            dates.add(DateTime(parsed.year, parsed.month, parsed.day));
          }
        }
      }
    }

    void addLeaveRaw(dynamic raw) {
      if (raw is! List) return;
      for (final item in raw) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final parsed = AttendanceDay._parseDate(
            map['date'] ?? map['day'] ?? map['from_date'] ?? map['date_from'],
          );
          if (parsed == null) continue;
          leaveDates.add(DateTime(parsed.year, parsed.month, parsed.day));
        } else {
          final parsed = AttendanceDay._parseDate(item);
          if (parsed != null) {
            leaveDates.add(DateTime(parsed.year, parsed.month, parsed.day));
          }
        }
      }
    }

    addLeaveRaw(json['leave_dates'] ?? json['leaves']);

    return AttendanceCalendarData(
      monthLabel: label,
      attendanceDates: dates,
      holidays: holidays,
      leaveDates: leaveDates.toList(growable: false),
    );
  }

  static bool _isLeaveStatus(String status, dynamic isLeave) {
    return isLeave == true ||
        isLeave == 1 ||
        isLeave == '1' ||
        isLeave == 'true' ||
        status == 'leave' ||
        status == 'on_leave' ||
        status == 'onleave';
  }
}
