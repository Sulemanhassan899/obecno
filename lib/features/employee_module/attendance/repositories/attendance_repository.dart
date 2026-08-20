import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';

import 'package:obecno/features/employee_module/attendance/data/local/attendance_dao.dart';
import 'package:obecno/features/employee_module/attendance/data/local/attendance_cache_tracker.dart';

class AttendanceMonthResult {
  const AttendanceMonthResult({
    required this.monthLabel,
    required this.summary,
    required this.records,
    required this.rawDays,
    required this.calendarDates,
  });

  final String monthLabel;

  final MonthSummary summary;

  final List<AttendanceDayRecord> records;

  final List<AttendanceDay> rawDays;

  final List<DateTime> calendarDates;
}

class HistoryAttendanceRepository {
  /// [userIdProvider] must always return the *currently signed-in* user's id
  /// (or null/empty if nobody is signed in). It is called fresh on every
  /// cache operation rather than captured once, because this repository is
  /// constructed a single time at app startup (see AppBindings) and lives
  /// across login/logout cycles -- so it must never assume "the user" is
  /// fixed for its lifetime.
  HistoryAttendanceRepository(
    this._service, {
    AttendanceDao? dao,
    AttendanceCacheTracker? cacheTracker,
    required String? Function() userIdProvider,
    DateTime? Function()? joiningDateProvider,
  }) : _dao = dao ?? AttendanceDao(),
       _cacheTracker = cacheTracker ?? AttendanceCacheTracker.instance,
       _userIdProvider = userIdProvider,
       _joiningDateProvider = joiningDateProvider;

  final AttendanceService _service;

  // 🔥 NEW
  final AttendanceDao _dao;
  final AttendanceCacheTracker _cacheTracker;
  final String? Function() _userIdProvider;
  final DateTime? Function()? _joiningDateProvider;

  /// Calendar date-only joining date for the current employee, or null.
  DateTime? get _joiningDate {
    final raw = _joiningDateProvider?.call();
    if (raw == null) return null;
    return DateTime(raw.year, raw.month, raw.day);
  }

  /// Resolves the current user id, failing loudly rather than silently
  /// falling back to a shared/global cache bucket if nobody is signed in.
  String _requireUserId() {
    final id = _userIdProvider();
    if (id == null || id.isEmpty) {
      throw StateError(
        'HistoryAttendanceRepository: no authenticated user to scope the '
        'offline cache to.',
      );
    }
    return id;
  }

  /// Working weekdays from backend policy. Defaults to Mon–Fri.
  /// Updated via [updateWorkingWeekdays] when the controller loads policy.
  Set<int> _workingWeekdays = const {1, 2, 3, 4, 5};

  /// Public holidays. Populated when holiday data is available.
  List<HolidayInfo> _holidays = const [];

  /// Called by the controller after loading policy from CompanyPolicyService.
  void updateWorkingWeekdays(Set<int> weekdays) {
    if (weekdays.isNotEmpty) _workingWeekdays = weekdays;
  }

  /// Called when holiday data becomes available.
  void updateHolidays(List<HolidayInfo> holidays) {
    _holidays = holidays;
  }

  static const _lateCheckInHour = 9;
  static const _lateCheckInMinute = 15;

  static const _lateCheckOutHour = 18;
  static const _lateCheckOutMinute = 0;

