import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/auth/services/company_policy_service.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:obecno/features/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:obecno/features/clock/services/employee_trusted_time.dart';

enum AttendanceActionResult {
  checkedIn,
  checkedOut,
  breakStarted,
  breakEnded,
  outOfRange,
  nonWorkingDay,
  breakLimitReached,
  timeUnavailable,
  none,
}

class _ClockPunchSession {
  const _ClockPunchSession({
    required this.checkInTime,
    required this.events,
    this.checkOutTime,
  });

  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final List<AttendanceEvent> events;

  bool get isClosed => checkOutTime != null;
}

class _ParsedTime {
  const _ParsedTime(this.hour, this.minute);
  final int hour;
  final int minute;
}

class ClockTicker extends ValueNotifier<DateTime> {
  ClockTicker({DateTime Function()? now})
    : _now = now,
      super((now ?? DateTime.now)());

  DateTime Function()? _now;
  Timer? _timer;

  set now(DateTime Function()? value) => _now = value;

  DateTime _read() => _now?.call() ?? DateTime.now();

  void start() {
    _timer?.cancel();
    value = _read();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      value = _read();
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

  /// Open session stays active across midnight until check-out, or until this
  /// elapses from the session's check-in — then an automatic check-out is
  /// punched (time + location) and the button resets to Check In.
  static const Duration maxOpenSessionDuration = Duration(hours: 24);

  /// Owning user for this controller instance. All persisted state
  /// (SharedPreferences keys) is namespaced by this id so that data from one
  /// user is never visible to, or overwritten by, another user on the same
  /// device.
  final String userId;

  final EmployeeTrustedTime? trustedTime;

  /// Online flag used only when stamping a punch (whether to consult an
  /// extra trusted-time source). Offline queue still freezes the issued time.
  @protected
  bool trustedNetworkOnline = true;

  String? lastTrustedTimeError;

  DateTime get clockNow => trustedTime?.displayNow() ?? DateTime.now();

  /// Phone wall clock — UI only. Never sent to the server.
  DateTime get phoneNow => DateTime.now();

  bool get rebootDetected => trustedTime?.rebootDetected ?? false;

  bool get sessionEndedByReboot => trustedTime?.sessionEndedByReboot ?? false;

  bool get canIssueTrustedPunch => trustedTime != null && trustedTime!.canPunch;

  final List<AttendanceEvent> _events = [];
  List<AttendanceEvent> get events =>
      List.unmodifiable(_activeEvents(clockNow));
  bool get hasAnyEventToday => _activeEvents(clockNow).isNotEmpty;

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
    final breakTimeRaw =
        await policyService.valueFor('attendance', 'break_time') ??
        await policyService.valueFor('break_timing', 'break_time');

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
    final now = clockNow;
    return DateTime(now.year, now.month, now.day, workEndHour, workEndMinute);
  }

  bool get isPastGraceThreshold {
    final now = clockNow;
    final graceStart = _todayWorkEnd.subtract(checkoutGracePeriod);

    return !now.isBefore(graceStart);
  }

  bool get isAfterCheckOutThreshold {
    final now = clockNow;
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
    final now = clockNow;
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
    final now = clockNow;
    final graceEnd = _todayWorkStart.add(checkoutGracePeriod);

    return now.isAfter(graceEnd);
  }

  /// NEW: Inside grace window (no dialogs)
  bool get isWithinCheckInGrace {
    final now = clockNow;
    final graceStart = _todayWorkStart.subtract(checkoutGracePeriod);
    final graceEnd = _todayWorkStart.add(checkoutGracePeriod);

    return !now.isBefore(graceStart) && !now.isAfter(graceEnd);
  }

