
import 'package:Obecno/core/api/api_cancel_token.dart';
import 'package:Obecno/core/api/api_response.dart';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:Obecno/features/employee_module/attendance/services/attendance_service.dart';

// 🔥 NEW — offline cache layer (additive only).
import 'package:Obecno/features/employee_module/attendance/data/local/attendance_dao.dart';
import 'package:Obecno/features/employee_module/attendance/data/local/attendance_cache_tracker.dart';


/// Everything a screen/provider needs to render one month, bundled together
/// so the provider makes exactly one repository call per month load.
class AttendanceMonthResult {
  const AttendanceMonthResult({
    required this.monthLabel,
    required this.summary,
    required this.records,
    required this.rawDays,
    required this.calendarDates,
  });

  /// e.g. "July 2026", straight from the calendar API — falls back to a
  /// locally-formatted label if the calendar call fails.
  final String monthLabel;

  final MonthSummary summary;

  /// UI-ready rows for `AttendanceDayTile`, latest date first.
  final List<AttendanceDayRecord> records;

  /// Normalized rows (pre-UI-mapping) — used to feed the details sheet.
  final List<AttendanceDay> rawDays;

  /// Dates (day-precision) the calendar API reports as having attendance.
  final List<DateTime> calendarDates;
}

/// Business/domain layer for attendance.
///
/// Combines `GET /api/employee/attendance` + `GET /api/employee/calendar`
/// for a given month, applies the rules the live API can't express itself
/// (late check-in/out thresholds, absent-day counting, sorting), and maps
/// the normalized [AttendanceDay] model onto the *existing*
/// `AttendanceDayRecord` / `MonthSummary` UI models so no widget needs to
/// change.
///
/// 🔥 NEW: also owns the offline cache (SQLite via [AttendanceDao]).
/// `loadMonth` below is the ORIGINAL, untouched API-only method. Everything
/// under "OFFLINE CACHE" is additive — cache-first reads, backfill, and
/// silent single-month sync sit on top of it without changing its
/// behavior or signature.
class HistoryAttendanceRepository {
  HistoryAttendanceRepository(this._service, {AttendanceDao? dao, AttendanceCacheTracker? cacheTracker})
    : _dao = dao ?? AttendanceDao(),
      _cacheTracker = cacheTracker ?? AttendanceCacheTracker.instance;

  final AttendanceService _service;

  // 🔥 NEW
  final AttendanceDao _dao;
  final AttendanceCacheTracker _cacheTracker;

  /// 9:15 AM cutoff — a check-in strictly after this is "late".
  static const _lateCheckInHour = 9;
  static const _lateCheckInMinute = 15;

  /// 6:00 PM cutoff — a check-out strictly before this is "late".
  static const _lateCheckOutHour = 18;
  static const _lateCheckOutMinute = 0;

  static const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// ORIGINAL METHOD — UNCHANGED. Always hits the API. Callers that want
  /// offline-first behavior should use [loadMonthFromCache] /
  /// [cacheMonth] around this, exactly like `MonthlyAttendanceController`
  /// now does.
  Future<ApiResponse<AttendanceMonthResult>> loadMonth(
    DateTime month, {
    ApiCancelToken? cancelToken,
  }) async {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    // Fired together — the calendar call is best-effort and must not block
    // rendering the attendance list if it fails.
    final attendanceFuture = _service.getAttendance(
      dateFrom: _yyyyMMdd(firstDay),
      dateTo: _yyyyMMdd(lastDay),
      cancelToken: cancelToken,
    );
    final calendarFuture = _service.getCalendar(
      month: _yyyyMM(month),
      cancelToken: cancelToken,
    );

    final attendanceResponse = await attendanceFuture;
    final calendarResponse = await calendarFuture;

    if (!attendanceResponse.success || attendanceResponse.data == null) {
      return ApiResponse.failure(
        attendanceResponse.message ?? 'Failed to load attendance.',
        statusCode: attendanceResponse.statusCode,
      );
    }

    final history = attendanceResponse.data!;
    final calendar = calendarResponse.success ? calendarResponse.data : null;

    final days = List<AttendanceDay>.from(history.history)
      ..sort((a, b) => b.date.compareTo(a.date)); // latest first

    final today = history.today ?? DateTime.now();

    final summary = _buildSummary(
      days: days,
      calendarDates: calendar?.attendanceDates ?? const [],
      month: month,
      today: today,
    );

    final records = days.map(_toDayRecord).toList();

    final monthLabel = (calendar?.monthLabel.isNotEmpty ?? false)
        ? calendar!.monthLabel
        : '${_monthNames[month.month - 1]} ${month.year}';

    return ApiResponse.success(
      AttendanceMonthResult(
        monthLabel: monthLabel,
        summary: summary,
        records: records,
        rawDays: days,
        calendarDates: calendar?.attendanceDates ?? const [],
      ),
    );
  }

