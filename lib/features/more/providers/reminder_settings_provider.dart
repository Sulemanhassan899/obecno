import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:obecno/features/auth/services/company_policy_service.dart';
import 'package:obecno/features/more/data/local/reminder_dao.dart';
import 'package:obecno/features/more/data/models/reminder_log.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';
import 'package:obecno/features/more/services/native_reminder_scheduler.dart';
import 'package:obecno/features/more/services/reminder_engine.dart';
import 'package:obecno/features/more/services/reminder_notification_plan.dart';
import 'package:obecno/features/more/services/reminder_notification_service.dart';

class ReminderSettingsProvider extends ChangeNotifier {
  ReminderSettingsProvider({
    required ReminderDao dao,
    required CompanyPolicyService policyService,
    required String Function() userIdProvider,
    String Function()? locationNameProvider,
  }) : _dao = dao,
       _policyService = policyService,
       _userIdProvider = userIdProvider,
       _locationNameProvider = locationNameProvider;

  final ReminderDao _dao;
  final CompanyPolicyService _policyService;
  final String Function() _userIdProvider;
  final String Function()? _locationNameProvider;

  static const defaultCheckInLabel = '09:00 AM';
  static const defaultCheckOutLabel = '06:00 PM';
  static const defaultGraceLabel = '5 mins';
  static const defaultBreakLabel = '60 mins';
  static const defaultLongerBreakLabel = '1 hour';
  static const defaultLongAttendanceHours = 12;
  static const defaultLongAttendanceMinutes =
      ReminderCopy.defaultLongAttendanceMinutes;
  static const defaultLongAttendanceLabel = '12 hours';

  Map<ReminderType, bool> _enabled = {
    for (final type in ReminderType.values)
      type:
          type != ReminderType.enterLocation &&
          type != ReminderType.leaveLocation,
  };

  TimeOfDay checkInTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay checkOutTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay policyCheckInTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay policyCheckOutTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay breakReminderTime = const TimeOfDay(hour: 13, minute: 25);
  TimeOfDay breakEndedReminderTime = const TimeOfDay(hour: 14, minute: 30);
  TimeOfDay policyBreakReminderTime = const TimeOfDay(hour: 13, minute: 25);
  TimeOfDay policyBreakEndedReminderTime = const TimeOfDay(
    hour: 14,
    minute: 30,
  );
  TimeOfDay checkInMissedTime = const TimeOfDay(hour: 9, minute: 5);
  TimeOfDay checkOutMissedTime = const TimeOfDay(hour: 18, minute: 5);
  int graceMinutes = 5;
  int checkInMissedMinutes = 5;
  int checkOutMissedMinutes = 5;
  int breakMinutes = 60;
  int longerBreakMinutes = 60;
  int longAttendanceMinutes = defaultLongAttendanceMinutes;
  int get longAttendanceHours =>
      longAttendanceMinutes >= 60 ? longAttendanceMinutes ~/ 60 : 0;
  Set<int> workingWeekdays = ReminderNotificationPlan.defaultWorkingWeekdays;

  List<ReminderPunch> _punches = const [];
  Map<ReminderType, int> _customMinutes = {};
  Timer? _watch;
  DateTime _lastWall = DateTime.now();
  bool _clockActivated = false;

  String checkInTimeLabel = defaultCheckInLabel;
  String checkOutTimeLabel = defaultCheckOutLabel;
  String breakTimeLabel = '01:25 PM';
  String breakEndedTimeLabel = '02:30 PM';
  String graceLabel = defaultGraceLabel;
  String checkInMissedLabel = '09:05 AM';
  String checkOutMissedLabel = '06:05 PM';
  String breakDurationLabel = defaultBreakLabel;
  String longerBreakLabel = defaultLongerBreakLabel;
  String longAttendanceLabel = defaultLongAttendanceLabel;

  String get longAttendanceCaption {
    final phrase = ReminderCopy.durationPhrase(longAttendanceMinutes);
    final plus = phrase.replaceFirstMapped(
      RegExp(r'^(\d+)'),
      (match) => '${match[1]}+',
    );
    return "You'll get a reminder if you've checked in for $plus without checking out.";
  }

