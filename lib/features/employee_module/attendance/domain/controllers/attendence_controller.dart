import 'dart:async';
import 'dart:convert';

import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart'
    hide MonthSummary, AttendanceDayRecord;
import 'package:obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:obecno/features/employee_module/attendance/repositories/attendance_repository.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';

import 'package:obecno/main.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonthlyAttendanceController extends ChangeNotifier {
  MonthlyAttendanceController({
    DateTime? initialMonth,
    HistoryAttendanceRepository? repository,
  }) : selectedMonth = _monthOnly(initialMonth ?? DateTime.now()),
       _repository = repository ?? (bindings.attendanceRepository) {
    _clampSelectedMonthToJoining();
    _logJoiningBounds();
    _initialLoad();
  }

  final HistoryAttendanceRepository _repository;

  get apiClient => bindings.ApihttpClient;
  String get userEmail => bindings.userEmail;

  /// Working weekdays from backend policy, exposed for the UI.
  Set<int> get workingWeekdays => _workingWeekdays;
  Set<int> _workingWeekdays = const {1, 2, 3, 4, 5};

  bool _disposed = false;

  // Fix (Issue 2): this controller previously guarded async continuations
  // only with _disposed, not with the app's session epoch -- so if a slow
  // request from User A's session resolved after User B was already signed
  // in but before this controller happened to be disposed, User A's month
  // data could flash into User B's screen. `bindings.authProvider` is the
  // same session-epoch source SyncService already trusts.
  int get _currentSessionEpoch => bindings.authProvider.sessionEpoch;
  bool _staleSession(int epochAtStart) => epochAtStart != _currentSessionEpoch;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  DateTime selectedMonth;
  MonthSummary? summary;
  List<AttendanceDayRecord> records = [];
  List<AttendanceDay> rawDays = [];

  bool isLoading = false;

  bool isPaginating = false;

  bool isSyncing = false;

  String? error;

  static DateTime _monthOnly(DateTime d) => DateTime(d.year, d.month);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Live joining date for the currently authenticated employee.
  DateTime? get joiningDate {
    final raw = bindings.authProvider.user?.joiningDate;
    if (raw == null) return null;
    return _dateOnly(raw);
  }

  /// First selectable attendance month (month containing [joiningDate]).
  DateTime? get minimumMonth {
    final join = joiningDate;
    if (join == null) return null;
    return DateTime(join.year, join.month);
  }

  bool get canGoNext => selectedMonth.isBefore(_monthOnly(DateTime.now()));

  bool get canGoPrevious {
    final min = minimumMonth;
    if (min == null) return true;
    return selectedMonth.isAfter(min);
  }

  void _clampSelectedMonthToJoining() {
    final min = minimumMonth;
    if (min != null && selectedMonth.isBefore(min)) {
      selectedMonth = min;
    }
    final currentMonth = _monthOnly(DateTime.now());
    if (selectedMonth.isAfter(currentMonth)) {
      selectedMonth = currentMonth;
    }
  }

  void _logJoiningBounds() {
    final join = joiningDate;
    final min = minimumMonth;
    if (join == null) {
      AppLogger.info(
        '[ATTENDANCE_BOUNDS]\n'
        'joining_date=null\n'
        'minimumDate=null\n'
        'minimumMonth=null\n'
        'selectedMonth=${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, "0")}',
      );
      return;
    }
    AppLogger.info(
      '[ATTENDANCE_BOUNDS]\n'
      'joining_date=${_yyyyMMdd(join)}\n'
      'minimumDate=${_yyyyMMdd(join)}\n'
      'minimumMonth=${min!.year}-${min.month.toString().padLeft(2, "0")}\n'
      'selectedMonth=${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, "0")}',
    );
  }

  static String _yyyyMMdd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // -----------------------------------------------------------------------
  // 🔥 NEW: initial load — offline-first
  // -----------------------------------------------------------------------

  Future<void> _initialLoad() async {
    final epochAtStart = _currentSessionEpoch; // Fix (Issue 2)

    final userId = bindings.authProvider.user?.id;
    if (userId == null || userId.isEmpty) return;

    // Load working_days policy from backend before any data loading.
    await _loadWorkingDaysPolicy();
    if (_disposed || _staleSession(epochAtStart)) return; // Fix (Issue 2)

    // /auth/me may have populated joining_date after construction.
    _clampSelectedMonthToJoining();
    _logJoiningBounds();

    final hasCache = await _repository.hasAnyCachedData();
    if (_disposed || _staleSession(epochAtStart)) {
      return; // FIXED (issue #1) + Fix (Issue 2)
    }

    if (!hasCache) {
      isLoading = true;
      error = null;
      notifyListeners();

      await _repository.syncInitialRange();
      if (_disposed || _staleSession(epochAtStart)) return; // Fix (Issue 2)
      await _loadMonth(preferCache: true, silent: false);
    } else {
      await _loadMonth(preferCache: true, silent: true);
      if (_disposed || _staleSession(epochAtStart)) {
        return; // FIXED (issue #1) + Fix (Issue 2)
      }
      unawaited(_syncLatestMonthInBackground());
    }
  }

  /// Loads working_days from CompanyPolicyService and updates the repository.
  Future<void> _loadWorkingDaysPolicy() async {
    try {
      final raw = await bindings.companyPolicyService.valueFor(
        'attendance',
        'working_days',
      );
      final parsed = WorkingDaysParser.parse(raw);
      if (parsed.isNotEmpty) {
        _workingWeekdays = parsed;
        _repository.updateWorkingWeekdays(parsed);
      }
    } catch (_) {
      // Silently fall back to default Mon–Fri.
    }
  }

  Future<void> _syncLatestMonthInBackground() async {
    final epochAtStart = _currentSessionEpoch; // Fix (Issue 2)
    isSyncing = true;

    final response = await _repository.syncLatestMonth();
    if (_disposed || _staleSession(epochAtStart)) {
      return; // FIXED (issue #1) + Fix (Issue 2)
    }

    isSyncing = false;

    final currentMonth = _monthOnly(DateTime.now());
    if (selectedMonth == currentMonth &&
        response.success &&
        response.data != null) {
      final result = response.data!;
      summary = result.summary;
      records = result.records;
      rawDays = result.rawDays;
    }

    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // Navigation
  // -----------------------------------------------------------------------

  void setMonth(DateTime date) {
    var target = _monthOnly(date);
    final currentMonth = _monthOnly(DateTime.now());

    if (target.isAfter(currentMonth)) target = currentMonth;

    final min = minimumMonth;
    if (min != null && target.isBefore(min)) target = min;

    selectedMonth = target;
    _logJoiningBounds();
    _loadMonth(preferCache: true);
  }

  void previousMonth() {
    if (!canGoPrevious) return;
    setMonth(DateTime(selectedMonth.year, selectedMonth.month - 1));
  }

  void nextMonth() {
    if (!canGoNext) return;
    setMonth(DateTime(selectedMonth.year, selectedMonth.month + 1));
  }

  AttendanceDay? dayFor(DateTime date) {
    for (final day in rawDays) {
      if (day.date.year == date.year &&
          day.date.month == date.month &&
          day.date.day == date.day) {
        return day;
      }
    }
    return null;
  }

  // -----------------------------------------------------------------------
  // 🔥 NEW: month-based pagination — cache first, API fallback
  // -----------------------------------------------------------------------

  Future<void> _loadMonth({
    bool preferCache = true,
    bool silent = false,
  }) async {
    final requestedMonth = selectedMonth;
    final epochAtStart = _currentSessionEpoch; // Fix (Issue 2)

    if (preferCache) {
      final cached = await _repository.loadMonthFromCache(requestedMonth);
      if (_disposed || _staleSession(epochAtStart)) {
        return; // FIXED (issue #1) + Fix (Issue 2)
      }
      if (cached != null) {
        if (requestedMonth != selectedMonth) return;

        summary = cached.summary;
        records = cached.records;
        rawDays = cached.rawDays;
        isLoading = false;
        isPaginating = false;
        error = null;
        notifyListeners();
        return;
      }
    }

    if (silent) {
      isSyncing = true;
    } else if (summary == null && records.isEmpty) {
      isLoading = true;
    } else {
      isPaginating = true;
    }
    error = null;
    notifyListeners();

    try {
      final response = await _repository.loadMonthSmart(requestedMonth);
      if (_disposed || _staleSession(epochAtStart)) return; // FIXED (issue #1) + Fix (Issue 2)

      if (requestedMonth != selectedMonth) return;

      if (response.success && response.data != null) {
        final result = response.data!;
        summary = result.summary;
        records = result.records;
        rawDays = result.rawDays;
      } else {
        error = response.message ?? 'Failed to load attendance.';
      }
    } catch (e) {
      if (_disposed || _staleSession(epochAtStart)) return; // FIXED (issue #1) + Fix (Issue 2)
      if (requestedMonth != selectedMonth) return;
      error = e.toString();
    }

    if (_disposed || _staleSession(epochAtStart)) return; // FIXED (issue #1) + Fix (Issue 2)
    isLoading = false;
    isPaginating = false;
    isSyncing = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    final epochAtStart = _currentSessionEpoch; // Fix (Issue 2)
    isPaginating = summary != null;
    isLoading = !isPaginating;
    notifyListeners();

    final response = await _repository.loadMonth(selectedMonth);
    if (_disposed || _staleSession(epochAtStart)) return; // FIXED (issue #1) + Fix (Issue 2)
    if (response.success && response.data != null) {
      await _repository.cacheMonth(selectedMonth, response.data!);
      if (_disposed || _staleSession(epochAtStart)) return; // FIXED (issue #1) + Fix (Issue 2)
      final result = response.data!;
      summary = result.summary;
      records = result.records;
      rawDays = result.rawDays;
      error = null;
    } else {
      error = response.message ?? 'Failed to load attendance.';
    }

    isLoading = false;
    isPaginating = false;
    notifyListeners();
  }

  /// Re-reads today's clock punches and the current month from the server.
  /// Used when the Attendance tab becomes visible so today's check-in
  /// shows without a pull-to-refresh.
  Future<void> reloadVisibleMonth() async {
    await _mergeTodayFromClock();
    await _loadMonth(preferCache: false, silent: true);
    await _mergeTodayFromClock();
  }

  Future<void> _mergeTodayFromClock() async {
    final today = DateTime.now();
    if (selectedMonth.year != today.year ||
        selectedMonth.month != today.month) {
      return;
    }
    final userId = bindings.authProvider.user?.id;
    if (userId == null || userId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key =
          'clock_events_${userId}_${today.year}-${today.month}-${today.day}';
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) return;

      final checkIns = <String>[];
      final checkOuts = <String>[];
      final checkInLocations = <String?>[];
      final checkOutLocations = <String?>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final type = item['type']?.toString() ?? '';
        final time = DateTime.tryParse(item['time']?.toString() ?? '');
        if (time == null) continue;
        final stamp = _hhmmss(time);
        final location = item['location']?.toString();
        if (type == 'checkIn') {
          checkIns.add(stamp);
          checkInLocations.add(location);
        } else if (type == 'checkOut') {
          checkOuts.add(stamp);
          checkOutLocations.add(location);
        }
      }
      if (checkIns.isEmpty && checkOuts.isEmpty) return;

      final dateOnly = DateTime(today.year, today.month, today.day);
      AttendanceDay? existing;
      for (final day in rawDays) {
        if (day.date.year == dateOnly.year &&
            day.date.month == dateOnly.month &&
            day.date.day == dateOnly.day) {
          existing = day;
          break;
        }
      }
      if (existing != null && existing.checkIns.isNotEmpty) return;

      final merged = AttendanceDay(
        date: dateOnly,
        recordId: existing?.recordId,
        checkIns: checkIns.isNotEmpty
            ? checkIns
            : (existing?.checkIns ?? const []),
        checkOuts: checkOuts.isNotEmpty
            ? checkOuts
            : (existing?.checkOuts ?? const []),
        checkInLocations: checkInLocations.isNotEmpty
            ? checkInLocations
            : (existing?.checkInLocations ?? const []),
        checkOutLocations: checkOutLocations.isNotEmpty
            ? checkOutLocations
            : (existing?.checkOutLocations ?? const []),
        breaks: existing?.breaks ?? const [],
        isEdited: existing?.isEdited ?? false,
        isHoliday: existing?.isHoliday ?? false,
        isLeave: existing?.isLeave ?? false,
        holidayName: existing?.holidayName,
      );

      rawDays = [
        for (final day in rawDays)
          if (day.date.year == dateOnly.year &&
              day.date.month == dateOnly.month &&
              day.date.day == dateOnly.day)
            merged
          else
            day,
      ];
      if (!rawDays.any(
        (day) =>
            day.date.year == dateOnly.year &&
            day.date.month == dateOnly.month &&
            day.date.day == dateOnly.day,
      )) {
        rawDays = [...rawDays, merged];
      }

      if (!(existing?.isLeave ?? false)) {
        records = [
          for (final record in records)
            if (record.date.year == dateOnly.year &&
                record.date.month == dateOnly.month &&
                record.date.day == dateOnly.day)
              AttendanceDayRecord(
                day: record.day,
                weekday: record.weekday,
                date: record.date,
                checkIn: _format12h(merged.firstCheckIn),
                checkOut: _format12h(merged.lastCheckOut),
                status: merged.lastCheckOut == null
                    ? AttendanceDayStatus.missingCheckOut
                    : AttendanceDayStatus.normal,
              )
            else
              record,
        ];
      }
      notifyListeners();
    } catch (_) {}
  }

  static String _hhmmss(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';

  static String? _format12h(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    final period = hour >= 12 ? 'PM' : 'AM';
    var hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    return '${hour12.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')} $period';
  }
}
