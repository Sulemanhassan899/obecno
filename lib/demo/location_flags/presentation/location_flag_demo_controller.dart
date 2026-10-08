import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obecno/demo/location_flags/data/location_flag_store.dart';
import 'package:obecno/demo/location_flags/domain/location_flag_models.dart';
import 'package:obecno/demo/location_flags/engine/location_flag_background.dart';
import 'package:obecno/demo/location_flags/engine/location_flag_monitor.dart';
import 'package:obecno/demo/location_flags/engine/smart_attendance_engine.dart';
import 'package:obecno/features/more/services/native_reminder_scheduler.dart';
import 'package:obecno/features/more/services/reminder_notification_service.dart';

enum DemoGpsMode {
  insideA,
  insideC,
  outsideAll,
  unavailable,
  denied,
  timeout,
  poorAccuracy,
  mock,
}

class LocationFlagDemoController extends ChangeNotifier {
  LocationFlagDemoController({LocationFlagStore? store, DateTime? now})
    : _injected = store,
      _initialNow = now;

  final LocationFlagStore? _injected;
  final DateTime? _initialNow;

  LocationFlagStore? _store;
  LocationFlagMonitor? _monitor;
  List<LocationFlagRecord> records = [];
  List<FlagAlert> alerts = [];
  List<StatusInterval> savedIntervals = [];
  List<MissingOutsideHour> savedIssueHours = [];
  List<AutoPunchRecord> autoPunches = [];
  SmartAttendanceSettings smartSettings = const SmartAttendanceSettings();
  DemoGpsMode gpsMode = DemoGpsMode.insideA;
  String? lastMessage;
  bool ready = false;
  Timer? _tick;
  bool _ticking = false;
  bool _following = false;
  DateTime? _capturedSlot;

  /// Last 5-minute slot that already posted a premises check-in/out banner.
  DateTime? _lastPremisesNotifySlot;
  AlertType? _lastPremisesNotifyType;
  PresenceZone? _lastPresence;
  String? _lastInsideOfficeName;
  Future<void> Function()? onBeforeTick;

  /// Calendar day shown on the demo screen (history when not today).
  DateTime selectedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  /// Bumps on each refresh so the timeline can replay its animation.
  int refreshToken = 0;

  /// Clock is alive when the monitor is following live attendance.
  bool get clockAlive => ready && _following;

  bool get isViewingToday {
    final now = DateTime.now();
    return selectedDay.year == now.year &&
        selectedDay.month == now.month &&
        selectedDay.day == now.day;
  }

  PolicyWindow policy = const PolicyWindow(
    checkInMinutes: 9 * 60,
    checkOutMinutes: 18 * 60,
    graceMinutes: 5,
  );

  LocationFlagMonitor get monitor => _monitor!;
  List<AssignedOffice> get offices => monitor.offices;

  Future<void> init() async {
    _store = _injected ?? await SqliteFlagStore.open();
    final start = _initialNow ?? DateTime.now();
    selectedDay = DateTime(start.year, start.month, start.day);
    _monitor = LocationFlagMonitor(
      store: _store!,
      employeeId: 'employee_a',
      offices: demoOffices(),
      policy: policy,
      now: start,
    );
    LocationFlagBackground.bindLiveHandler(_onBackgroundTick);
    await _reload();
    ready = true;
    notifyListeners();
  }

  Future<void> _onBackgroundTick() async {
    if (!_following || !ready) {
      await LocationFlagBackground.runCaptureTick();
      if (isViewingToday) {
        await _reload();
        notifyListeners();
      }
      return;
    }
    await _tickOnce();
  }