  bool _loading = false;
  bool get isLoading => _loading;

  ReminderHealth? health;
  DateTime? testReminderAt;

  bool isEnabled(ReminderType type) => _enabled[type] ?? false;

  String _armedKey() => 'reminder_clock_armed_${_userIdProvider()}';

  /// App reopen with a saved session, or a previous Clock visit, should
  /// keep scheduling. A first-time login waits until Clock.
  static bool shouldScheduleOnLoad({
    required bool resumeExistingSession,
    required bool clockArmed,
  }) => resumeExistingSession || clockArmed;

  Future<void> load({
    bool resumeExistingSession = false,
    bool forcePolicyRefresh = false,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      if (forcePolicyRefresh) {
        await _policyService.refreshFromNetwork(force: true);
      }
      await Future.wait([_loadSettings(), _loadPolicyTimes()]);
      _enabled[ReminderType.enterLocation] = false;
      _enabled[ReminderType.leaveLocation] = false;
      _applyCustomTimes();
      final userId = _userIdProvider();
      if (userId.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final flagged = prefs.getBool(_armedKey()) ?? false;
      final scheduleNow = shouldScheduleOnLoad(
        resumeExistingSession: resumeExistingSession,
        clockArmed: flagged,
      );
      if (scheduleNow && !flagged) {
        await prefs.setBool(_armedKey(), true);
      }
      _clockActivated = scheduleNow;
      if (_clockActivated) {
        await _rescheduleNotifications();
        _startWatch();
      }
      await NativeReminderScheduler.ensureUnrestricted();
      await refreshHealth();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh: fetch latest permission clocks and reschedule.
  Future<void> refresh() =>
      load(resumeExistingSession: _clockActivated, forcePolicyRefresh: true);

  /// First-time users wait until Clock. Returning users are already armed.
  Future<void> activateFromClock() async {
    final userId = _userIdProvider();
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final alreadyArmed = prefs.getBool(_armedKey()) ?? false;
    await prefs.setBool(_armedKey(), true);
    _clockActivated = true;
    if (!alreadyArmed) {
      await Future.wait([_loadSettings(), _loadPolicyTimes()]);
      _applyCustomTimes();
    }
    // OS notifications follow the phone clock, not trusted punch time.
    await _rescheduleNotifications(now: DateTime.now());
    await NativeReminderScheduler.ensureUnrestricted();
    _startWatch();
  }

  Future<void> setEnabled(ReminderType type, bool value) async {
    _enabled[type] = value;
    notifyListeners();
    await _dao.setEnabled(
      userId: _userIdProvider(),
      type: type,
      enabled: value,
    );
    if (value) await _clearOsFired(DateTime.now(), type);
    await _persistSettingsSnapshot();
    await _rescheduleNotifications();
  }

  Future<void> setReminderTime(ReminderType type, TimeOfDay value) async {
    if (!type.canPickTime) return;
    final policy = latestTimeFor(type);
    final matchesPolicy =
        value.hour == policy.hour && value.minute == policy.minute;
    if (matchesPolicy) {
      _customMinutes.remove(type);
    } else {
      _customMinutes[type] = value.hour * 60 + value.minute;
    }
    _applyCustomTimes();
    notifyListeners();
    if (matchesPolicy) {
      await _dao.clearRemindMinutes(userId: _userIdProvider(), type: type);
    } else {
      await _dao.setRemindMinutes(
        userId: _userIdProvider(),
        type: type,
        minutes: value.hour * 60 + value.minute,
      );
    }
    await _clearOsFired(DateTime.now(), type);
    await _persistSettingsSnapshot();
    await _rescheduleNotifications();
  }

  Future<void> setLongAttendanceHours(int hoursOrMinutes) {
    return setDuration(ReminderType.veryLongAttendance, hoursOrMinutes);
  }

  int defaultDurationMinutesFor(ReminderType type) {
    switch (type) {
      case ReminderType.veryLongAttendance:
        return defaultLongAttendanceMinutes;
      case ReminderType.longerBreak:
        return 60;
      case ReminderType.checkInMissed:
      case ReminderType.checkOutMissed:
        return graceMinutes <= 0 ? 5 : graceMinutes;
      default:
        return 60;
    }
  }

  int durationMinutesFor(ReminderType type) {
    final custom = _customMinutes[type];
    if (custom == null) return defaultDurationMinutesFor(type);
    if (type == ReminderType.veryLongAttendance) {
      return ReminderCopy.durationMinutes(custom);
    }
    if (ReminderCopy.durationOptionsInMinutes.contains(custom)) return custom;
    return custom;
  }

  Future<void> setDuration(ReminderType type, int hoursOrMinutes) async {
    if (!type.canPickDuration) return;
    final value = ReminderCopy.snapDuration(hoursOrMinutes);
    final fallback = defaultDurationMinutesFor(type);
    if (value == fallback) {
      _customMinutes.remove(type);
    } else {
      _customMinutes[type] = value;
    }
    _applyCustomTimes();
    notifyListeners();
    if (value == fallback) {
      await _dao.clearRemindMinutes(userId: _userIdProvider(), type: type);
    } else {
      await _dao.setRemindMinutes(
        userId: _userIdProvider(),
        type: type,
        minutes: value,
      );
    }
    await _clearOsFired(DateTime.now(), type);
    await _persistSettingsSnapshot();
    await _rescheduleNotifications();
  }

  TimeOfDay latestTimeFor(ReminderType type) {
    switch (type) {
      case ReminderType.checkIn:
        return policyCheckInTime;
      case ReminderType.checkOut:
        return policyCheckOutTime;
      case ReminderType.breakTime:
        return policyBreakReminderTime;
      case ReminderType.breakTimeEnded:
        return policyBreakEndedReminderTime;
      case ReminderType.checkInMissed:
        return ReminderNotificationPlan.addMinutes(
          checkInTime,
          graceMinutes <= 0 ? 5 : graceMinutes,
        );
      case ReminderType.checkOutMissed:
        return ReminderNotificationPlan.addMinutes(
          checkOutTime,
          graceMinutes <= 0 ? 5 : graceMinutes,
        );
      default:
        return const TimeOfDay(hour: 23, minute: 59);
    }
  }

  TimeOfDay reminderTimeFor(ReminderType type) {
    switch (type) {
      case ReminderType.checkIn:
        return checkInTime;
      case ReminderType.checkOut:
        return checkOutTime;
      case ReminderType.breakTime:
        return breakReminderTime;
      case ReminderType.breakTimeEnded:
        return breakEndedReminderTime;
      case ReminderType.checkInMissed:
        return checkInMissedTime;
      case ReminderType.checkOutMissed:
        return checkOutMissedTime;
      default:
        return latestTimeFor(type);
    }
  }

  String reminderTimeLabelFor(ReminderType type) {
    switch (type) {
      case ReminderType.checkIn:
        return checkInTimeLabel;
      case ReminderType.checkOut:
        return checkOutTimeLabel;
      case ReminderType.breakTime:
        return breakTimeLabel;
      case ReminderType.breakTimeEnded:
        return breakEndedTimeLabel;
      case ReminderType.checkInMissed:
        return checkInMissedLabel;
      case ReminderType.checkOutMissed:
        return checkOutMissedLabel;
      default:
        return '';
    }
  }

  Future<void> cancelNotifications() {
    _watch?.cancel();
    _watch = null;
    _clockActivated = false;
    return ReminderNotificationService.instance.cancelAll();
  }

  Future<void> refreshHealth() async {
    try {
      health = await ReminderNotificationService.instance.health();
    } catch (_) {
      health = ReminderHealth.unavailable;
    }
    notifyListeners();
  }

  Future<DateTime> scheduleTestReminder() async {
    final fireAt = await ReminderNotificationService.instance
        .scheduleTestReminder();
    testReminderAt = fireAt;
    await refreshHealth();
    return fireAt;
  }

  Future<void> openReminderFix() async {
    final status = health;
    if (status == null) {
      await NativeReminderScheduler.openAppDetails();
      return;
    }
    if (!status.notificationsAllowed) {
      await NativeReminderScheduler.openNotificationSettings();
      return;
    }
    if (!status.exactAlarmsAllowed) {
      await NativeReminderScheduler.openExactAlarmSettings();
      return;
    }
    if (!status.batteryUnrestricted) {
      await NativeReminderScheduler.openBatterySettings();
      return;
    }
  }

  Future<void> resync({DateTime? now}) {
    if (!_clockActivated) return Future.value();
    return _rescheduleNotifications(now: now ?? DateTime.now());
  }

  Future<void> notifyGeofenceTransition({
    required bool entered,
    required DateTime now,
    required List<ReminderPunch> punches,
    String? locationName,
  }) async {
    return;
  }

  Future<List<ReminderLog>> syncForDay({
    required DateTime day,
    required List<ReminderPunch> punches,
    DateTime? now,
    String? locationName,
  }) async {
    _punches = List.of(punches);
    await Future.wait([_loadSettings(), _loadPolicyTimes()]);
    _applyCustomTimes();
    await _persistClockState(day, punches);
    final logs = await ReminderEngine.syncDay(
      dao: _dao,
      userId: _userIdProvider(),
      day: day,
      now: now ?? DateTime.now(),
      enabled: _enabled,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      policyCheckInTime: policyCheckInTime,
      policyCheckOutTime: policyCheckOutTime,
      breakReminderTime: breakReminderTime,
      breakEndedReminderTime: breakEndedReminderTime,
      checkInMissedTime: checkInMissedTime,
      checkOutMissedTime: checkOutMissedTime,
      graceMinutes: graceMinutes,
      checkInMissedMinutes: checkInMissedMinutes,
      checkOutMissedMinutes: checkOutMissedMinutes,
      longerBreakMinutes: longerBreakMinutes,
      breakMinutes: breakMinutes,
      longAttendanceHours: longAttendanceMinutes,
      punches: punches,
      locationName: _locationName(locationName),
    );
    await _rescheduleNotifications(now: DateTime.now(), reloadPunches: false);
    return logs;
  }

  void _startWatch() {
    _watch?.cancel();
    _lastWall = DateTime.now();
    _watch = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_onWatchTick());
    });
  }

