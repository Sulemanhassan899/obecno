/// Normalized attendance domain model + raw API DTOs.
///
/// This file is ADDITIVE only — it does not modify the existing
/// `attendence_model.dart` (which stays as the UI-facing model consumed by
/// `AttendanceSummaryCard` / `AttendanceDayTile`). `AttendanceDay` here is
/// the scalable, API-shape-agnostic model requested in the spec; the
/// repository maps it down into the existing `AttendanceDayRecord` /
/// `MonthSummary` UI models so widgets never need to change.
library;

/// A single break window on a given day. The current API only ever returns
/// one break pair (`breakin` + `breakout`) per day, but modeling it as a
/// list of sessions (see [AttendanceDay.breaks]) means the day model
/// doesn't need to change shape if the backend adds multiple breaks later.
class BreakSession {
  const BreakSession({required this.breakIn, required this.breakOut});

  /// Raw "HH:mm:ss" (or "HH:mm") time string, 24-hour, as returned by the API.
  final String breakIn;
  final String breakOut;

  @override
  String toString() => 'BreakSession($breakIn -> $breakOut)';
}

/// Normalized, scalable representation of one day's attendance.
///
/// The live API only ever produces a single check-in and a single
/// check-out per day, but modeling them as lists ([checkIns], [checkOuts])
/// means downstream code (summaries, tiles) doesn't have to change if the
/// backend later supports multiple clock events per day.
class AttendanceDay {
  const AttendanceDay({
    required this.date,
    this.recordId,
    this.checkIns = const [],
    this.checkOuts = const [],
    this.breaks = const [],
    this.isEdited = false,
  });

  final DateTime date;
  final int? recordId;
  final List<String> checkIns;
  final List<String> checkOuts;
  final List<BreakSession> breaks;

  /// The API has no `is_edited` flag today, so this is always `false`.
  /// Kept as a field (rather than hardcoded at every call site) so a future
  /// API addition only requires wiring this one value, not touching the
  /// icon logic that reads it.
  final bool isEdited;

  String? get firstCheckIn => checkIns.isEmpty ? null : checkIns.first;
  String? get lastCheckOut => checkOuts.isEmpty ? null : checkOuts.last;

  bool get hasCheckIn => firstCheckIn != null;
  bool get hasCheckOut => lastCheckOut != null;

  /// True when both a check-in and a check-out are present.
  bool get isComplete => hasCheckIn && hasCheckOut;

  /// True when the record is missing a check-in and/or a check-out —
  /// drives the `imagesTriangleExclamation` icon per the spec.
  bool get hasMissingData => !hasCheckIn || !hasCheckOut;

  /// Builds an [AttendanceDay] from one `history[]` (or `today_attendance`)
  /// item:
  /// ```json
  /// {"id":6,"date":"2026-07-14","checkin":"00:27:02","checkout":"00:28:12","breakout":"","breakin":""}
  /// ```
  /// Empty strings are treated as null/absent per the mapping rules.
  factory AttendanceDay.fromApiHistoryItem(Map<String, dynamic> json) {
    final date = _parseDate(json['date']) ?? DateTime.now();

    final checkin = _normalizedTime(json['checkin']);
    final checkout = _normalizedTime(json['checkout']);
    final breakin = _normalizedTime(json['breakin']);
    final breakout = _normalizedTime(json['breakout']);

    final breaks = <BreakSession>[
      if (breakin != null && breakout != null)
        BreakSession(breakIn: breakin, breakOut: breakout),
    ];

    return AttendanceDay(
      date: DateTime(date.year, date.month, date.day),
      recordId: _parseId(json['id']),
      checkIns: checkin != null ? [checkin] : const [],
      checkOuts: checkout != null ? [checkout] : const [],
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

  /// Treats empty/blank strings (and null) as "no value", per the API's
  /// convention of returning `""` instead of omitting the field.
  static String? _normalizedTime(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  @override
  String toString() =>
      'AttendanceDay(date: $date, in: $checkIns, out: $checkOuts, breaks: $breaks)';
}

/// Raw payload of `GET /api/employee/attendance`.
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
          } catch (_) {
            // Skip malformed rows instead of failing the whole response.
          }
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

/// Raw payload of `GET /api/employee/calendar`.
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