  // =======================================================================
  // 🔥 NEW: OFFLINE CACHE
  // =======================================================================

  /// True once at least one month has ever been synced to the local DB —
  /// used to distinguish "first login" (needs the full backfill) from
  /// "app reopen" (cache already warm).
  Future<bool> hasAnyCachedData() => _dao.hasAnyData();

  Future<List<String>> getLoadedMonths() => _dao.getLoadedMonths();

  /// Reads [month] from the local DB only — never touches the network.
  /// Returns null if this month has never been synced (i.e. it's genuinely
  /// unknown, not just empty).
  Future<AttendanceMonthResult?> loadMonthFromCache(DateTime month) async {
    final monthKey = _yyyyMM(month);

    if (!_cacheTracker.isLoaded(monthKey)) {
      final synced = await _dao.isMonthSynced(month);
      if (!synced) return null;
      _cacheTracker.markLoaded(monthKey);
    }

    final isEmpty = await _dao.isMonthEmpty(month);
    final days = isEmpty ? const <AttendanceDay>[] : await _dao.getDaysForMonth(month);

    final summary = _buildSummary(
      days: days,
      calendarDates: const [],
      month: month,
      today: DateTime.now(),
    );
    final records = days.map(_toDayRecord).toList();
    final monthLabel = '${_monthNames[month.month - 1]} ${month.year}';

    return AttendanceMonthResult(
      monthLabel: monthLabel,
      summary: summary,
      records: records,
      rawDays: days,
      calendarDates: const [],
    );
  }

  /// Persists a freshly-fetched month into the local DB (UPSERT — never
  /// clears the DB, never duplicates rows) and marks it loaded in the
  /// in-memory tracker.
  Future<void> cacheMonth(DateTime month, AttendanceMonthResult result) async {
    await _dao.upsertMonth(month, result.rawDays);
    _cacheTracker.markLoaded(_yyyyMM(month));
  }

  /// Cache-first convenience wrapper: DB hit → return it; miss → fetch
  /// from the API, cache it, then return it. Used for background/backfill
  /// syncing where no UI loader distinction is needed.
  Future<ApiResponse<AttendanceMonthResult>> loadMonthSmart(
    DateTime month, {
    ApiCancelToken? cancelToken,
  }) async {
    final cached = await loadMonthFromCache(month);
    if (cached != null) return ApiResponse.success(cached);

    final response = await loadMonth(month, cancelToken: cancelToken);
    if (response.success && response.data != null) {
      await cacheMonth(month, response.data!);
    }
    return response;
  }

