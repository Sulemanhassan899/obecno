

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/auth/services/company_policy_service.dart';
import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/features/employee_module/clock/presentation/widgets/clock_attendance_engine.dart';

enum AttendanceActionResult {
  checkedIn,
  checkedOut,
  breakStarted,
  breakEnded,
  outOfRange,
  nonWorkingDay,
  breakLimitReached,
  none,
}

class _ParsedTime {
  const _ParsedTime(this.hour, this.minute);
  final int hour;
  final int minute;
}

class ClockTicker extends ValueNotifier<DateTime> {
  ClockTicker() : super(DateTime.now());

  Timer? _timer;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      value = DateTime.now();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

class ClockScreenController extends ChangeNotifier {
  static const Duration actionCooldown = Duration(seconds: 5);
  static const Duration tapProcessingDelay = Duration(milliseconds: 700);

  /// Owning user for this controller instance. All persisted state
  /// (SharedPreferences keys) is namespaced by this id so that data from one
  /// user is never visible to, or overwritten by, another user on the same
  /// device.
  final String userId;

  final List<AttendanceEvent> _events = [];
  List<AttendanceEvent> get events => List.unmodifiable(_events);
  bool get hasAnyEventToday => _events.isNotEmpty;

  bool isInRange = true;
  bool isCompanyValid = true;

  String selectedLocationName = "";
  String selectedCompanyName = "";
  String? _lastPersistedEventsJson;

  int workStartHour = 9;
  int workStartMinute = 0;
  int workEndHour = 18;
  int workEndMinute = 0;

  Duration checkoutGracePeriod = const Duration(minutes: 30);

  Set<int> workingWeekdays = const {1, 2, 3, 4, 5};
  Duration maxBreakDuration = const Duration(minutes: 60);

  static bool _isValidHour(int h) => h >= 0 && h <= 23;
  static bool _isValidMinute(int m) => m >= 0 && m <= 59;

  void configureWorkingHours({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    Duration? gracePeriod,
  }) {
    if (_isValidHour(startHour) && _isValidMinute(startMinute)) {
      workStartHour = startHour;
      workStartMinute = startMinute;
    }
    if (_isValidHour(endHour) && _isValidMinute(endMinute)) {
      workEndHour = endHour;
      workEndMinute = endMinute;
    }
    if (gracePeriod != null && !gracePeriod.isNegative) {
      checkoutGracePeriod = gracePeriod;
    }
    unawaited(_persistWorkingHoursPolicy());
    notifyListeners();
  }

  void configurePolicyExtras({Set<int>? workingDays, Duration? maxBreak}) {
    if (workingDays != null && workingDays.isNotEmpty) {
      workingWeekdays = workingDays;
    }
    if (maxBreak != null && !maxBreak.isNegative) {
      maxBreakDuration = maxBreak;
    }
    unawaited(_persistWorkingHoursPolicy());
    notifyListeners();
  }

  Future<void> loadPolicyFrom(CompanyPolicyService policyService) async {
    final checkIn = await policyService.valueFor('attendance', 'check_in_time');
    final checkOut = await policyService.valueFor(
      'attendance',
      'check_out_time',
    );
    final grace = await policyService.valueFor('attendance', 'grace_period');

    final start = _parse12HourTime(checkIn);
    final end = _parse12HourTime(checkOut);
    final graceMinutes = _parseLeadingMinutes(grace);

    if (start != null || end != null || graceMinutes != null) {
      configureWorkingHours(
        startHour: start?.hour ?? workStartHour,
        startMinute: start?.minute ?? workStartMinute,
        endHour: end?.hour ?? workEndHour,
        endMinute: end?.minute ?? workEndMinute,
        gracePeriod: graceMinutes != null
            ? Duration(minutes: graceMinutes)
            : null,
      );
    }

    final workingDaysRaw = await policyService.valueFor(
      'attendance',
      'working_days',
    );
    final breakTimeRaw = await policyService.valueFor(
      'break_timing',
      'break_time',
    );

    final workingDays = _parseWorkingDays(workingDaysRaw);
    final breakMinutes = _parseLeadingMinutes(breakTimeRaw);

    if (workingDays != null || breakMinutes != null) {
      configurePolicyExtras(
        workingDays: workingDays,
        maxBreak: breakMinutes != null ? Duration(minutes: breakMinutes) : null,
      );
    }
  }

  static Set<int>? _parseWorkingDays(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    const names = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };
    final days = <int>{};
    for (final part in raw.split(',')) {
      final key = part.trim().toLowerCase();
      final weekday = names[key];
      if (weekday != null) days.add(weekday);
    }
    return days.isEmpty ? null : days;
  }

  static _ParsedTime? _parse12HourTime(String? raw) {
    if (raw == null) return null;
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$',
    ).firstMatch(raw.trim());
    if (match == null) return null;

    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return null;