  bool get isBeforeCheckInThreshold {
    final now = clockNow;
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
  bool _maxSessionAutoCheckoutInFlight = false;

  /// Bumped on server-driven [replaceLiveEvents] so a late prefs restore
  /// cannot resurrect a phantom open session after reconcile cleared it.
  int _liveEventsEpoch = 0;
  Future<void>? _eventsRestoreFuture;

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

  ClockScreenController({required this.userId, this.trustedTime}) {
    _eventsRestoreFuture = _restorePersistedEvents();
    unawaited(_restoreWorkingHoursPolicy());
    unawaited(_restoreGeofenceState());
  }

  /// Wait until local prefs have been loaded (Call before first reconcile).
  Future<void> ensureEventsRestored() =>
      _eventsRestoreFuture ?? Future<void>.value();

  String get _activePrefsKey => '${_prefsKeyPrefixBase}${userId}_active';

  String _prefsKeyForCalendarDay(DateTime day) =>
      '$_prefsKeyPrefixBase${userId}_${day.year}-${day.month}-${day.day}';

  Future<void> _restorePersistedEvents() async {
    final epochAtStart = _liveEventsEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = clockNow;
      // Active key is the live session. When it exists (even as `[]` after
      // check-out / 24h reset), do not merge yesterday's calendar mirror or
      // the Check In button comes back as still checked in.
      final keys = prefs.containsKey(_activePrefsKey)
          ? <String>[_activePrefsKey]
          : <String>{
              _prefsKeyForCalendarDay(now),
              _prefsKeyForCalendarDay(now.subtract(const Duration(days: 1))),
            }.toList();

      final restored = <AttendanceEvent>[];
      for (final key in keys) {
        restored.addAll(_eventsFromPrefsKey(prefs, key));
      }
      if (_disposed) return;
      // Server reconcile already won — do not revive a ghost check-in.
      if (epochAtStart != _liveEventsEpoch) return;
      if (restored.isEmpty) {
        // Still persist `[]` under the active key so reminders / relaunches
        // see an authoritative empty session instead of stale day mirrors.
        if (prefs.containsKey(_activePrefsKey)) {
          unawaited(_persistEvents());
        }
        return;
      }

      restoreEvents(restored);
    } catch (_) {}
  }

