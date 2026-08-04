


import 'dart:async';

import 'package:Obecno/core/binding/app_binding.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendance_day.dart'
    hide MonthSummary, AttendanceDayRecord;
import 'package:Obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:Obecno/features/employee_module/attendance/repositories/attendance_repository.dart';
import 'package:Obecno/features/employee_module/attendance/services/day_classification_engine.dart';

import 'package:Obecno/main.dart';
import 'package:flutter/material.dart';

class MonthlyAttendanceController extends ChangeNotifier {
  MonthlyAttendanceController({
    DateTime? initialMonth,
    HistoryAttendanceRepository? repository,
  }) : selectedMonth = _monthOnly(initialMonth ?? DateTime.now()),
       _repository = repository ?? (bindings.attendanceRepository) {
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

  bool get canGoNext => selectedMonth.isBefore(_monthOnly(DateTime.now()));

  // -----------------------------------------------------------------------
  // 🔥 NEW: initial load — offline-first
  // -----------------------------------------------------------------------

  Future<void> _initialLoad() async {
    final epochAtStart = _currentSessionEpoch; // Fix (Issue 2)

    // Load working_days policy from backend before any data loading.
    await _loadWorkingDaysPolicy();
    if (_disposed || _staleSession(epochAtStart)) return; // Fix (Issue 2)

    final hasCache = await _repository.hasAnyCachedData();
    if (_disposed || _staleSession(epochAtStart)) return; // FIXED (issue #1) + Fix (Issue 2)

    if (!hasCache) {
      isLoading = true;
      error = null;
      notifyListeners();

      await _repository.syncInitialRange();
      if (_disposed || _staleSession(epochAtStart)) return; // Fix (Issue 2)
      await _loadMonth(preferCache: true, silent: false);
    } else {
      await _loadMonth(preferCache: true, silent: true);
      if (_disposed || _staleSession(epochAtStart)) return; // FIXED (issue #1) + Fix (Issue 2)
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
    if (_disposed || _staleSession(epochAtStart)) return; // FIXED (issue #1) + Fix (Issue 2)

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
    final target = _monthOnly(date);
    final currentMonth = _monthOnly(DateTime.now());

    selectedMonth = target.isAfter(currentMonth) ? currentMonth : target;
    _loadMonth(preferCache: true);
  }

  void previousMonth() {
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
      if (_disposed || _staleSession(epochAtStart)) return; // FIXED (issue #1) + Fix (Issue 2)
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
}