  static const _weekdayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  Future<ApiResponse<AttendanceMonthResult>> loadMonth(
    DateTime month, {
    ApiCancelToken? cancelToken,
  }) async {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

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
    final joiningDate = _joiningDate;

    final summary = _buildSummary(
      days: days,
      calendarDates: calendar?.attendanceDates ?? const [],
      month: month,
      today: today,
      joiningDate: joiningDate,
    );

    // 🔥 fill every calendar day (ascending, gap-free), then flip back to
    // latest-first so records match the original display order.
    // Days before the employee's joining date are never filled/shown.
    final displayDays = _fillMissingDays(
      days: days,
      month: month,
      today: today,
      joiningDate: joiningDate,
    ).reversed.toList();
    final records = displayDays.map(_toDayRecord).toList();

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

  Future<bool> hasAnyCachedData() async {
    final id = _userIdProvider();
    if (id == null || id.isEmpty) return false;
    return _dao.hasAnyData(id);
  }

  Future<List<String>> getLoadedMonths() =>
      _dao.getLoadedMonths(_requireUserId());

  Future<AttendanceMonthResult?> loadMonthFromCache(DateTime month) async {
    final userId = _requireUserId();
    final monthKey = _yyyyMM(month);

    if (!_cacheTracker.isLoaded(userId, monthKey)) {
      final synced = await _dao.isMonthSynced(userId, month);
      if (!synced) return null;
      _cacheTracker.markLoaded(userId, monthKey);
    }

    final isEmpty = await _dao.isMonthEmpty(userId, month);
    final days = isEmpty
        ? const <AttendanceDay>[]
        : await _dao.getDaysForMonth(userId, month);

    final today = DateTime.now();
    final joiningDate = _joiningDate;

    final summary = _buildSummary(
      days: days,
      calendarDates: const [],
      month: month,
      today: today,
      joiningDate: joiningDate,
    );

    final displayDays = _fillMissingDays(
      days: days,
      month: month,
      today: today,
      joiningDate: joiningDate,
    ).reversed.toList();
    final records = displayDays.map(_toDayRecord).toList();
    final monthLabel = '${_monthNames[month.month - 1]} ${month.year}';

    return AttendanceMonthResult(
      monthLabel: monthLabel,
      summary: summary,
      records: records,
      rawDays: days,
      calendarDates: const [],
    );
  }

  Future<void> cacheMonth(DateTime month, AttendanceMonthResult result) async {
    final userId = _requireUserId();
    await _dao.upsertMonth(userId, month, result.rawDays);
    _cacheTracker.markLoaded(userId, _yyyyMM(month));
  }

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

  Future<void> syncInitialRange({
    int daysBack = 120,
    ApiCancelToken? cancelToken,
  }) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: daysBack));

    var cursor = DateTime(start.year, start.month);
    final joiningDate = _joiningDate;
    if (joiningDate != null) {
      final joiningMonth = DateTime(joiningDate.year, joiningDate.month);
      if (cursor.isBefore(joiningMonth)) cursor = joiningMonth;
    }

    final endMonth = DateTime(now.year, now.month);
    final userId = _requireUserId();

    while (!cursor.isAfter(endMonth)) {
      // This loop can span many awaited network calls. If the signed-in
      // user changes partway through, stop rather than keep writing
      // freshly-fetched server data into the outgoing user's cache rows.
      if (_userIdProvider() != userId) break;

      final alreadySynced = await _dao.isMonthSynced(userId, cursor);
      if (!alreadySynced) {
        final response = await loadMonth(cursor, cancelToken: cancelToken);
        if (response.success && response.data != null) {
          await cacheMonth(cursor, response.data!);
        }
      }
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
  }

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
    DateTime? joiningDate,
  }) {
    final eligibleDays = joiningDate == null
        ? days
        : days
              .where((d) {
                final date = DateTime(d.date.year, d.date.month, d.date.day);
                return !date.isBefore(joiningDate);
              })
              .toList(growable: false);

    final workingDays = eligibleDays.length;

    // Count only working weekdays (per policy) in the elapsed period,
    // instead of counting every calendar day.
    final range = _monthDisplayRange(
      month: month,
      today: today,
      joiningDate: joiningDate,
    );
    final firstDay = range.$1;
    final elapsedDays = range.$2;
    var totalWorkingDays = 0;
    for (var i = 0; i < elapsedDays; i++) {
      final d = firstDay.add(Duration(days: i));
      if (_workingWeekdays.contains(d.weekday)) totalWorkingDays++;
    }

    final absentOrLeaves = (totalWorkingDays - workingDays).clamp(
      0,
      totalWorkingDays,
    );

    var lateCheckIns = 0;
    var lateCheckOuts = 0;

    for (final day in eligibleDays) {
      final checkIn = _parseClockTime(day.firstCheckIn);
      if (checkIn != null &&
          _isAfterThreshold(checkIn, _lateCheckInHour, _lateCheckInMinute)) {
        lateCheckIns++;
      }

      final checkOut = _parseClockTime(day.lastCheckOut);
      if (checkOut != null &&
          _isBeforeThreshold(
            checkOut,
            _lateCheckOutHour,
            _lateCheckOutMinute,
          )) {
        lateCheckOuts++;
      }
    }

    return MonthSummary(
      workingDays: workingDays,
      totalDays: totalWorkingDays,
      absentOrLeaves: absentOrLeaves,
      lateCheckIns: lateCheckIns,
      lateCheckOuts: lateCheckOuts,
    );
  }

  /// Returns `(startDate, dayCount)` for the visible attendance range in
  /// [month], respecting today (no future days) and [joiningDate].
  (DateTime, int) _monthDisplayRange({
    required DateTime month,
    required DateTime today,
    DateTime? joiningDate,
  }) {
    final monthStart = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final todayOnly = DateTime(today.year, today.month, today.day);

    final sameMonth = todayOnly.year == month.year && todayOnly.month == month.month;
    var effectiveEnd =
        sameMonth && todayOnly.isBefore(lastDay) ? todayOnly : lastDay;

    var effectiveStart = monthStart;
    if (joiningDate != null) {
      final join = DateTime(joiningDate.year, joiningDate.month, joiningDate.day);
      final joiningMonth = DateTime(join.year, join.month);
      final thisMonth = DateTime(month.year, month.month);

      // Entire month before joining month → nothing to show.
      if (thisMonth.isBefore(joiningMonth)) {
        return (monthStart, 0);
      }

      if (thisMonth.year == join.year && thisMonth.month == join.month) {
        if (join.isAfter(effectiveStart)) effectiveStart = join;
      }

      if (effectiveEnd.isBefore(join)) {
        return (monthStart, 0);
      }
    }

    if (effectiveEnd.isBefore(effectiveStart)) return (effectiveStart, 0);
    return (
      effectiveStart,
      effectiveEnd.difference(effectiveStart).inDays + 1,
    );
  }

  List<AttendanceDay> _fillMissingDays({
    required List<AttendanceDay> days,
    required DateTime month,
    required DateTime today,
    DateTime? joiningDate,
  }) {
    final byDate = <String, AttendanceDay>{
      for (final d in days) _yyyyMMdd(d.date): d,
    };

    final range = _monthDisplayRange(
      month: month,
      today: today,
      joiningDate: joiningDate,
    );
    final firstDay = range.$1;
    final elapsed = range.$2;

    final filled = <AttendanceDay>[];
    for (var i = 0; i < elapsed; i++) {
      final date = firstDay.add(Duration(days: i));
      final key = _yyyyMMdd(date);
      filled.add(byDate[key] ?? AttendanceDay(date: date));
    }
    return filled;
  }

  // ---------------------------------------------------------------------
  // AttendanceDay -> AttendanceDayRecord (existing UI model)
  // Uses DayClassificationEngine for backend-driven day classification.
  // ---------------------------------------------------------------------

  AttendanceDayRecord _toDayRecord(AttendanceDay day) {
    // No attendance recorded at all for this date.
    final isFullyMissing =
        day.firstCheckIn == null && day.lastCheckOut == null && !day.isEdited;

    // Build the set of dates that have attendance for classification.
    final attendanceDates = <DateTime>{
      if (!isFullyMissing)
        DateTime(day.date.year, day.date.month, day.date.day),
    };

    // Use the classification engine instead of hardcoded weekend check.
    final classification = DayClassificationEngine.classifyDay(
      date: day.date,
      workingWeekdays: _workingWeekdays,
      attendanceDates: attendanceDates,
      holidays: _holidays,
    );

    // Map classification to status and labels.
    String? checkInLabel;
    String? checkOutLabel;
    AttendanceDayStatus status;

    switch (classification.type) {
      case DayCardType.holiday:
        checkInLabel = 'Holiday';
        checkOutLabel = 'Holiday';
        status = AttendanceDayStatus.holiday;
        break;
      case DayCardType.weekend:
        checkInLabel = 'Holiday';
        checkOutLabel = 'Holiday';
        status = AttendanceDayStatus.weekend;
        break;
      case DayCardType.onLeave:
        checkInLabel = 'Leave';
        checkOutLabel = 'Leave';
        status = AttendanceDayStatus.onLeave;
        break;
      case DayCardType.worked:
        checkInLabel = _formatTime12h(day.firstCheckIn);
        checkOutLabel = _formatTime12h(day.lastCheckOut);
        status = day.isEdited
            ? AttendanceDayStatus.manuallyEdited
            : (day.hasMissingData
                  ? AttendanceDayStatus.missingCheckOut
                  : AttendanceDayStatus.normal);
        break;
    }

    return AttendanceDayRecord(
      day: day.date.day,
      weekday: _weekdayNames[day.date.weekday - 1],
      date: day.date,
      checkIn: checkInLabel,
      checkOut: checkOutLabel,
      status: status,
    );
  }

  // ---------------------------------------------------------------------
  // Time helpers
  // ---------------------------------------------------------------------

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