  Future<void> _onWatchTick() async {
    final now = DateTime.now();
    final gap = now.difference(_lastWall);
    _lastWall = now;
    if (gap.abs() > const Duration(seconds: 45)) {
      await _rescheduleNotifications(now: now);
      return;
    }
    await _rescheduleNotifications(now: now, rebuildSchedule: false);
  }

  Future<void> _rescheduleNotifications({
    DateTime? now,
    bool rebuildSchedule = true,
    bool reloadPunches = true,
  }) async {
    if (!_clockActivated) return;
    final when = now ?? DateTime.now();
    if (reloadPunches) {
      _punches = await _loadTodayPunches(when);
    }
    await _persistClockState(when, _punches);
    final alreadyFired = await _loadOsFired(when);
    final place = _locationName(null);
    final status = ReminderClockStatus.fromPunches(_punches);
    final result = await ReminderNotificationService.instance.sync(
      now: when,
      enabled: _enabled,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      policyCheckInTime: policyCheckInTime,
      policyCheckOutTime: policyCheckOutTime,
      breakReminderTime: breakReminderTime,
      breakEndedReminderTime: breakEndedReminderTime,
      checkInMissedTime: checkInMissedTime,
      checkOutMissedTime: checkOutMissedTime,
      graceMinutes: graceMinutes,
      checkInMissedMinutes: checkInMissedMinutes,
      checkOutMissedMinutes: checkOutMissedMinutes,
      longerBreakMinutes: longerBreakMinutes,
      breakMinutes: breakMinutes,
      longAttendanceHours: longAttendanceMinutes,
      punches: _punches,
      workingWeekdays: workingWeekdays,
      alreadyFired: alreadyFired,
      locationName: place,
      rebuildSchedule: rebuildSchedule,
      requestPermission: rebuildSchedule,
    );
    for (final type in result.seenTypes) {
      await _markOsFired(when, type);
    }
    for (final item in result.planned) {
      if (!item.deliverImmediately) continue;
      if (!result.seenTypes.contains(item.type)) continue;
      await _persistFiredLog(item: item, when: when, status: status);
    }
    // A zoned break alarm can show without being in [planned] (already
    // delivered / leftover). Still write the timeline row.
    final day = DateTime(when.year, when.month, when.day);
    final schedule = ReminderFireSchedule.forDay(
      day: day,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      policyCheckInTime: policyCheckInTime,
      policyCheckOutTime: policyCheckOutTime,
      breakReminderTime: breakReminderTime,
      breakEndedReminderTime: breakEndedReminderTime,
      checkInMissedTime: checkInMissedTime,
      checkOutMissedTime: checkOutMissedTime,
      graceMinutes: graceMinutes,
      checkInMissedMinutes: checkInMissedMinutes,
      checkOutMissedMinutes: checkOutMissedMinutes,
      longerBreakMinutes: longerBreakMinutes,
      breakMinutes: breakMinutes,
      longAttendanceHours: longAttendanceMinutes,
      status: status,
    );
    await _persistLeftoverIfShown(
      type: ReminderType.breakTimeEnded,
      result: result,
      when: when,
      status: status,
      fireAt: schedule.breakEndedAt ?? when,
    );
    await _persistLeftoverIfShown(
      type: ReminderType.breakTime,
      result: result,
      when: when,
      status: status,
      fireAt: schedule.breakAt,
    );
    final longAt = schedule.veryLongAttendanceAt;
    if (longAt != null) {
      await _persistLeftoverIfShown(
        type: ReminderType.veryLongAttendance,
        result: result,
        when: when,
        status: status,
        fireAt: longAt,
      );
    }
  }