    final isPm = match.group(3)!.toUpperCase() == 'PM';
    hour = hour == 12 ? (isPm ? 12 : 0) : (isPm ? hour + 12 : hour);

    return _ParsedTime(hour, minute);
  }

  static int? _parseLeadingMinutes(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'(\d+)').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  Future<void> _restoreWorkingHoursPolicy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final start = prefs.getString(_prefsKeyWorkStart);
      final end = prefs.getString(_prefsKeyWorkEnd);
      final graceMinutes = prefs.getInt(_prefsKeyGraceMinutes);

      final startParts = start?.split(':');
      if (startParts != null && startParts.length == 2) {
        final h = int.tryParse(startParts[0]);
        final m = int.tryParse(startParts[1]);
        if (h != null && m != null && _isValidHour(h) && _isValidMinute(m)) {
          workStartHour = h;
          workStartMinute = m;
        }
      }

      final endParts = end?.split(':');
      if (endParts != null && endParts.length == 2) {
        final h = int.tryParse(endParts[0]);
        final m = int.tryParse(endParts[1]);
        if (h != null && m != null && _isValidHour(h) && _isValidMinute(m)) {
          workEndHour = h;
          workEndMinute = m;
        }
      }

      if (graceMinutes != null && graceMinutes >= 0) {
        checkoutGracePeriod = Duration(minutes: graceMinutes);
      }

      final workingDaysCsv = prefs.getString(_prefsKeyWorkingDays);
      if (workingDaysCsv != null && workingDaysCsv.isNotEmpty) {
        final restored = workingDaysCsv
            .split(',')
            .map(int.tryParse)
            .whereType<int>()
            .where((d) => d >= 1 && d <= 7)
            .toSet();
        if (restored.isNotEmpty) workingWeekdays = restored;
      }

      final maxBreakMinutes = prefs.getInt(_prefsKeyMaxBreakMinutes);
      if (maxBreakMinutes != null && maxBreakMinutes >= 0) {
        maxBreakDuration = Duration(minutes: maxBreakMinutes);
      }

      if (_disposed) return;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persistWorkingHoursPolicy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKeyWorkStart,
        '$workStartHour:$workStartMinute',
      );
      await prefs.setString(_prefsKeyWorkEnd, '$workEndHour:$workEndMinute');
      await prefs.setInt(_prefsKeyGraceMinutes, checkoutGracePeriod.inMinutes);
      await prefs.setString(_prefsKeyWorkingDays, workingWeekdays.join(','));
      await prefs.setInt(_prefsKeyMaxBreakMinutes, maxBreakDuration.inMinutes);
    } catch (_) {}
  }

  /// Restores the last known geofence state (isInRange + selectedLocationName)
  /// from SharedPreferences so the UI shows the correct state immediately
  /// on startup — before the async geofence refresh completes.
  Future<void> _restoreGeofenceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedInRange = prefs.getBool(_prefsKeyIsInRange);
      final cachedLocationName = prefs.getString(_prefsKeyLocationName);
      if (_disposed) return;
      var changed = false;
      if (cachedInRange != null) {
        isInRange = cachedInRange;
        changed = true;
      }
      if (cachedLocationName != null && cachedLocationName.isNotEmpty) {
        selectedLocationName = cachedLocationName;
        changed = true;
      }
      if (changed) notifyListeners();
    } catch (_) {}
  }

  @protected
  Future<void> persistGeofenceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyIsInRange, isInRange);
      await prefs.setString(_prefsKeyLocationName, selectedLocationName);
    } catch (_) {}
  }

  DateTime get _todayWorkEnd {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, workEndHour, workEndMinute);
  }

  bool get isPastGraceThreshold {
    final now = DateTime.now();
    final graceStart = _todayWorkEnd.subtract(checkoutGracePeriod);

    return !now.isBefore(graceStart);
  }

  bool get isAfterCheckOutThreshold {
    final now = DateTime.now();
    final graceEnd = _todayWorkEnd.add(checkoutGracePeriod);

    return now.isAfter(graceEnd);
  }

  String get formattedWorkEndTime {
    final hour = workEndHour % 12 == 0 ? 12 : workEndHour % 12;
    final minute = workEndMinute.toString().padLeft(2, '0');
    final ampm = workEndHour >= 12 ? "PM" : "AM";
    return "$hour:$minute $ampm";
  }

  DateTime get _todayWorkStart {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      workStartHour,
      workStartMinute,
    );
  }

  /// NEW: Late check-in (AFTER grace window)
  bool get isAfterCheckInThreshold {
    final now = DateTime.now();
    final graceEnd = _todayWorkStart.add(checkoutGracePeriod);

    return now.isAfter(graceEnd);
  }

  /// NEW: Inside grace window (no dialogs)
  bool get isWithinCheckInGrace {
    final now = DateTime.now();
    final graceStart = _todayWorkStart.subtract(checkoutGracePeriod);
    final graceEnd = _todayWorkStart.add(checkoutGracePeriod);

    return !now.isBefore(graceStart) && !now.isAfter(graceEnd);
  }

  bool get isBeforeCheckInThreshold {
    final now = DateTime.now();
    final graceStart = _todayWorkStart.subtract(checkoutGracePeriod);

    return now.isBefore(graceStart);
  }

  String get formattedWorkStartTime {
    final hour = workStartHour % 12 == 0 ? 12 : workStartHour % 12;
    final minute = workStartMinute.toString().padLeft(2, '0');
    final ampm = workStartHour >= 12 ? "PM" : "AM";
    return "$hour:$minute $ampm";
  }

  bool isProcessing = false;
  bool isCoolingDown = false;
  Timer? _cooldownTimer;

  bool _disposed = false;

  // NOTE: these are intentionally instance getters (not `static const`).
  // Every key is namespaced with [userId] so SharedPreferences state can
  // never leak between two different users signed in on the same device.
  static const String _prefsKeyPrefixBase = 'clock_events_';
  String get _prefsKeyWorkStart => 'clock_policy_work_start_$userId';
  String get _prefsKeyWorkEnd => 'clock_policy_work_end_$userId';
  String get _prefsKeyGraceMinutes => 'clock_policy_grace_minutes_$userId';
  String get _prefsKeyWorkingDays => 'clock_policy_working_days_$userId';
  String get _prefsKeyMaxBreakMinutes =>
      'clock_policy_max_break_minutes_$userId';
  String get _prefsKeyIsInRange => 'clock_is_in_range_$userId';
  String get _prefsKeyLocationName => 'clock_selected_location_name_$userId';

  ClockScreenController({required this.userId}) {
    unawaited(_restorePersistedEvents());
    unawaited(_restoreWorkingHoursPolicy());
    unawaited(_restoreGeofenceState());
  }

  String get _todayPrefsKey {
    final now = DateTime.now();
    return '$_prefsKeyPrefixBase${userId}_${now.year}-${now.month}-${now.day}';
  }

  Future<void> _restorePersistedEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_todayPrefsKey);
      if (raw == null || _disposed) return;

      final decoded = jsonDecode(raw) as List;
      final restored = decoded
          .map((e) => AttendanceEvent.fromJson(e as Map<String, dynamic>))
          .toList();

      _events
        ..clear()
        ..addAll(restored);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persistEvents() async {
    try {
      final encoded = jsonEncode(_events.map((e) => e.toJson()).toList());
      if (encoded == _lastPersistedEventsJson) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_todayPrefsKey, encoded);
      _lastPersistedEventsJson = encoded;
    } catch (_) {}
  }

  void selectLocation(String name, {required bool inRange}) {
    selectedLocationName = name;
    isInRange = inRange;
    unawaited(persistGeofenceState());
    notifyListeners();
  }

  void selectCompany(String name, {required bool isCompany}) {
    selectedCompanyName = name;
    isCompanyValid = isCompany;
    notifyListeners();
  }

  void hydrateFromAuth({String? companyName, String? locationName}) {
    var changed = false;
    if (companyName != null &&
        companyName.isNotEmpty &&
        selectedCompanyName != companyName) {
      selectedCompanyName = companyName;
      changed = true;
    }
    if (locationName != null &&
        locationName.isNotEmpty &&
        selectedLocationName != locationName) {
      selectedLocationName = locationName;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  AttendanceDayStatus get _statusFromEvents {
    if (_events.isEmpty) return AttendanceDayStatus.checkedOut;
    final summary = AttendanceEngine.compute(_events);
    if (summary.isOnBreak) return AttendanceDayStatus.onBreak;
    if (summary.isCheckedIn) {
      final sorted = [..._events]..sort((a, b) => a.time.compareTo(b.time));
      final everHadBreak = sorted.any(
        (e) => e.type == AttendanceEventType.breakEnd,
      );
      return everHadBreak
          ? AttendanceDayStatus.endedBreak
          : AttendanceDayStatus.checkedIn;
    }
    return AttendanceDayStatus.checkedOut;
  }

  AttendanceDayStatus get effectiveStatus {
    return _statusFromEvents;
  }

  bool get isOnBreak => effectiveStatus == AttendanceDayStatus.onBreak;

  bool get isTodayWorkingDay =>
      workingWeekdays.contains(DateTime.now().weekday);

  bool get isBreakLimitReached =>
      AttendanceEngine.compute(_events).liveBreakDuration() >= maxBreakDuration;

  bool get isButtonEnabled => !isCoolingDown;

  void _addEvent(AttendanceEventType type) {
    _events.add(
      AttendanceEvent(
        id: '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(10000)}',
        type: type,
        time: DateTime.now(),
        location: selectedLocationName,
        isValidLocation: isInRange,
      ),
    );
    unawaited(_persistEvents());
  }

  @protected
  void updateEventLocationIfStillLast({
    required AttendanceEventType type,
    required DateTime time,
    required String newLocationLabel,
  }) {
    if (_disposed || _events.isEmpty) return;
    final last = _events.last;
    if (last.type != type || last.time != time) return;
    _events[_events.length - 1] = last.copyWith(location: newLocationLabel);
    unawaited(_persistEvents());
    notifyListeners();
  }

  bool get lastEventFlaggedInvalidLocation =>
      _events.isNotEmpty && !_events.last.isValidLocation;

  void _startActionCooldown() {
    _cooldownTimer?.cancel();
    isCoolingDown = true;
    _cooldownTimer = Timer(actionCooldown, () {
      if (_disposed) return;
      isCoolingDown = false;
      notifyListeners();
    });
  }

  @protected
  void revertLastEvent() {
    // REVERT LOGIC DELETED: Append-only enforcement
    throw UnsupportedError(
      "Event mutation is forbidden. System is append-only.",
    );
  }
  @protected
  void restoreEvents(List<AttendanceEvent> snapshot) {
    if (_disposed) return;

    const clockSkewTolerance = Duration(seconds: 2);
    bool isDuplicate(AttendanceEvent a, AttendanceEvent b) {
      return a.id == b.id ||
          (a.type == b.type &&
              (a.time.difference(b.time)).abs() <= clockSkewTolerance);
    }

    final merged = <AttendanceEvent>[..._events];
    for (final incoming in snapshot) {
      final exists = merged.any((existing) => isDuplicate(existing, incoming));
      if (!exists) merged.add(incoming);
    }
    merged.sort((a, b) => a.time.compareTo(b.time));

    _events
      ..clear()
      ..addAll(merged);
    unawaited(_persistEvents());
    notifyListeners();
  }

  Future<AttendanceActionResult> handleMainTap() async {
    if (isProcessing || isCoolingDown) return AttendanceActionResult.none;

    final status = _statusFromEvents;

    if (status == AttendanceDayStatus.checkedOut && !isTodayWorkingDay) {
      return AttendanceActionResult.nonWorkingDay;
    }

    isProcessing = true;
    notifyListeners();
    await Future.delayed(tapProcessingDelay);
    if (_disposed) return AttendanceActionResult.none;

    var result = AttendanceActionResult.none;

    switch (status) {
      case AttendanceDayStatus.checkedOut:
        _addEvent(AttendanceEventType.checkIn);
        _startActionCooldown();
        result = AttendanceActionResult.checkedIn;
        break;

      case AttendanceDayStatus.checkedIn:
      case AttendanceDayStatus.endedBreak:
        _addEvent(AttendanceEventType.checkOut);
        _startActionCooldown();
        result = AttendanceActionResult.checkedOut;
        break;

      case AttendanceDayStatus.onBreak:
        _addEvent(AttendanceEventType.breakEnd);
        _startActionCooldown();
        result = AttendanceActionResult.breakEnded;
        break;

      case AttendanceDayStatus.outofRange:
        break;
      case AttendanceDayStatus.lateCheckIn:
      case AttendanceDayStatus.absent:
      case AttendanceDayStatus.normal:
      case AttendanceDayStatus.missingCheckOut:
      case AttendanceDayStatus.manuallyEdited:
      case AttendanceDayStatus.weekend:
      case AttendanceDayStatus.onLeave:
      case AttendanceDayStatus.holiday:
        break;
    }

    isProcessing = false;
    notifyListeners();
    return result;
  }

  Future<AttendanceActionResult> handleBreakTap() async {
    if (isProcessing || isCoolingDown) return AttendanceActionResult.none;

    final status = _statusFromEvents;
    if (status != AttendanceDayStatus.checkedIn &&
        status != AttendanceDayStatus.endedBreak) {
      return AttendanceActionResult.none;
    }

    // NEW (Task 4 -- policy enforcement): don't allow starting another
    // break once today's break_time allowance is already used up.
    if (isBreakLimitReached) {
      return AttendanceActionResult.breakLimitReached;
    }

    isProcessing = true;
    notifyListeners();
    await Future.delayed(tapProcessingDelay);
    if (_disposed) return AttendanceActionResult.none;

    _addEvent(AttendanceEventType.breakStart);
    _startActionCooldown();

    isProcessing = false;
    notifyListeners();
    return AttendanceActionResult.breakStarted;
  }

  @override
  void dispose() {
    _disposed = true;
    _cooldownTimer?.cancel();
    super.dispose();
  }
}