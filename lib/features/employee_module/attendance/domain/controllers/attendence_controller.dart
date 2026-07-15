
import 'dart:async';

import 'package:Obecno/core/binding/app_binding.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:Obecno/features/employee_module/attendance/repositories/attendance_repository.dart';

import 'package:Obecno/main.dart';
import 'package:flutter/material.dart';

class MonthlyAttendanceController extends ChangeNotifier {
  MonthlyAttendanceController({
    DateTime? initialMonth,
    HistoryAttendanceRepository? repository,
  }) : selectedMonth = _monthOnly(initialMonth ?? DateTime.now()),
       _repository =
           repository ??
           (bindings.attendanceRepository) {
    // ✅ FIX
    _initialLoad();
  }

  final HistoryAttendanceRepository _repository;

  DateTime selectedMonth;
  MonthSummary? summary;
  List<AttendanceDayRecord> records = [];
  List<AttendanceDay> rawDays = [];

  /// Full-screen loader — only true on the very first-ever load (no cache
  /// yet at all) or when jumping to a month that isn't cached.
  bool isLoading = false;

  /// 🔥 NEW — bottom-only loader while paginating to a month that isn't
  /// cached yet and has to be fetched from the API.
  bool isPaginating = false;

  /// 🔥 NEW — true while the silent "app reopen" background sync of the
  /// current month is in flight. Not surfaced as a loader anywhere by
  /// design (spec: "App reopen -> NO loader").
  bool isSyncing = false;

  String? error;

  static DateTime _monthOnly(DateTime d) => DateTime(d.year, d.month);

  /// 🔥 NEW — the picker/header use this to disable forward navigation
  /// past the current month.
  bool get canGoNext => selectedMonth.isBefore(_monthOnly(DateTime.now()));

  // -----------------------------------------------------------------------
  // 🔥 NEW: initial load — offline-first
  // -----------------------------------------------------------------------

  Future<void> _initialLoad() async {
    final hasCache = await _repository.hasAnyCachedData();

    if (!hasCache) {
      // First login ever (or fresh install): full loader, backfill the
      // last ~4 months into the DB, then show the current month.
      isLoading = true;
      error = null;
      notifyListeners();

      await _repository.syncInitialRange();
      await _loadMonth(preferCache: true, silent: false);
    } else {
      // App reopen: instant UI straight from the DB, no loader at all,
      // then silently re-sync just the current month in the background.
      await _loadMonth(preferCache: true, silent: true);
      unawaited(_syncLatestMonthInBackground());
    }
  }

  Future<void> _syncLatestMonthInBackground() async {
    isSyncing = true;

    final response = await _repository.syncLatestMonth();

    isSyncing = false;

    final currentMonth = _monthOnly(DateTime.now());
    // Only reflect this in the UI if the user is still looking at the
    // current month — otherwise it'd silently overwrite whatever month
    // they've since paginated to.
    if (selectedMonth == currentMonth && response.success && response.data != null) {
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

    // 🔒 Never allow navigating into a future month, however it was
    // requested (picker, deep link, etc).
    selectedMonth = target.isAfter(currentMonth) ? currentMonth : target;
    _loadMonth(preferCache: true);
  }

  void previousMonth() {
    setMonth(DateTime(selectedMonth.year, selectedMonth.month - 1));
  }

  void nextMonth() {
    // ❌ No forward navigation past the current month.
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

  Future<void> _loadMonth({bool preferCache = true, bool silent = false}) async {
    final requestedMonth = selectedMonth;

    if (preferCache) {
      final cached = await _repository.loadMonthFromCache(requestedMonth);
      if (cached != null) {
        // Stale guard: user may have navigated again while we awaited.
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

    // Not cached — need the network. Full loader only if this is the very
    // first paint (`silent == false` and nothing shown yet); otherwise
    // it's pagination, so only the bottom loader shows.
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

      if (requestedMonth != selectedMonth) return; // stale — user moved on

      if (response.success && response.data != null) {
        final result = response.data!;
        summary = result.summary;
        records = result.records;
        rawDays = result.rawDays;
      } else {
        error = response.message ?? 'Failed to load attendance.';
      }
    } catch (e) {
      if (requestedMonth != selectedMonth) return;
      error = e.toString();
    }

    isLoading = false;
    isPaginating = false;
    isSyncing = false;
    notifyListeners();
  }

  /// Re-fetches the currently selected month from the API, bypassing the
  /// cache (pull-to-refresh style).
  Future<void> refresh() async {
    isPaginating = summary != null;
    isLoading = !isPaginating;
    notifyListeners();

    final response = await _repository.loadMonth(selectedMonth);
    if (response.success && response.data != null) {
      await _repository.cacheMonth(selectedMonth, response.data!);
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