  Future<void> _persistLeftoverIfShown({
    required ReminderType type,
    required ReminderNotificationSyncResult result,
    required DateTime when,
    required ReminderClockStatus status,
    required DateTime fireAt,
  }) async {
    final plannedNow = result.planned.any(
      (item) => item.type == type && item.deliverImmediately,
    );
    if (!result.seenTypes.contains(type) || plannedNow) return;
    if (fireAt.isAfter(when)) return;
    await _persistFiredLog(
      item: ScheduledReminderNotification(
        id: ReminderNotificationPlan.idFor(type),
        type: type,
        fireAt: fireAt,
        title: ReminderCopy.title(type),
        body: ReminderCopy.message(type),
        deliverImmediately: true,
      ),
      when: when,
      status: status,
    );
  }

  Future<void> _persistFiredLog({
    required ScheduledReminderNotification item,
    required DateTime when,
    required ReminderClockStatus status,
  }) async {
    final log = ReminderLog(
      type: item.type,
      firedAt: item.fireAt,
      title: item.title,
      message: item.body,
      clockStatus: status.storageValue,
      deliveredAt: when,
    );
    await _dao.insertLogIfAbsent(
      userId: _userIdProvider(),
      date: when,
      log: log,
    );
    await _dao.markDelivered(
      userId: _userIdProvider(),
      date: when,
      log: log,
      deliveredAt: when,
    );
  }