  /// First-login backfill: fetches and caches every month in the last
  /// ~120 days that isn't already synced. Months already in the DB are
  /// skipped — never re-fetched.
  Future<void> syncInitialRange({
    int daysBack = 120,
    ApiCancelToken? cancelToken,
  }) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: daysBack));

    var cursor = DateTime(start.year, start.month);
    final endMonth = DateTime(now.year, now.month);

    while (!cursor.isAfter(endMonth)) {
      final alreadySynced = await _dao.isMonthSynced(cursor);
      if (!alreadySynced) {
        final response = await loadMonth(cursor, cancelToken: cancelToken);
        if (response.success && response.data != null) {
          await cacheMonth(cursor, response.data!);
        }
      }
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
  }

  /// App-reopen silent sync: re-fetches ONLY the current month from the
  /// API (in case new events happened since the last cache write) and
  /// updates the DB. Older months are left as-is — they don't change.
  Future<ApiResponse<AttendanceMonthResult>> syncLatestMonth({
    ApiCancelToken? cancelToken,
  }) async {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final response = await loadMonth(currentMonth, cancelToken: cancelToken);
    if (response.success && response.data != null) {
      await cacheMonth(currentMonth, response.data!);
    }
    return response;
  }

  // ---------------------------------------------------------------------
  // Summary computation
  // ---------------------------------------------------------------------

  MonthSummary _buildSummary({
    required List<AttendanceDay> days,
    required List<DateTime> calendarDates,
    required DateTime month,
    required DateTime today,
  }) {
    final workingDays = days.length;

    // "calendar_days": days elapsed in the selected month so far (capped at
    // the month's last day for past/future months). This is the API's only
    // available notion of "days that should have attendance" since there's
    // no shift/roster endpoint.
    final calendarDays = _elapsedDaysInMonth(month, today);

    final absentOrLeaves = (calendarDays - workingDays).clamp(0, calendarDays);

    var lateCheckIns = 0;
    var lateCheckOuts = 0;

    for (final day in days) {
      final checkIn = _parseClockTime(day.firstCheckIn);
      if (checkIn != null && _isAfterThreshold(checkIn, _lateCheckInHour, _lateCheckInMinute)) {
        lateCheckIns++;
      }

      final checkOut = _parseClockTime(day.lastCheckOut);
      if (checkOut != null && _isBeforeThreshold(checkOut, _lateCheckOutHour, _lateCheckOutMinute)) {
        lateCheckOuts++;
      }
    }

    return MonthSummary(
      workingDays: workingDays,
      totalDays: calendarDays,
      absentOrLeaves: absentOrLeaves,
      lateCheckIns: lateCheckIns,
      lateCheckOuts: lateCheckOuts,
    );
  }

  int _elapsedDaysInMonth(DateTime month, DateTime today) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final sameMonth = today.year == month.year && today.month == month.month;
    final effectiveEnd = sameMonth && today.isBefore(lastDay) ? today : lastDay;

    if (effectiveEnd.isBefore(firstDay)) return 0;
    return effectiveEnd.difference(firstDay).inDays + 1;
  }

  // ---------------------------------------------------------------------
  // AttendanceDay -> AttendanceDayRecord (existing UI model)
  // ---------------------------------------------------------------------

  AttendanceDayRecord _toDayRecord(AttendanceDay day) {
    // hasMissingData covers both "missing checkin" and "missing checkout"
    // per the icon-logic spec (Case 1). isEdited is always false today
    // (Case 2 never fires), so manuallyEdited is intentionally unused here.
    final status = day.hasMissingData
        ? AttendanceDayStatus.missingCheckOut
        : AttendanceDayStatus.normal;

    return AttendanceDayRecord(
      day: day.date.day,
      weekday: _weekdayNames[day.date.weekday - 1],
      date: day.date,
      checkIn: _formatTime12h(day.firstCheckIn),
      checkOut: _formatTime12h(day.lastCheckOut),
      status: status,
    );
  }

  // ---------------------------------------------------------------------
  // Time helpers
  // ---------------------------------------------------------------------

  /// Parses "HH:mm[:ss]" (24-hour, as returned by the API) into a
  /// day-agnostic `(hour, minute)` pair. Returns null for anything blank
  /// or malformed rather than throwing.
  ({int hour, int minute})? _parseClockTime(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return (hour: h, minute: m);
  }

  bool _isAfterThreshold(({int hour, int minute}) t, int hour, int minute) {
    return t.hour > hour || (t.hour == hour && t.minute > minute);
  }

  bool _isBeforeThreshold(({int hour, int minute}) t, int hour, int minute) {
    return t.hour < hour || (t.hour == hour && t.minute < minute);
  }

  String? _formatTime12h(String? raw) {
    final t = _parseClockTime(raw);
    if (t == null) return null;
    final period = t.hour >= 12 ? 'PM' : 'AM';
    var hour12 = t.hour % 12;
    if (hour12 == 0) hour12 = 12;
    final hh = hour12.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm $period';
  }

  String _yyyyMMdd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _yyyyMM(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
}