  Future<void> followClock({
    required String employeeId,
    required List<AssignedOffice> offices,
    required bool checkedIn,
    PolicyWindow? policyWindow,
  }) async {
    if (policyWindow != null) {
      policy = policyWindow;
      monitor.policy = policyWindow;
    }
    monitor.adoptEmployee(employeeId);
    if (offices.isNotEmpty) monitor.offices = offices;
    monitor.setClock(DateTime.now());
    final saved = await _store!.sessionFor(employeeId);
    if (saved != null && saved.date == monitor.today) {
      monitor.restoreSession(saved);
    } else if (checkedIn) {
      monitor.checkIn();
    }
    smartSettings = await _store!.smartSettingsFor(employeeId);
    await _reload();
    _lastPresence = _presenceFromRecords();
    _restoreLastInsideOffice();
    _following = true;
    await _flushQueuedPunches();
    await _armBackgroundAlarms();
    notifyListeners();
    _tick?.cancel();
    if (smartSettings.smartAttendance || smartSettings.premisesNotifications) {
      unawaited(_evaluateSmartNow());
    } else {
      unawaited(_tickOnce());
    }
  }

  Future<void> _armBackgroundAlarms() async {
    if (!_following || !ready) return;
    await LocationFlagBackground.arm(
      config: LocationFlagBgConfig(
        enabled: true,
        employeeId: monitor.employeeId,
        offices: monitor.offices,
        policy: policy,
        checkedInAtMs: monitor.checkedInAt?.millisecondsSinceEpoch,
        phase: monitor.phase,
      ),
    );
    // Best-effort: always-allow location so closed-app ticks can get a fix.
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  /// Stops the 5-min timer and clears premises/smart banners (call on logout).
  Future<void> stopFollowing() async {
    _following = false;
    _tick?.cancel();
    _tick = null;
    _ticking = false;
    _capturedSlot = null;
    _lastPremisesNotifySlot = null;
    _lastPremisesNotifyType = null;
    _lastPresence = null;
    lastMessage = null;
    await LocationFlagBackground.stopLiveTracking();
    await LocationFlagBackground.cancel();
    await LocationFlagBackground.clearConfig();
    await ReminderNotificationService.instance.cancelDemoNotifications();
    notifyListeners();
  }

  /// Loads flags for a previous (or current) calendar day from SQLite.
  Future<void> selectDate(DateTime day) async {
    selectedDay = DateTime(day.year, day.month, day.day);
    await _reload();
    refreshToken++;
    notifyListeners();
  }

  /// Reloads flags from local store and optionally applies backend policy.
  /// Never clears existing location-flag checks.
  Future<void> refreshFlags({
    PolicyWindow? policyWindow,
    List<AssignedOffice>? offices,
    bool? checkedIn,
  }) async {
    if (!ready) return;
    if (policyWindow != null) {
      policy = policyWindow;
      monitor.policy = policyWindow;
    }
    if (offices != null && offices.isNotEmpty) {
      monitor.offices = offices;
    }
    monitor.setClock(DateTime.now());
    if (checkedIn == true && monitor.phase == AttendancePhase.notCheckedIn) {
      monitor.checkIn();
    }
    await onBeforeTick?.call();
    await _armBackgroundAlarms();
    await _reload();
    refreshToken++;
    notifyListeners();
    if (_following && isViewingToday) {
      _capturedSlot = null;
      unawaited(_tickOnce());
    }
  }

  PresenceZone? _presenceFromRecords() {
    for (final row in records.reversed) {
      final zone = presenceFrom(row.value);
      if (zone != null) return zone;
    }
    return null;
  }

  void _restoreLastInsideOffice() {
    for (final row in records.reversed) {
      if (row.value == FlagValue.inside &&
          row.matchedLocationName != null &&
          row.matchedLocationName!.isNotEmpty) {
        _lastInsideOfficeName = row.matchedLocationName;
        return;
      }
    }
  }

  /// Runs one capture immediately when a 5-minute slot was missed in the background.
  void onAppResumed() {
    if (!_following || !ready || _ticking) return;
    // Smart auto-punch must re-check on resume (already inside / mid-slot enter).
    if (smartSettings.smartAttendance) {
      unawaited(_evaluateSmartNow());
      return;
    }
    // Premises banners are once per 5-min slot. Pulling the shade pauses the
    // app; resume must not re-post the same notification after a swipe-away.
    if (smartSettings.premisesNotifications) {
      final slot = slotStart(DateTime.now());
      if (_capturedSlot == slot) return;
      unawaited(_evaluateSmartNow());
      return;
    }
    if (_capturedSlot == slotStart(DateTime.now())) return;
    unawaited(_tickOnce());
  }

  /// Posts a location-flag banner immediately (demo / toggle verification).
  Future<bool> sendTestLocationFlagNotification() async {
    final health = await ReminderNotificationService.instance.health();
    if (!health.notificationsAllowed) {
      await NativeReminderScheduler.openNotificationSettings();
      lastMessage =
          'Turn on "All obecno notifications" in system settings, then tap again.';
      notifyListeners();
      return false;
    }
    final shown = await ReminderNotificationService.instance.showCustom(
      id: 88025,
      title: 'Location flag',
      body: 'Demo location-flag notification. If you see this, alerts work.',
      payload: 'location-flag-test',
    );
    lastMessage = shown
        ? 'Test location-flag notification posted. Check the notification shade.'
        : 'Failed to post notification. Check system notification settings.';
    notifyListeners();
    return shown;
  }

  Future<void> setPremisesNotifications(bool value) async {
    smartSettings = smartSettings.copyWith(premisesNotifications: value);
    await _store!.saveSmartSettings(monitor.employeeId, smartSettings);
    notifyListeners();
    if (!value) return;
    // Confirm the tray path works immediately — waiting for GPS/slot made it
    // look like notifications were broken when already checked in.
    final shown = await sendTestLocationFlagNotification();
    if (!shown) {
      await ReminderNotificationService.instance.showCustom(
        id: 88021,
        title: 'Attendance notifications',
        body:
            'Premises and location-flag reminders are on. Allow notifications in system settings if you did not see a banner.',
        payload: 'premises-enabled',
      );
    }
    if (_following) unawaited(_evaluateSmartNow());
  }

  Future<void> setSmartAttendance(bool value) async {
    smartSettings = smartSettings.copyWith(smartAttendance: value);
    await _store!.saveSmartSettings(monitor.employeeId, smartSettings);
    if (!value) {
      _lastPresence = null;
      _lastInsideOfficeName = null;
      notifyListeners();
      return;
    }
    notifyListeners();
    unawaited(
      ReminderNotificationService.instance.showCustom(
        id: 88031,
        title: 'Smart attendance',
        body:
            'Smart attendance is on. Auto check-in / check-out will notify you.',
        payload: 'smart-enabled',
      ),
    );
    // Run immediately so already-inside users get auto check-in without
    // waiting for the next 5-minute slot or an outside→inside edge.
    if (_following) unawaited(_evaluateSmartNow());
  }

  /// Live GPS evaluation outside the 5-minute slot gate (toggle / resume).
  Future<void> _evaluateSmartNow() async {
    if (!ready || _ticking || !_following) return;
    _ticking = true;
    try {
      final now = DateTime.now();
      monitor.setClock(now);
      await onBeforeTick?.call();
      final sample = await _liveSample(now);
      final slot = slotStart(now);
      // Fill this slot and any earlier empty slots so "No check" gaps close
      // when the app is running / GPS is available.
      final record = await monitor.captureThroughNow(sample);
      await _processSmart(sample: sample, record: record, now: now);
      _capturedSlot = slot;
      await _armBackgroundAlarms();
      if (isViewingToday) {
        await _reload();
        notifyListeners();
      }
    } finally {
      _ticking = false;
      if (_following) _scheduleNextSlot();
    }
  }

  void _scheduleNextSlot() {
    if (!_following) return;
    _tick?.cancel();
    // Heartbeat every 30s so a late Dart timer cannot skip a 5-minute slot.
    // captureThroughNow is idempotent for already-written slots.
    _tick = Timer(const Duration(seconds: 30), () {
      unawaited(_tickOnce());
    });
  }

  Future<void> _tickOnce() async {
    if (_ticking || !ready || !_following) return;
    _ticking = true;
    try {
      final now = DateTime.now();
      monitor.setClock(now);
      final slot = slotStart(now);
      await onBeforeTick?.call();
      final sample = await _liveSample(now);
      // Always catch up empty slots in the window — do not bail just because
      // the current slot was already written (earlier gaps may still be open).
      final record = await monitor.captureThroughNow(sample);
      await _processSmart(sample: sample, record: record, now: now);
      _capturedSlot = slot;
      await _armBackgroundAlarms();
      if (isViewingToday) {
        await _reload();
        notifyListeners();
      }
    } finally {
      _ticking = false;
      if (_following) _scheduleNextSlot();
    }
  }

  Future<void> _processSmart({
    required GpsSample sample,
    required LocationFlagRecord? record,
    required DateTime now,
  }) async {
    if (!_following) return;
    var match = matchOffices(sample, monitor.offices);
    // Live GPS can flake; if the latest stored flag is inside, still allow
    // smart check-in / premises while not checked in.
    if (match.value == FlagValue.unavailable) {
      final fallback = _latestInsideMatch();
      if (fallback != null) match = fallback;
    }
    final decision = decideSmartAttendance(
      settings: smartSettings,
      match: match,
      phase: monitor.phase,
      policy: policy,
      now: now,
      previousPresence: _lastPresence,
    );

    if (decision.hasAutoPunch) {
      await _handleAutoPunch(
        kind: decision.autoPunch!,
        match: match,
        now: now,
        flagEventId: record?.eventId ?? 'smart_${now.millisecondsSinceEpoch}',
        cycleId: record?.cycleId ?? cycleIdFor(now),
      );
    } else if (decision.hasPremisesAlert) {
      final type = decision.premisesAlert!.type;
      if (type != null && !_premisesAlreadyNotified(type, now)) {
        await _emitPremisesAlert(
          decision: decision.premisesAlert!,
          match: match,
          now: now,
          flagEventId:
              record?.eventId ?? 'premises_${now.millisecondsSinceEpoch}',
          cycleId: record?.cycleId ?? cycleIdFor(now),
        );
      }
    }

    // Location-flag tray banners are independent of smart auto-punch so an
    // outside / please-check-in flag still notifies when Attendance
    // notifications are on.
    if (smartSettings.premisesNotifications) {
      await _emitLocationFlagAlertIfNeeded(
        match: match,
        record: record,
        now: now,
      );
    }

    final nextPresence = presenceFrom(match.value);
    if (nextPresence != null) _lastPresence = nextPresence;
    if (match.value == FlagValue.inside && match.matched != null) {
      _lastInsideOfficeName = match.matched!.name;
    }
  }

  MatchResult? _latestInsideMatch() {
    for (final row in records.reversed) {
      if (row.value != FlagValue.inside) continue;
      final office =
          _officeById(row.matchedLocationId) ??
          (row.matchedLocationName == null
              ? null
              : _officeByName(row.matchedLocationName!));
      if (office == null) {
        if (monitor.offices.isEmpty) return null;
        final first = monitor.offices.first;
        return MatchResult(
          value: FlagValue.inside,
          comparisons: const [],
          matched: first,
          distanceMeters: 0,
        );
      }
      return MatchResult(
        value: FlagValue.inside,
        comparisons: const [],
        matched: office,
        distanceMeters: row.distanceMeters,
      );
    }
    return null;
  }

  AssignedOffice? _officeById(String? id) {
    if (id == null) return null;
    for (final office in monitor.offices) {
      if (office.id == id) return office;
    }
    return null;
  }

  AssignedOffice? _officeByName(String name) {
    for (final office in monitor.offices) {
      if (office.name == name) return office;
    }
    return null;
  }

  Future<void> _handleAutoPunch({
    required AutoPunchKind kind,
    required MatchResult match,
    required DateTime now,
    required String flagEventId,
    required String cycleId,
  }) async {
    final id =
        'ap_${monitor.employeeId}_${kind.name}_${now.millisecondsSinceEpoch}';
    final canApply = clockAlive;
    final isCheckIn = kind == AutoPunchKind.checkIn;
    final officeName = isCheckIn
        ? ((match.matched == null || match.matched!.name.isEmpty)
              ? 'assigned office'
              : match.matched!.name)
        : ((_lastInsideOfficeName == null || _lastInsideOfficeName!.isEmpty)
              ? (match.matched?.name ?? 'assigned office')
              : _lastInsideOfficeName!);
    final punch = AutoPunchRecord(
      id: id,
      employeeId: monitor.employeeId,
      kind: kind,
      timestamp: now,
      applied: canApply,
      officeId: match.matched?.id,
      officeName: officeName,
      queuedAt: canApply ? null : now,
    );
    await _store!.upsertAutoPunch(punch);

    if (canApply) {
      await _applyAutoPunch(kind);
    }

    final message = _smartAttendanceRecordMessage(
      kind: kind,
      at: now,
      officeName: officeName,
      queued: !canApply,
    );

    await _store!.insertAlert(
      FlagAlert(
        id: 'al_${id}_notify',
        employeeId: monitor.employeeId,
        attendanceSessionId: monitor.sessionId,
        flagEventId: flagEventId,
        cycleId: cycleId,
        timestamp: now,
        type: isCheckIn ? AlertType.autoCheckIn : AlertType.autoCheckOut,
        locationStatus: match.value,
        matchedLocationId: match.matched?.id,
        message: message,
      ),
    );
    await ReminderNotificationService.instance.showCustom(
      id: isCheckIn ? 88031 : 88032,
      title: 'Smart attendance',
      body: message.replaceFirst('Smart attendance\n', ''),
      payload: isCheckIn ? 'smart-auto-check-in' : 'smart-auto-check-out',
    );
    lastMessage = message;
  }

  String _smartAttendanceRecordMessage({
    required AutoPunchKind kind,
    required DateTime at,
    required String officeName,
    required bool queued,
  }) {
    final time = _smartTimeLabel(at);
    if (kind == AutoPunchKind.checkIn) {
      final action = queued ? 'auto check-in queued' : 'auto checked in';
      return 'Smart attendance\n$action at $time at ($officeName)';
    }
    final action = queued ? 'auto check-out queued' : 'auto checked out';
    return 'Smart attendance\n$action at $time from ($officeName)';
  }

  String _smartTimeLabel(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final suffix = local.hour >= 12 ? 'pm' : 'am';
    if (local.minute == 0) return '$hour $suffix';
    return '$hour:${local.minute.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _applyAutoPunch(AutoPunchKind kind) async {
    if (kind == AutoPunchKind.checkIn) {
      monitor.checkIn();
    } else {
      monitor.checkOut();
    }
    await monitor.persistSession();
    await _armBackgroundAlarms();
  }

  Future<void> _flushQueuedPunches() async {
    if (!clockAlive) return;
    final queued = await _store!.queuedAutoPunches(monitor.employeeId);
    for (final punch in queued) {
      await _applyAutoPunch(punch.kind);
      await _store!.upsertAutoPunch(
        AutoPunchRecord(
          id: punch.id,
          employeeId: punch.employeeId,
          kind: punch.kind,
          timestamp: punch.timestamp,
          applied: true,
          officeId: punch.officeId,
          officeName: punch.officeName,
          queuedAt: punch.queuedAt,
        ),
      );
    }
  }

  /// Premises / location-flag OS banners fire at most once per 5-minute slot.
  /// Only track in-memory posts — a DB alert row alone must not block the
  /// tray (older builds wrote alerts without ever calling [showCustom]).
  bool _premisesAlreadyNotified(AlertType type, DateTime now) {
    final slotMs = slotStart(now).millisecondsSinceEpoch;
    return _lastPremisesNotifySlot?.millisecondsSinceEpoch == slotMs &&
        _lastPremisesNotifyType == type;
  }

  Future<void> _emitPremisesAlert({
    required AlertDecision decision,
    required MatchResult match,
    required DateTime now,
    required String flagEventId,
    required String cycleId,
  }) async {
    if (!_following) return;
    final type = decision.type!;
    if (_premisesAlreadyNotified(type, now)) return;

    await _store!.insertAlert(
      FlagAlert(
        id: 'al_${flagEventId}_${type.name}',
        employeeId: monitor.employeeId,
        attendanceSessionId: monitor.sessionId,
        flagEventId: flagEventId,
        cycleId: cycleId,
        timestamp: now,
        type: type,
        locationStatus: match.value,
        matchedLocationId: match.matched?.id,
        message: decision.message!,
      ),
    );
    final checkIn = type == AlertType.premisesCheckIn;
    await ReminderNotificationService.instance.showCustom(
      id: checkIn ? 88021 : 88022,
      title: checkIn ? 'Check in' : 'Check out',
      body: decision.message!,
      payload: checkIn ? 'premises-check-in' : 'premises-check-out',
    );
    _lastPremisesNotifySlot = slotStart(now);
    _lastPremisesNotifyType = type;
    lastMessage = decision.message;
  }

  Future<void> _emitLocationFlagAlertIfNeeded({
    required MatchResult match,
    required LocationFlagRecord? record,
    required DateTime now,
  }) async {
    if (!_following) return;
    final policyCheckOut = policy.onDay(now, policy.checkOutMinutes);
    final decision = decideAlert(
      value: match.value,
      phase: monitor.phase,
      officeName: match.value == FlagValue.outside ? null : match.matched?.name,
      checkoutTimeReached: !now.isBefore(
        policyCheckOut.subtract(const Duration(minutes: kFlagIntervalMinutes)),
      ),
    );

    AlertType? type = decision.type;
    String? body = decision.message;
    String title = 'Location flag';
    int notifId = 88023;
    String payload = 'location-flag';

    if (decision.send && type != null && body != null) {
      switch (type) {
        case AlertType.checkInRange:
          // Premises check-in already covered this slot.
          if (_premisesAlreadyNotified(AlertType.premisesCheckIn, now)) return;
          title = 'Location flag';
          notifId = 88025;
          payload = 'location-flag-check-in';
        case AlertType.checkOutOutside:
          title = 'Location flag';
          notifId = 88023;
          payload = 'location-flag-outside';
        case AlertType.locationUnavailable:
          title = 'Location unavailable';
          notifId = 88024;
          payload = 'location-flag-unavailable';
        default:
          return;
      }
    } else if (monitor.phase == AttendancePhase.working &&
        (match.value == FlagValue.outside ||
            record?.kind == SlotKind.outside)) {
      // Flag check landed outside while on the clock.
      type = AlertType.checkOutOutside;
      body = 'You are outside office premises. Please return or check out.';
      title = 'Location flag';
      notifId = 88023;
      payload = 'location-flag-outside';
    } else if (monitor.phase == AttendancePhase.working &&
        (record?.kind == SlotKind.missing ||
            match.value == FlagValue.unavailable)) {
      type = AlertType.locationUnavailable;
      body = 'Location flag could not be verified for this check.';
      title = 'Location flag';
      notifId = 88024;
      payload = 'location-flag-missing';
    } else {
      return;
    }

    if (type == null || body == null) return;
    if (_premisesAlreadyNotified(type, now)) return;

    await ReminderNotificationService.instance.showCustom(
      id: notifId,
      title: title,
      body: body,
      payload: payload,
    );
    _lastPremisesNotifySlot = slotStart(now);
    _lastPremisesNotifyType = type;
    lastMessage = body;
  }

  Future<GpsSample> _liveSample(DateTime time) => readLiveSample(time);

  @override
  void dispose() {
    _following = false;
    _tick?.cancel();
    super.dispose();
  }

  Future<void> setGps(DemoGpsMode mode) async {
    gpsMode = mode;
    notifyListeners();
  }

  Future<void> checkIn() async {
    monitor.checkIn();
    await _capture();
  }

  Future<void> breakIn() async {
    monitor.breakIn();
    await _capture();
  }

  Future<void> breakOut() async {
    monitor.breakOut();
    await _capture();
  }

  Future<void> checkOut() async {
    await _capture();
    monitor.checkOut();
    await monitor.markMissedSlots();
    await _reload();
    notifyListeners();
  }

  Future<void> captureSlot() => _capture();

  Future<void> advanceSlot() async {
    monitor.setClock(
      monitor.now.add(const Duration(minutes: kFlagIntervalMinutes)),
    );
    await monitor.markMissedSlots();
    await _capture();
  }

  Future<void> setOffline(bool value) async {
    monitor.offline = value;
    notifyListeners();
  }

  Future<void> sync() async {
    await monitor.syncPending();
    await _reload();
    notifyListeners();
  }

  Future<void> failNextSync() async {
    monitor.failNextSync = true;
    lastMessage = 'Next sync attempt will fail and stay retryable.';
    notifyListeners();
  }

  Future<void> switchEmployee() async {
    final next = monitor.employeeId == 'employee_a'
        ? 'employee_b'
        : 'employee_a';
    monitor.adoptEmployee(next);
    gpsMode = DemoGpsMode.insideA;
    _lastPresence = null;
    _lastInsideOfficeName = null;
    smartSettings = await _store!.smartSettingsFor(next);
    await _reload();
    lastMessage = 'Monitoring now belongs to $next.';
    notifyListeners();
  }

  Future<void> resetDay() async {
    await _store!.clearEmployee(monitor.employeeId);
    final id = monitor.employeeId;
    _monitor = LocationFlagMonitor(
      store: _store!,
      employeeId: id,
      offices: demoOffices(),
      policy: policy,
      now: DateTime(monitor.now.year, monitor.now.month, monitor.now.day, 9),
    );
    savedIntervals = [];
    savedIssueHours = [];
    autoPunches = [];
    _lastPresence = null;
    _lastInsideOfficeName = null;
    smartSettings = const SmartAttendanceSettings();
    await _reload();
    lastMessage = null;
    notifyListeners();
  }

  GpsSample _sample() {
    final time = monitor.now;
    final offices = monitor.offices;
    switch (gpsMode) {
      case DemoGpsMode.insideA:
        return sampleInside(offices[0], time);
      case DemoGpsMode.insideC:
        return sampleInside(offices[2], time);
      case DemoGpsMode.outsideAll:
        return sampleOutside(time);
      case DemoGpsMode.unavailable:
        return sampleFailed(time, GpsFailure.unavailable);
      case DemoGpsMode.denied:
        return sampleFailed(time, GpsFailure.permissionDenied);
      case DemoGpsMode.timeout:
        return sampleFailed(time, GpsFailure.timeout);
      case DemoGpsMode.poorAccuracy:
        return GpsSample(
          timestamp: time,
          latitude: offices[0].latitude,
          longitude: offices[0].longitude,
          accuracyMeters: 180,
          failure: GpsFailure.poorAccuracy,
        );
      case DemoGpsMode.mock:
        return sampleFailed(time, GpsFailure.mock);
    }
  }

  Future<void> _capture() async {
    final sample = _sample();
    final record = await monitor.capture(sample);
    await _processSmart(sample: sample, record: record, now: monitor.now);
    await _armBackgroundAlarms();
    await _reload();
    lastMessage ??= alerts.isEmpty ? null : alerts.last.message;
    if (record == null && lastMessage == null) {
      lastMessage = 'No flag written. Monitoring is stopped after check-out.';
    }
    notifyListeners();
  }

  Future<void> _reload() async {
    final day = selectedDay;
    final date = dateKey(day);
    final flagStart = policy.onDay(day, policy.visualStartMinutes);
    final flagEnd = policy.onDay(day, policy.visualEndMinutes);
    final clock = isViewingToday ? DateTime.now() : flagEnd;
    records = await _store!.flagsFor(
      employeeId: monitor.employeeId,
      date: date,
    );
    alerts = await _store!.alertsFor(monitor.employeeId);
    autoPunches = await _store!.autoPunchesFor(monitor.employeeId);
    smartSettings = await _store!.smartSettingsFor(monitor.employeeId);

    final intervals = statusIntervals(
      records,
      checkIn: flagStart,
      checkOut: flagEnd,
      now: clock,
    );
    final hours = missingOutsideHours(
      records,
      checkIn: flagStart,
      checkOut: flagEnd,
      now: clock,
    );
    await _store!.replaceStatusIntervals(
      employeeId: monitor.employeeId,
      date: date,
      intervals: intervals,
    );
    await _store!.replaceIssueHours(
      employeeId: monitor.employeeId,
      date: date,
      hours: hours,
    );
    if (isViewingToday) {
      await monitor.persistSession();
    }

    savedIntervals = await _store!.statusIntervalsFor(
      employeeId: monitor.employeeId,
      date: date,
    );
    savedIssueHours = await _store!.issueHoursFor(
      employeeId: monitor.employeeId,
      date: date,
    );
  }
}