  String _osFiredKey(DateTime date) {
    final userId = _userIdProvider();
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'reminder_os_fired_${userId}_$y-$m-$d';
  }

  Future<Set<ReminderType>> _loadOsFired(DateTime date) async {
    final userId = _userIdProvider();
    if (userId.isEmpty) return {};
    final fromDb = await _dao.loadDeliveredTypes(userId: userId, date: date);
    if (fromDb.isNotEmpty) return fromDb;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_osFiredKey(date)) ?? const [];
      return {
        for (final key in raw)
          if (ReminderType.fromStorageKey(key) != null)
            ReminderType.fromStorageKey(key)!,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _markOsFired(DateTime date, ReminderType type) async {
    final userId = _userIdProvider();
    if (userId.isEmpty) return;
    await _dao.markDelivered(
      userId: userId,
      date: date,
      log: ReminderLog(
        type: type,
        firedAt: date,
        title: ReminderCopy.title(type),
        message: ReminderCopy.message(
          type,
          longAttendanceHours: longAttendanceMinutes,
        ),
        clockStatus: ReminderClockStatus.fromPunches(_punches).storageValue,
        deliveredAt: date,
      ),
      deliveredAt: date,
    );
  }

  Future<void> _clearOsFired(DateTime date, ReminderType type) async {
    final userId = _userIdProvider();
    if (userId.isEmpty) return;
    await _dao.clearDelivered(userId: userId, date: date, type: type);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _osFiredKey(date);
      final next = <String>{...(prefs.getStringList(key) ?? const <String>[])}
        ..remove(type.storageKey);
      await prefs.setStringList(key, next.toList());
    } catch (_) {}
  }