  List<AttendanceEvent> _eventsFromPrefsKey(
    SharedPreferences prefs,
    String key,
  ) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <AttendanceEvent>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        out.add(AttendanceEvent.fromJson(item));
      } else if (item is Map) {
        out.add(AttendanceEvent.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return out;
  }

  /// Open sessions still stored under calendar-day prefs (offline fallback).
  List<AttendanceEvent> openSessionsFromDayMirrorsWithPrefs(
    SharedPreferences prefs, [
    DateTime? at,
  ]) => _openSessionEventsFromDayMirrors(prefs, at ?? clockNow);

  List<AttendanceEvent> _openSessionEventsFromDayMirrors(
    SharedPreferences prefs,
    DateTime now,
  ) {
    final fromDays = <AttendanceEvent>[
      ..._eventsFromPrefsKey(prefs, _prefsKeyForCalendarDay(now)),
      ..._eventsFromPrefsKey(
        prefs,
        _prefsKeyForCalendarDay(now.subtract(const Duration(days: 1))),
      ),
    ];
    if (fromDays.isEmpty) return const [];

    final kept = <AttendanceEvent>[];
    for (final session in _sessionsFrom(fromDays)) {
      if (_sessionIsOpenWithinLimit(session, now) ||
          _isOpenSessionPastLimit(session, now)) {
        kept.addAll(session.events);
      }
    }
    return kept;
  }

  /// Drop open (no check-out) sessions from today/yesterday day mirrors so a
  /// later offline/align path cannot revive a ghost check-in the server closed.
  Future<void> discardOpenSessionsFromDayMirrors([DateTime? at]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = at ?? clockNow;
      for (final day in [now, now.subtract(const Duration(days: 1))]) {
        final key = _prefsKeyForCalendarDay(day);
        final stored = _eventsFromPrefsKey(prefs, key);
        if (stored.isEmpty) continue;
        final closedOnly = <AttendanceEvent>[];
        for (final session in _sessionsFrom(stored)) {
          if (session.isClosed) closedOnly.addAll(session.events);
        }
        await prefs.setString(
          key,
          jsonEncode(closedOnly.map((e) => e.toJson()).toList()),
        );
      }
    } catch (_) {}
  }

  Future<void> _persistEvents() async {
    try {
      final now = clockNow;
      final active = _activeEvents(now);
      final encoded = jsonEncode(active.map((e) => e.toJson()).toList());
      final prefs = await SharedPreferences.getInstance();

      // Active key may stay unchanged (e.g. empty both before and after a
      // 24h auto check-out on the next calendar day) while the check-in-day
      // mirror still needs the new check-out punch written.
      if (encoded != _lastPersistedEventsJson) {
        await prefs.setString(_activePrefsKey, encoded);
        _lastPersistedEventsJson = encoded;
      }

      // Also mirror each session under its check-in calendar day so attendance
      // history can attribute overnight punches to the session-start date.
      final bySessionDay = <String, List<AttendanceEvent>>{};
      for (final session in _sessionsFrom(_events)) {
        final start = session.checkInTime;
        if (!_isSameCalendarDay(start, now) &&
            !_isSameCalendarDay(start, now.subtract(const Duration(days: 1))) &&
            !_sessionIsOpenWithinLimit(session, now) &&
            !_isOpenSessionPastLimit(session, now)) {
          continue;
        }
        final key = _prefsKeyForCalendarDay(start);
        bySessionDay
            .putIfAbsent(key, () => <AttendanceEvent>[])
            .addAll(session.events);
      }
      for (final entry in bySessionDay.entries) {
        await prefs.setString(
          entry.key,
          jsonEncode(entry.value.map((e) => e.toJson()).toList()),
        );
      }
    } catch (_) {}
  }

  static bool _isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Sessions that drive the clock button/card at [now]:
  /// - an open session whose check-in is still within 24h, or
  /// - completed sessions whose check-in falls on [now]'s calendar day.
  ///
  /// Open sessions past 24h are excluded here so the button resets, but they
  /// stay in [_events] until [ensureMaxSessionAutoCheckout] punches check-out.
  List<AttendanceEvent> _activeEvents(DateTime now) {
    final kept = <AttendanceEvent>[];
    for (final session in _sessionsFrom(_events)) {
      if (_sessionIsOpenWithinLimit(session, now) ||
          (session.isClosed && _isSameCalendarDay(session.checkInTime, now))) {
        kept.addAll(session.events);
      }
    }
    return kept;
  }

  bool _sessionIsOpenWithinLimit(_ClockPunchSession session, DateTime now) {
    if (session.isClosed) return false;
    final age = now.difference(session.checkInTime);
    return !age.isNegative && age < maxOpenSessionDuration;
  }

  bool _isOpenSessionPastLimit(_ClockPunchSession session, DateTime now) {
    if (session.isClosed) return false;
    final age = now.difference(session.checkInTime);
    return !age.isNegative && age >= maxOpenSessionDuration;
  }

  /// Punches check-out (trusted time + selected location) when an open
  /// session has reached [maxOpenSessionDuration], then prunes so the
  /// button resets to Check In. History stays on the check-in calendar day.
  Future<AttendanceActionResult> ensureMaxSessionAutoCheckout() async {
    if (_disposed || _maxSessionAutoCheckoutInFlight) {
      return AttendanceActionResult.none;
    }

    final now = clockNow;
    final expired = _sessionsFrom(
      _events,
    ).any((session) => _isOpenSessionPastLimit(session, now));
    if (!expired) return AttendanceActionResult.none;

    if (!canIssueTrustedPunch) {
      return AttendanceActionResult.timeUnavailable;
    }

    _maxSessionAutoCheckoutInFlight = true;
    try {
      // Direct check-out even if on break — one punch closes the session.
      if (!await _addEvent(AttendanceEventType.checkOut)) {
        return AttendanceActionResult.timeUnavailable;
      }
      // _addEvent persists async; await so the check-in-day mirror includes
      // this auto check-out before prune drops the closed overnight session.
      await _persistEvents();
      _pruneInactiveEvents(clockNow);
      if (!_disposed) notifyListeners();
      return AttendanceActionResult.checkedOut;
    } finally {
      _maxSessionAutoCheckoutInFlight = false;
    }
  }

  void _pruneInactiveEvents(DateTime now) {
    // Keep open-past-24h sessions in memory until auto check-out punches them;
    // do not silently drop an unclosed session.
    final kept = <AttendanceEvent>[];
    for (final session in _sessionsFrom(_events)) {
      if (_sessionIsOpenWithinLimit(session, now) ||
          (session.isClosed && _isSameCalendarDay(session.checkInTime, now)) ||
          _isOpenSessionPastLimit(session, now)) {
        kept.addAll(session.events);
      }
    }
    if (kept.length == _events.length && kept.every(_events.contains)) {
      return;
    }
    _events
      ..clear()
      ..addAll(kept);
  }

  static List<_ClockPunchSession> _sessionsFrom(List<AttendanceEvent> events) {
    if (events.isEmpty) return const [];
    final sorted = [...events]
      ..sort((a, b) => a.effectiveTime.compareTo(b.effectiveTime));

    final sessions = <_ClockPunchSession>[];
    var current = <AttendanceEvent>[];
    DateTime? checkInTime;
    // Portal may store overnight check-out on the same attendance_date with
    // an early morning clock (e.g. 12:05 AM) before the day's first check-in
    // chronologically — hold it to close a later evening open session.
    final orphanEarlyCheckOuts = <AttendanceEvent>[];

    DateTime effectiveOut(DateTime raw, DateTime openStart) {
      if (raw.isAfter(openStart)) return raw;
      return raw.add(const Duration(days: 1));
    }

    for (final event in sorted) {
      if (event.type == AttendanceEventType.checkIn && current.isEmpty) {
        current = [event];
        checkInTime = event.effectiveTime;
        continue;
      }
      if (current.isEmpty || checkInTime == null) {
        if (event.type == AttendanceEventType.checkOut) {
          orphanEarlyCheckOuts.add(event);
        }
        continue;
      }

      current.add(event);
      if (event.type == AttendanceEventType.checkOut) {
        sessions.add(
          _ClockPunchSession(
            checkInTime: checkInTime,
            events: List<AttendanceEvent>.unmodifiable(current),
            checkOutTime: effectiveOut(event.effectiveTime, checkInTime),
          ),
        );
        current = <AttendanceEvent>[];
        checkInTime = null;
      }
    }

    if (current.isNotEmpty && checkInTime != null) {
      if (orphanEarlyCheckOuts.isNotEmpty) {
        final orphan = orphanEarlyCheckOuts.removeLast();
        current = [...current, orphan];
        sessions.add(
          _ClockPunchSession(
            checkInTime: checkInTime,
            events: List<AttendanceEvent>.unmodifiable(current),
            checkOutTime: effectiveOut(orphan.effectiveTime, checkInTime),
          ),
        );
      } else {
        sessions.add(
          _ClockPunchSession(
            checkInTime: checkInTime,
            events: List<AttendanceEvent>.unmodifiable(current),
          ),
        );
      }
    }
    return sessions;
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
    final active = _activeEvents(clockNow);
    if (active.isEmpty) return AttendanceDayStatus.checkedOut;
    final summary = AttendanceEngine.compute(active);
    if (summary.isOnBreak) return AttendanceDayStatus.onBreak;
    if (summary.isCheckedIn) {
      final sorted = [...active]
        ..sort((a, b) => a.effectiveTime.compareTo(b.effectiveTime));
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

  bool get isTodayWorkingDay => workingWeekdays.contains(clockNow.weekday);

  bool get isBreakLimitReached =>
      AttendanceEngine.compute(
        _activeEvents(clockNow),
      ).liveBreakDuration(now: clockNow) >=
      maxBreakDuration;

  bool get isButtonEnabled => !isCoolingDown && canIssueTrustedPunch;

  /// Smart Attendance geofence punch — reuses [_addEvent], skips duplicates.
  @protected
  Future<AttendanceActionResult> applySmartAttendancePunch({
    required bool checkIn,
  }) async {
    if (_disposed || isProcessing || isCoolingDown) {
      return AttendanceActionResult.none;
    }

    final autoClosed = await ensureMaxSessionAutoCheckout();
    if (autoClosed == AttendanceActionResult.checkedOut) {
      return autoClosed;
    }

    _pruneInactiveEvents(clockNow);
    final status = _statusFromEvents;

    if (checkIn) {
      if (status != AttendanceDayStatus.checkedOut) {
        return AttendanceActionResult.none;
      }
      isProcessing = true;
      notifyListeners();
      try {
        if (!await _addEvent(AttendanceEventType.checkIn)) {
          return AttendanceActionResult.timeUnavailable;
        }
        _startActionCooldown();
        return AttendanceActionResult.checkedIn;
      } finally {
        isProcessing = false;
        notifyListeners();
      }
    }

    if (status == AttendanceDayStatus.checkedOut) {
      return AttendanceActionResult.none;
    }

    isProcessing = true;
    notifyListeners();
    try {
      // Direct check-out even if on break — one production punch, same as
      // AttendanceEngine (check-out clears on-break state).
      if (!await _addEvent(AttendanceEventType.checkOut)) {
        return AttendanceActionResult.timeUnavailable;
      }
      _startActionCooldown();
      return AttendanceActionResult.checkedOut;
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  Future<bool> _addEvent(AttendanceEventType type) async {
    lastTrustedTimeError = null;
    final source = trustedTime;
    if (source == null) {
      lastTrustedTimeError = 'Trusted time is not ready.';
      return false;
    }

    final result = await source.issuePunch(networkOnline: trustedNetworkOnline);
    final punch = result.punch;
    if (!result.isOk || punch == null) {
      lastTrustedTimeError = result.error ?? 'Cannot issue authoritative time.';
      return false;
    }

    // Phone wall-clock is stored for detection only. [time] is what the
    // server must receive — never DateTime.now().
    final at = punch.timeSentToServer;
    _events.add(
      AttendanceEvent(
        id: '${at.microsecondsSinceEpoch}_${math.Random().nextInt(10000)}',
        type: type,
        time: at,
        location: selectedLocationName,
        isValidLocation: isInRange,
        phoneWallClock: punch.phoneWallClock,
        calculatedActualTime: punch.calculatedActualTime,
        clockChanged: punch.clockChanged,
        clockDifference: punch.clockDifference,
        timeComparison: punch.comparison,
        monotonicElapsed: punch.monotonicElapsed,
      ),
    );
    unawaited(_persistEvents());
    return true;
  }

  @protected
  AttendanceEvent? get lastRecordedEvent =>
      _events.isEmpty ? null : _events.last;

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

  bool get lastEventFlaggedInvalidLocation {
    final active = _activeEvents(clockNow);
    return active.isNotEmpty && !active.last.isValidLocation;
  }

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

    final merged = <AttendanceEvent>[..._events];
    for (final incoming in snapshot) {
      final index = merged.indexWhere(
        (existing) => existing.isSamePunchAs(incoming),
      );
      if (index >= 0) {
        merged[index] = AttendanceEvent.preferAuthoritative(
          merged[index],
          incoming,
        );
      } else {
        merged.add(incoming);
      }
    }
    merged.sort((a, b) => a.effectiveTime.compareTo(b.effectiveTime));
    final collapsed = AttendanceEngine.collapseDuplicatePunches(merged);

    _events
      ..clear()
      ..addAll(collapsed);
    _pruneInactiveEvents(clockNow);
    unawaited(_persistEvents());
    notifyListeners();
  }

  /// Replace live events (no union). Used when local open state must yield
  /// to the server after a rejected punch.
  @protected
  void replaceLiveEvents(List<AttendanceEvent> next) {
    if (_disposed) return;
    _liveEventsEpoch++;
    final collapsed = AttendanceEngine.collapseDuplicatePunches([...next])
      ..sort((a, b) => a.effectiveTime.compareTo(b.effectiveTime));
    _events
      ..clear()
      ..addAll(collapsed);
    // Mirror CLOSED sessions to check-in day prefs BEFORE prune, so a
    // yesterday closed day overwrites any ghost open check-in still stored.
    unawaited(_forceMirrorClosedSessions(List.of(_events)));
    _pruneInactiveEvents(clockNow);
    unawaited(_persistEvents());
    notifyListeners();
  }

  /// Writes closed sessions under their check-in calendar day even when the
  /// live clock has already moved to the next day (prune would skip them).
  Future<void> _forceMirrorClosedSessions(List<AttendanceEvent> source) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bySessionDay = <String, List<AttendanceEvent>>{};
      for (final session in _sessionsFrom(source)) {
        if (!session.isClosed) continue;
        final key = _prefsKeyForCalendarDay(session.checkInTime);
        bySessionDay
            .putIfAbsent(key, () => <AttendanceEvent>[])
            .addAll(session.events);
      }
      for (final entry in bySessionDay.entries) {
        await prefs.setString(
          entry.key,
          jsonEncode(entry.value.map((e) => e.toJson()).toList()),
        );
      }
    } catch (_) {}
  }

  /// Public entry-point used by the Clock details sheet after it fetches the
  /// full today timeline from the attendance API.
  ///
  /// API today is authoritative — replace that calendar day's punches instead
  /// of unioning with local phantoms (keeps card / sheet Check-In correct).
  void mergeTodayEvents(List<AttendanceEvent> todayEvents) {
    if (todayEvents.isEmpty) return;
    final day = todayEvents.first.effectiveTime;
    final otherDays = _events
        .where((e) => !_isSameCalendarDay(e.effectiveTime, day))
        .toList();
    replaceLiveEvents([...otherDays, ...todayEvents]);
  }

  Future<AttendanceActionResult> handleMainTap() async {
    if (isProcessing || isCoolingDown) return AttendanceActionResult.none;

    final autoClosed = await ensureMaxSessionAutoCheckout();
    if (autoClosed == AttendanceActionResult.checkedOut) {
      return autoClosed;
    }

    _pruneInactiveEvents(clockNow);

    final status = _statusFromEvents;

    isProcessing = true;
    notifyListeners();
    await Future.delayed(tapProcessingDelay);
    if (_disposed) return AttendanceActionResult.none;

    var result = AttendanceActionResult.none;

    switch (status) {
      case AttendanceDayStatus.checkedOut:
        if (!await _addEvent(AttendanceEventType.checkIn)) {
          result = AttendanceActionResult.timeUnavailable;
          break;
        }
        _startActionCooldown();
        result = AttendanceActionResult.checkedIn;
        break;

      case AttendanceDayStatus.checkedIn:
      case AttendanceDayStatus.endedBreak:
        if (!await _addEvent(AttendanceEventType.checkOut)) {
          result = AttendanceActionResult.timeUnavailable;
          break;
        }
        _startActionCooldown();
        result = AttendanceActionResult.checkedOut;
        break;

      case AttendanceDayStatus.onBreak:
        if (!await _addEvent(AttendanceEventType.breakEnd)) {
          result = AttendanceActionResult.timeUnavailable;
          break;
        }
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

    final autoClosed = await ensureMaxSessionAutoCheckout();
    if (autoClosed == AttendanceActionResult.checkedOut) {
      return autoClosed;
    }

    _pruneInactiveEvents(clockNow);

    final status = _statusFromEvents;
    if (status != AttendanceDayStatus.checkedIn &&
        status != AttendanceDayStatus.endedBreak) {
      return AttendanceActionResult.none;
    }

    // Break limit removed: employees may start as many breaks as needed.
    // maxBreakDuration is still used only for break-end ETA display.

    isProcessing = true;
    notifyListeners();
    await Future.delayed(tapProcessingDelay);
    if (_disposed) return AttendanceActionResult.none;

    if (!await _addEvent(AttendanceEventType.breakStart)) {
      isProcessing = false;
      notifyListeners();
      return AttendanceActionResult.timeUnavailable;
    }
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