  Future<List<ReminderPunch>> _loadTodayPunches(DateTime now) async {
    final userId = _userIdProvider();
    if (userId.isEmpty) return const [];
    final saved = await _dao.loadSavedPunches(userId: userId, date: now);
    if (saved != null) return saved;
    final fromClock = await _loadClockPunches(userId, now);
    if (fromClock != null) {
      await _persistClockState(now, fromClock);
      return fromClock;
    }
    return const [];
  }

  /// `null` means the clock has not stored today yet. An empty list means
  /// the Check In button is showing — do not fall back to attendance cache.
  Future<List<ReminderPunch>?> _loadClockPunches(
    String userId,
    DateTime now,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'clock_events_${userId}_${now.year}-${now.month}-${now.day}';
      if (!prefs.containsKey(key)) return null;
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final punches = <ReminderPunch>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final kind = ReminderPunchKind.fromName(item['type']?.toString() ?? '');
        if (kind == null) continue;
        final time = DateTime.tryParse(item['time']?.toString() ?? '');
        if (time == null) continue;
        punches.add(ReminderPunch(kind: kind, time: time));
      }
      return punches;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistClockState(
    DateTime day,
    List<ReminderPunch> punches,
  ) async {
    final userId = _userIdProvider();
    if (userId.isEmpty) return;
    final status = ReminderClockStatus.fromPunches(punches);
    await _dao.replacePunches(userId: userId, date: day, punches: punches);
    await _dao.saveDayState(
      userId: userId,
      date: day,
      status: status,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      breakReminderTime: breakReminderTime,
      breakEndedReminderTime: breakEndedReminderTime,
      policyCheckInTime: policyCheckInTime,
      policyCheckOutTime: policyCheckOutTime,
      graceMinutes: graceMinutes,
      breakMinutes: breakMinutes,
      longAttendanceHours: longAttendanceMinutes,
    );
  }

  Future<void> _persistSettingsSnapshot() async {
    final userId = _userIdProvider();
    if (userId.isEmpty) return;
    await _dao.persistMissingSettings(
      userId: userId,
      enabled: _enabled,
      remindMinutes: _customMinutes,
    );
  }

  String _locationName(String? locationName) {
    final explicit = locationName?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    final fromAuth = _locationNameProvider?.call().trim() ?? '';
    return fromAuth.isNotEmpty ? fromAuth : 'work';
  }

  Future<void> _loadSettings() async {
    final userId = _userIdProvider();
    _enabled = await _dao.loadSettings(userId);
    _customMinutes = await _dao.loadRemindMinutes(userId);
    await _dao.persistMissingSettings(
      userId: userId,
      enabled: _enabled,
      remindMinutes: _customMinutes,
    );
  }

  Future<void> _loadPolicyTimes() async {
    final checkIn = await _policyService.valueFor(
      'attendance',
      'check_in_time',
    );
    final checkOut = await _policyService.valueFor(
      'attendance',
      'check_out_time',
    );
    final grace = await _policyService.valueFor('attendance', 'grace_period');
    final breakTime =
        await _policyService.valueFor('attendance', 'break_time') ??
        await _policyService.valueFor('break_timing', 'break_time');

    final workingDaysRaw = await _policyService.valueFor(
      'attendance',
      'working_days',
    );

    policyCheckInTime = _parseTimeOfDay(checkIn) ?? policyCheckInTime;
    policyCheckOutTime = _parseTimeOfDay(checkOut) ?? policyCheckOutTime;
    graceMinutes = _parseLeadingMinutes(grace) ?? graceMinutes;
    breakMinutes = _parseLeadingMinutes(breakTime) ?? breakMinutes;
    workingWeekdays = _parseWorkingDays(workingDaysRaw) ?? workingWeekdays;

    policyBreakReminderTime = ReminderNotificationPlan.defaultBreakReminderTime(
      checkInTime: policyCheckInTime,
      checkOutTime: policyCheckOutTime,
    );
    policyBreakEndedReminderTime =
        ReminderNotificationPlan.defaultBreakEndedReminderTime(
          checkInTime: policyCheckInTime,
          checkOutTime: policyCheckOutTime,
          breakMinutes: breakMinutes,
        );

    graceLabel = '$graceMinutes mins';
    breakDurationLabel = breakMinutes >= 60 && breakMinutes % 60 == 0
        ? '${breakMinutes ~/ 60} ${breakMinutes == 60 ? 'hour' : 'hours'}'
        : '$breakMinutes mins';
  }

  void _applyCustomTimes() {
    checkInTime = _resolvedTime(ReminderType.checkIn, policyCheckInTime);
    checkOutTime = _resolvedTime(ReminderType.checkOut, policyCheckOutTime);
    breakReminderTime = _resolvedTime(
      ReminderType.breakTime,
      policyBreakReminderTime,
    );
    breakEndedReminderTime = _resolvedTime(
      ReminderType.breakTimeEnded,
      policyBreakEndedReminderTime,
    );
    checkInTimeLabel = _formatTime(checkInTime);
    checkOutTimeLabel = _formatTime(checkOutTime);
    breakTimeLabel = _formatTime(breakReminderTime);
    breakEndedTimeLabel = _formatTime(breakEndedReminderTime);
    checkInMissedTime = _resolvedTime(
      ReminderType.checkInMissed,
      ReminderNotificationPlan.addMinutes(
        checkInTime,
        graceMinutes <= 0 ? 5 : graceMinutes,
      ),
    );
    checkOutMissedTime = _resolvedTime(
      ReminderType.checkOutMissed,
      ReminderNotificationPlan.addMinutes(
        checkOutTime,
        graceMinutes <= 0 ? 5 : graceMinutes,
      ),
    );
    checkInMissedLabel = _formatTime(checkInMissedTime);
    checkOutMissedLabel = _formatTime(checkOutMissedTime);
    final custom = _customMinutes[ReminderType.veryLongAttendance];
    longAttendanceMinutes = custom == null
        ? defaultLongAttendanceMinutes
        : ReminderCopy.durationMinutes(custom);
    longAttendanceLabel = ReminderCopy.durationPhrase(longAttendanceMinutes);
    checkInMissedMinutes = _offsetMinutes(checkInTime, checkInMissedTime);
    checkOutMissedMinutes = _offsetMinutes(checkOutTime, checkOutMissedTime);
    longerBreakMinutes = durationMinutesFor(ReminderType.longerBreak);
    longerBreakLabel = _customMinutes[ReminderType.longerBreak] == null
        ? defaultLongerBreakLabel
        : ReminderCopy.durationPhrase(longerBreakMinutes);
  }

  TimeOfDay _resolvedTime(ReminderType type, TimeOfDay fallback) {
    final custom = _customMinutes[type];
    if (custom == null) return fallback;
    return _minutesToTime(custom);
  }

  static int _offsetMinutes(TimeOfDay start, TimeOfDay end) {
    var span =
        ReminderNotificationPlan.minutesOf(end) -
        ReminderNotificationPlan.minutesOf(start);
    if (span < 0) span += 24 * 60;
    return span;
  }

  static TimeOfDay _minutesToTime(int minutes) {
    final wrapped = minutes.clamp(0, 23 * 60 + 59);
    return TimeOfDay(hour: wrapped ~/ 60, minute: wrapped % 60);
  }

  static TimeOfDay? _parseTimeOfDay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();
    final ampm = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$',
    ).firstMatch(value);
    if (ampm != null) {
      var hour = int.tryParse(ampm.group(1)!);
      final minute = int.tryParse(ampm.group(2)!);
      if (hour == null || minute == null) return null;
      final isPm = ampm.group(3)!.toUpperCase() == 'PM';
      hour = hour == 12 ? (isPm ? 12 : 0) : (isPm ? hour + 12 : hour);
      return TimeOfDay(hour: hour, minute: minute);
    }

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static int? _parseLeadingMinutes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final match = RegExp(r'(\d+)').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
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

  static String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.period == DayPeriod.pm ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $ampm';
  }
}
