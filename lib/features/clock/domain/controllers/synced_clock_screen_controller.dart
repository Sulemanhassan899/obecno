import 'dart:async';
import 'dart:convert';

import 'package:obecno/core/constants/app_strings.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/auth/services/company_policy_service.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:obecno/features/clock/domain/controllers/clock_controller.dart';
import 'package:obecno/shared/location/data/location_model.dart';
import 'package:obecno/shared/location/service/attendance_payload_model.dart';
import 'package:obecno/shared/location/service/attendance_permission_service.dart';
import 'package:obecno/shared/location/service/location_service.dart';
import 'package:obecno/shared/location/service/geofence_helper.dart';
import 'package:obecno/shared/location/service/office_geofence_matcher.dart';
import 'package:obecno/shared/location/service/reverse_geocoding_service.dart';

import '../../repositories/clock_attendance_repository.dart';
import '../../presentation/widgets/clock_attendance_engine.dart';
import '../../services/sync_service.dart';
import '../../services/employee_trusted_time.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';
import 'package:obecno/features/employee_module/attendance/domain/attendance_timeline_assembler.dart';
import 'package:obecno/main.dart';
import 'package:obecno/core/constants/app_enums.dart' show AttendanceDayStatus;

class SyncedClockScreenController extends ClockScreenController {
  SyncedClockScreenController({
    required AttendanceRepository repository,
    required CompanyPolicyService companyPolicyService,
    required String userId,
    AttendancePermissionService permissionService =
        const AttendancePermissionService(),
    LocationService? locationService,
    SyncService? syncService,
    EmployeeTrustedTime? trustedTime,
  }) : _repository = repository,
       _companyPolicyService = companyPolicyService,
       _permissionService = permissionService,
       _locationService = locationService ?? LocationServiceImpl(),
       _sessionEpoch = bindings.authProvider.sessionEpoch,
       super(
         userId: userId,
         trustedTime: trustedTime ?? bindings.employeeTrustedTime,
       ) {
    bindings.smartAttendanceService.clockScreenActive = true;
    bindings.smartAttendanceService.addListener(_onSmartAttendanceChanged);
    isProcessing = true;
    syncService?.onQueuedItemSynced = _onQueuedItemSynced;
    // Phase 6: when the background sync service completes a pass that
    // actually pushed queued items to the server, pull fresh server state
    // and refresh the UI -- previously nothing drove this after a sync.
    syncService?.onSyncCompleted = () {
      unawaited(reconcileWithServer());
    };
    this.trustedTime?.addListener(_onTrustedTimeChanged);
    _maxSessionTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_runMaxSessionAutoCheckout());
    });
    unawaited(_bootstrap());
  }

  final AttendanceRepository _repository;
  final CompanyPolicyService _companyPolicyService;
  final AttendancePermissionService _permissionService;
  final LocationService _locationService;

  void _onTrustedTimeChanged() {
    if (!_isStale) notifyListeners();
    unawaited(_runMaxSessionAutoCheckout());
  }

  /// 24h open-session limit: punch check-out (time + place) and sync it.
  Future<void> _runMaxSessionAutoCheckout() async {
    if (_isStale ||
        _maxSessionSyncInFlight ||
        _isHandlingTap ||
        isProcessing ||
        isCoolingDown) {
      return;
    }

    _maxSessionSyncInFlight = true;
    try {
      trustedNetworkOnline = await bindings.networkChecker.isConnected;
      if (_isStale) return;

      // Best-effort GPS so the auto check-out carries a place; never block
      // the punch if location is unavailable.
      try {
        await _validateGeofence();
      } catch (_) {}
      if (_isStale) return;

      final previousEvents = List.of(events);
      final result = await ensureMaxSessionAutoCheckout();
      if (result != AttendanceActionResult.checkedOut || _isStale) return;

      _captureRealLocationIfOutOfRange(result);
      unawaited(_syncReminderLogs());
      await _syncIfNeeded(result, previousEvents);
    } finally {
      _maxSessionSyncInFlight = false;
    }
  }

  void _onSmartAttendanceChanged() {
    if (_isStale) return;
    unawaited(
      _reloadEventsFromPrefs().then((_) {
        if (!_isStale) notifyListeners();
      }),
    );
  }

  Future<void> _bootstrap() async {
    await trustedTime?.ensureLogin(userId: userId, createIfMissing: false);
    if (_isStale) return;
    // Prefs first, then server — otherwise restore can re-apply a ghost
    // check-in after reconcile already cleared the live session.
    await ensureEventsRestored();
    if (_isStale) return;
    // Reboot blocks issuing new punches, but we still reconcile so the
    // button/card mirror the portal open session.
    final rebootBlocked =
        trustedTime?.sessionEndedByReboot == true ||
        trustedTime?.rebootDetected == true;
    await _loadBreakDurationPolicy();
    await reconcileWithServer().whenComplete(() {
      if (!_isStale) {
        isProcessing = false;
        notifyListeners();
        // Reconcile may leave events unchanged (already Check In) while
        // reminder SQL still says checked_in — always re-sync.
        unawaited(_syncReminderLogs());
        unawaited(_runMaxSessionAutoCheckout());
        if (!rebootBlocked && bindings.smartAttendanceService.isEnabled) {
          unawaited(
            bindings.smartAttendanceService.evaluate(reason: 'clock_open'),
          );
        }
      }
    });
  }

  void _onQueuedItemSynced(String requestId, String action, String message) {
    _raiseLocationAlert(requestId, AppStrings.synced);
  }

  String? lastServerMessage;

  String? lastLocationAlertMessage;
  String? _lastAlertedRequestId;

  void _raiseLocationAlert(String requestId, String message) {
    if (_lastAlertedRequestId == requestId) return;
    _lastAlertedRequestId = requestId;
    lastLocationAlertMessage = message;
    if (!_isStale) notifyListeners();
  }

  static String _actionLabel(String action) {
    switch (action) {
      case AttendanceAction.checkIn:
        return 'check-in';
      case AttendanceAction.checkOut:
        return 'check-out';
      case AttendanceAction.breakStart:
        return 'break-out';
      case AttendanceAction.breakEnd:
        return 'break-in';
      default:
        return action;
    }
  }

  bool blockNextAction = false;

  bool _localDisposed = false;

  /// Prevents overlapping / stampeding status polls while the screen is open.
  bool _reconcileInFlight = false;
  DateTime? _lastReconcileAt;
  static const Duration _reconcileMinInterval = Duration(seconds: 8);

  // The session active when this controller was built. dispose() normally
  // guards against stale continuations, but ClockScreen's dispose runs on
  // the next frame after logout, not synchronously with it -- this closes
  // that gap for any continuation that resumes in between.
  final int _sessionEpoch;
  bool get _isStale =>
      _localDisposed || bindings.authProvider.sessionEpoch != _sessionEpoch;

  bool _isHandlingTap = false;

  // Throttle: prevent back-to-back network refreshes on rapid taps / geofence
  // polls.  Network work is skipped if the last refresh was < 60 seconds ago.
  DateTime? _lastPolicyRefresh;
  static const Duration _policyRefreshThrottle = Duration(seconds: 60);

  bool get _isPolicyRefreshThrottled {
    final last = _lastPolicyRefresh;
    if (last == null) return false;
    return DateTime.now().difference(last) < _policyRefreshThrottle;
  }

  GpsReading? _lastGpsReading;
  bool _geofenceSampled = false;
  bool _locationManuallyChosen = false;
  String? nearbyLocationId;
  bool _smartAttendanceInFlight = false;
  Timer? _maxSessionTimer;
  bool _maxSessionSyncInFlight = false;

  /// Sheet pick: keep this office even if GPS currently matches another one.
  void markLocationChosenManually() {
    _locationManuallyChosen = true;
  }

  void _captureRealLocationIfOutOfRange(AttendanceActionResult result) {
    if (isInRange ||
        result == AttendanceActionResult.none ||
        result == AttendanceActionResult.timeUnavailable) {
      return;
    }
    final reading = _lastGpsReading;
    if (reading == null || events.isEmpty) return;
    final justRecorded = events.last;

    unawaited(
      ReverseGeocodingServiceImpl.instance
          .resolve(lat: reading.location.lat, lon: reading.location.lon)
          .then((resolved) {
            if (_isStale || resolved == null || resolved.trim().isEmpty) {
              return;
            }
            updateEventLocationIfStillLast(
              type: justRecorded.type,
              time: justRecorded.time,
              newLocationLabel: resolved.trim(),
            );
          }),
    );
  }

  AttendanceSummary get _summary => AttendanceEngine.compute(events);

  DateTime? get breakStartedAt =>
      _summary.isOnBreak ? _summary.openSessionStart : null;

  Duration get liveBreakDuration => _summary.liveBreakDuration(now: clockNow);

  int get breakDurationMinutes => liveBreakDuration.inMinutes;

  Duration? lastBreakDuration;

  final List<Duration> recordedBreakDurations = [];

  Duration? _policyBreakDuration;

  Duration get policyBreakDuration =>
      _policyBreakDuration ??
      (maxBreakDuration.inMinutes > 0 ? maxBreakDuration : Duration.zero);

  bool get hasPolicyBreakDuration =>
      (_policyBreakDuration != null && _policyBreakDuration!.inMinutes > 0) ||
      maxBreakDuration.inMinutes > 0;

  DateTime? get breakEndsAt {
    final startedAt = breakStartedAt;
    final allowed = policyBreakDuration;
    if (startedAt == null || allowed.inMinutes <= 0) return null;
    return startedAt.add(allowed);
  }

  String? get breakEndsAtLabel {
    final endsAt = breakEndsAt;
    if (endsAt == null) return null;
    return AttendanceFormat.time(endsAt);
  }

  bool get isEarlyForCheckIn {
    final now = clockNow;
    final scheduledCheckIn = DateTime(
      now.year,
      now.month,
      now.day,
      workStartHour,
      workStartMinute,
    );
    return now.isBefore(scheduledCheckIn);
  }

  bool get isEarlyForCheckOut {
    final now = clockNow;
    final scheduledCheckOut = DateTime(
      now.year,
      now.month,
      now.day,
      workEndHour,
      workEndMinute,
    ).subtract(checkoutGracePeriod);
    return now.isBefore(scheduledCheckOut);
  }

  Future<void> _loadBreakDurationPolicy() async {
    try {
      // Prefer the real permissions section used by the API (`attendance`),
      // then legacy `break_timing`, then the already-loaded maxBreakDuration.
      final raw =
          await _companyPolicyService.valueFor('attendance', 'break_time') ??
          await _companyPolicyService.valueFor('break_timing', 'break_time');
      final minutes = _parseMinutes(raw);
      if (minutes != null && minutes > 0) {
        _policyBreakDuration = Duration(minutes: minutes);
        // Keep base controller limit in sync for break-limit checks.
        configurePolicyExtras(maxBreak: _policyBreakDuration);
      } else if (maxBreakDuration.inMinutes > 0) {
        _policyBreakDuration = maxBreakDuration;
      }
    } catch (e, st) {
      AppLogger.error(
        'SyncedClockScreenController',
        '_loadBreakDurationPolicy',
        e,
        stackTrace: st,
      );
      if (_policyBreakDuration == null && maxBreakDuration.inMinutes > 0) {
        _policyBreakDuration = maxBreakDuration;
      }
    }
    if (!_isStale) notifyListeners();
  }

  int? _parseMinutes(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final digitsOnly = RegExp(r'^\d+').firstMatch(trimmed);
    if (digitsOnly == null) return null;
    return int.tryParse(digitsOnly.group(0)!);
  }

  @override
  void dispose() {
    _maxSessionTimer?.cancel();
    _maxSessionTimer = null;
    bindings.smartAttendanceService.removeListener(_onSmartAttendanceChanged);
    bindings.smartAttendanceService.clockScreenActive = false;
    trustedTime?.removeListener(_onTrustedTimeChanged);
    _localDisposed = true;
    super.dispose();
  }

  @override
  bool get isButtonEnabled => !blockNextAction && super.isButtonEnabled;

  @override
  Future<AttendanceActionResult> handleMainTap() async {
    if (blockNextAction) return AttendanceActionResult.none;
    if (isProcessing || isCoolingDown || _isHandlingTap) {
      return AttendanceActionResult.none;
    }

    _isHandlingTap = true;
    // Show loader INSTANTLY — before any async work
    isProcessing = true;
    notifyListeners();

    try {
      trustedNetworkOnline = await bindings.networkChecker.isConnected;
      final permitted = await _permissionService.checkAndRequestPermissions();
      if (!permitted) {
        lastServerMessage =
            'Location and notification permissions are required to record attendance.';
        return AttendanceActionResult.none;
      }

      await _refreshPolicyBeforeAction();

      final gotLocationFix = await _validateGeofence();
      if (!gotLocationFix) {
        return AttendanceActionResult.outOfRange;
      }

      final previousEvents = List.of(events);
      // Temporarily clear so base class guard doesn't reject the call
      isProcessing = false;
      final result = await super.handleMainTap();

      _captureRealLocationIfOutOfRange(result);

      if (result == AttendanceActionResult.breakEnded) {
        _recordBreakEnd(previousEvents);
      }

      // Keep loader active during server sync
      isProcessing = true;
      unawaited(_syncReminderLogs());
      return await _syncIfNeeded(result, previousEvents);
    } finally {
      isProcessing = false;
      _isHandlingTap = false;
      if (!_isStale) notifyListeners();
    }
  }

  @override
  Future<AttendanceActionResult> handleBreakTap() async {
    if (blockNextAction) return AttendanceActionResult.none;
    if (isProcessing || isCoolingDown || _isHandlingTap) {
      return AttendanceActionResult.none;
    }

    _isHandlingTap = true;
    // Show loader INSTANTLY — before any async work
    isProcessing = true;
    notifyListeners();

    try {
      trustedNetworkOnline = await bindings.networkChecker.isConnected;
      final permitted = await _permissionService.checkAndRequestPermissions();
      if (!permitted) {
        lastServerMessage =
            'Location and notification permissions are required to record attendance.';
        return AttendanceActionResult.none;
      }

      await _refreshPolicyBeforeAction();

      final gotLocationFix = await _validateGeofence();
      if (!gotLocationFix) {
        return AttendanceActionResult.outOfRange;
      }

      final previousEvents = List.of(events);
      // Temporarily clear so base class guard doesn't reject the call
      isProcessing = false;
      final result = await super.handleBreakTap();

      _captureRealLocationIfOutOfRange(result);

      if (result == AttendanceActionResult.breakEnded) {
        _recordBreakEnd(previousEvents);
      }

      // Keep loader active during server sync
      isProcessing = true;
      unawaited(_syncReminderLogs());
      return await _syncIfNeeded(result, previousEvents);
    } finally {
      isProcessing = false;
      _isHandlingTap = false;
      if (!_isStale) notifyListeners();
    }
  }

  Future<void> _syncReminderLogs() async {
    final punches = AttendanceTimelineAssembler.reminderPunchesFromClock(
      events,
    );
    await bindings.reminderSettingsProvider.syncForDay(
      day: clockNow,
      punches: punches,
      now: clockNow,
      locationName: selectedLocationName,
    );
  }

  /// Push the live clock button state into reminder SQL / AlarmManager.
  /// Empty events clear a stale "checked_in" day_state that blocked check-in.
  Future<void> syncRemindersFromLiveClock() => _syncReminderLogs();

  @override
  Future<void> ensureEventsRestored() async {
    await super.ensureEventsRestored();
    await _syncReminderLogs();
  }

  @override
  void restoreEvents(List<AttendanceEvent> snapshot) {
    super.restoreEvents(snapshot);
    unawaited(_syncReminderLogs());
    unawaited(_runMaxSessionAutoCheckout());
  }

  @override
  void replaceLiveEvents(List<AttendanceEvent> next) {
    super.replaceLiveEvents(next);
    unawaited(_syncReminderLogs());
  }

  Future<bool> _validateGeofence() async {
    lastServerMessage = null;

    GpsReading? reading;
    try {
      reading = await _locationService.getCurrentReading();
    } on LocationPermissionDeniedException {
      isInRange = false;
      lastServerMessage = AppStrings.locationPermissionRequired;
      return false;
    } on LocationServiceDisabledException {
      isInRange = false;
      lastServerMessage = AppStrings.turnOnLocationServices;
      return false;
    } on LocationAccuracyTooLowException catch (e) {
      reading = await _locationService.getLastKnownReading();
      if (reading == null) {
        if (!trustedNetworkOnline) return _allowOfflinePunchWithoutFix();
        isInRange = false;
        lastServerMessage =
            'Location accuracy too low (${e.accuracyMeters.toStringAsFixed(0)}m). Move to an open area and try again.';
        return false;
      }
    } on LocationTimeoutException {
      reading = await _locationService.getLastKnownReading();
      if (reading == null) {
        if (!trustedNetworkOnline) return _allowOfflinePunchWithoutFix();
        isInRange = false;
        lastServerMessage =
            'Getting your location is taking too long. Check your GPS signal and try again.';
        return false;
      }
    } catch (e, st) {
      AppLogger.error(
        'SyncedClockScreenController',
        '_validateGeofence',
        e,
        stackTrace: st,
      );
      reading = await _locationService.getLastKnownReading();
      if (reading == null) {
        if (!trustedNetworkOnline) return _allowOfflinePunchWithoutFix();
        isInRange = false;
        lastServerMessage = 'Unable to get your location. Please try again.';
        return false;
      }
    }

    if (reading == null) {
      if (!trustedNetworkOnline) return _allowOfflinePunchWithoutFix();
      isInRange = false;
      lastServerMessage = 'Unable to get your location. Please try again.';
      return false;
    }

    _lastGpsReading = reading;
    final userPoint = GeoPoint(
      lat: reading.location.lat,
      lon: reading.location.lon,
    );
    await _syncWorkingOfficeFromGps(userPoint);

    final selectedLoc = bindings.authProvider.selectedLocation;
    final locName = (selectedLoc?.name != null && selectedLoc!.name.isNotEmpty)
        ? selectedLoc.name
        : selectedLocationName;
    if (locName.isNotEmpty) {
      selectedLocationName = locName;
    }

    final result = GeofenceHelper.evaluate(
      companyLocation: GeoPoint.tryParse(selectedLoc?.latLon),
      user: userPoint,
      radiusMeters: selectedLoc?.radiusMeters,
      locationName: locName,
    );

    final wasInside = isInRange;
    isInRange = result.isInside;
    unawaited(persistGeofenceState());
    final edge = _geofenceSampled && wasInside != isInRange;
    _geofenceSampled = true;

    // Smart Attendance uses physical presence in ANY assigned office+radius.
    // Manual location picks only change the selected label — they must NOT
    // auto check-out while the user is still on assigned premises.
    final premisesMatch = OfficeGeofenceMatcher.bestInside(
      offices: bindings.authProvider.locations,
      user: userPoint,
    );
    final onAssignedPremises = premisesMatch != null;
    final premisesName =
        (premisesMatch != null && premisesMatch.location.name.isNotEmpty)
        ? premisesMatch.location.name
        : locName;

    final reminders = bindings.reminderSettingsProvider;
    if (onAssignedPremises &&
        (reminders.isEnabled(ReminderType.smartAttendance) ||
            reminders.isEnabled(ReminderType.enterLocation))) {
      unawaited(
        _maybeSmartAttendance(entered: true, locationName: premisesName),
      );
    } else if (!onAssignedPremises &&
        (reminders.isEnabled(ReminderType.smartAttendance) ||
            reminders.isEnabled(ReminderType.leaveLocation))) {
      unawaited(
        _maybeSmartAttendance(entered: false, locationName: premisesName),
      );
    } else if (edge) {
      unawaited(
        _notifyGeofenceTransition(entered: isInRange, locationName: locName),
      );
    }
    return true;
  }

  /// Auto-selects the assigned office whose geofence contains the current GPS
  /// point. A manual sheet pick is kept until the user leaves every office.
  Future<void> _syncWorkingOfficeFromGps(GeoPoint user) async {
    final match = OfficeGeofenceMatcher.bestInside(
      offices: bindings.authProvider.locations,
      user: user,
    );
    nearbyLocationId = match?.location.id;

    if (match == null) {
      // Not inside any assigned office — next time they enter one, auto-select.
      _locationManuallyChosen = false;
      return;
    }

    final selectedId = bindings.authProvider.selectedLocation?.id;
    if (selectedId == match.location.id) {
      _locationManuallyChosen = false;
      return;
    }
    if (_locationManuallyChosen) return;

    await bindings.authProvider.selectLocation(
      match.location,
      refreshProfile: false,
    );
    selectedLocationName = match.location.name;
  }

  /// Offline GPS (especially A-GPS / fused location) often fails. Keep the
  /// last cached geofence result so the punch can still be queued.
  bool _allowOfflinePunchWithoutFix() {
    debugPrint(
      '[SyncedClockScreenController] GPS unavailable offline — '
      'keeping cached geofence (inRange=$isInRange)',
    );
    return true;
  }

  Future<void> _notifyGeofenceTransition({
    required bool entered,
    required String locationName,
  }) async {
    await _maybeSmartAttendance(entered: entered, locationName: locationName);
  }

  /// Smart Attendance auto check-in / premises notifications on geofence edge.
  Future<void> _maybeSmartAttendance({
    required bool entered,
    required String locationName,
  }) async {
    if (_isStale || _isHandlingTap || _smartAttendanceInFlight) return;

    final reminders = bindings.reminderSettingsProvider;
    final smartOn = reminders.isEnabled(ReminderType.smartAttendance);
    final enterOn = reminders.isEnabled(ReminderType.enterLocation);
    final leaveOn = reminders.isEnabled(ReminderType.leaveLocation);

    if (entered && !smartOn && !enterOn) return;
    if (!entered && !smartOn && !leaveOn) return;

    _smartAttendanceInFlight = true;
    try {
      final didPunch = await bindings.smartAttendanceService.handleTransition(
        entered: entered,
        locationName: locationName,
        location: _lastGpsReading?.location,
      );
      if (!didPunch || _isStale) return;

      await _reloadEventsFromPrefs();
      unawaited(_syncReminderLogs());
      if (!_isStale) notifyListeners();
    } finally {
      _smartAttendanceInFlight = false;
    }
  }

  Future<void> _reloadEventsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = clockNow;
      final key = 'clock_events_${userId}_${now.year}-${now.month}-${now.day}';
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final restored = decoded
          .whereType<Map>()
          .map((e) => AttendanceEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      restoreEvents(restored);
    } catch (_) {}
  }

  Future<void> refreshGeofenceStatus() async {
    if (_isStale) return;
    await _refreshPolicyBeforeAction();
    if (_isStale) return;
    await _validateGeofence();
    if (!_isStale) notifyListeners();
    // Force Smart Attendance after a Clock geofence refresh so "already
    // inside + Enter ON" auto-checks in without waiting for an edge.
    if (bindings.smartAttendanceService.isEnabled) {
      unawaited(
        bindings.smartAttendanceService.evaluate(reason: 'clock_refresh'),
      );
    }
  }

  Future<void> _refreshPolicyBeforeAction() async {
    final online = trustedNetworkOnline;
    // Throttle guard: skip network if we refreshed recently or are offline.
    if (online && !_isPolicyRefreshThrottled) {
      try {
        await Future.wait([
          _companyPolicyService.refreshFromNetwork().catchError((_) {}),
          bindings.authProvider.refreshCurrentUser().catchError((_) {}),
        ]).timeout(const Duration(seconds: 3));
        _lastPolicyRefresh = DateTime.now();
      } on TimeoutException {
        debugPrint(
          '[SyncedClockScreenController] Network refresh timed out (expected if offline)',
        );
      } catch (e) {
        debugPrint('[SyncedClockScreenController] Network refresh failed: $e');
      }
    }

    if (_isStale) return;
    await loadPolicyFrom(_companyPolicyService);
    await _loadBreakDurationPolicy();
  }

  void _recordBreakEnd(List<AttendanceEvent> previousEvents) {
    final previousSummary = AttendanceEngine.compute(previousEvents);
    final startedAt = previousSummary.openSessionStart;
    final endedAt = events.isNotEmpty ? events.last.time : clockNow;

    if (startedAt == null || !previousSummary.isOnBreak) {
      AppLogger.error(
        'SyncedClockScreenController',
        '_recordBreakEnd',
        'Break ended without a recorded start in event history; '
            'skipping duration calc.',
      );
      return;
    }

    final duration = endedAt.difference(startedAt);
    lastBreakDuration = duration;
    recordedBreakDurations.add(duration);

    debugPrint(
      '[SyncedClockScreenController] Break duration: '
      '${duration.inMinutes}m ${duration.inSeconds % 60}s '
      '(started $startedAt, ended $endedAt)',
    );
  }

  Future<AttendanceActionResult> _syncIfNeeded(
    AttendanceActionResult localResult,
    List<AttendanceEvent> previousEvents,
  ) async {
    final action = _apiActionFor(localResult);
    if (action == null) return localResult;

    final succeeded = await _submit(action, localResult);

    if (!succeeded) {
      if (_lastSubmitWasConflict) {
        // Reconcile drops orphan local open sessions so the button matches
        // the portal (fixes "Unable to check out… make sure you are checked in").
        await reconcileWithServer(force: true);
        if (action == AttendanceAction.checkOut) {
          await _forceServerLiveSessionIfStillOpenLocally();
        }
        blockNextAction = false;
        if (!_isStale) notifyListeners();
        return AttendanceActionResult.none;
      }

      await reconcileWithServer(force: true);
      return AttendanceActionResult.none;
    }

    // Pull the full day after a successful punch so the attendance card keeps
    // the day's earliest check-in when this device started from empty local
    // state (e.g. re-check-in after a portal-only session).
    await reconcileWithServer(force: true);
    return localResult;
  }

  bool _samePunchList(List<AttendanceEvent> a, List<AttendanceEvent> b) {
    if (a.length != b.length) return false;
    final left = [...a]
      ..sort((x, y) => x.effectiveTime.compareTo(y.effectiveTime));
    final right = [...b]
      ..sort((x, y) => x.effectiveTime.compareTo(y.effectiveTime));
    for (var i = 0; i < left.length; i++) {
      if (left[i].type != right[i].type) return false;
      if (left[i].effectiveTime.difference(right[i].effectiveTime).inSeconds !=
          0) {
        return false;
      }
    }
    return true;
  }

  Future<bool> reconcileWithServer({bool force = false}) async {
    if (_isStale) return false;
    if (_reconcileInFlight) return false;
    if (!force) {
      final last = _lastReconcileAt;
      if (last != null &&
          DateTime.now().difference(last) < _reconcileMinInterval) {
        return false;
      }
    }

    final online = await bindings.networkChecker.isConnected;
    if (!online) {
      debugPrint(
        '[SyncedClockScreenController] reconcileWithServer: skipped (offline)',
      );
      return false;
    }

    _reconcileInFlight = true;
    try {
      debugPrint('[SyncedClockScreenController] reconcileWithServer: start');
      final today = clockNow;
      final yesterday = today.subtract(const Duration(days: 1));
      // Fetch yesterday too so an open overnight session (check-in before
      // midnight) is not dropped when today's list is empty.
      Future<List<AttendanceEvent>?> fetchDay(DateTime day) async {
        try {
          return await _repository
              .fetchTodayEvents(
                cancelToken: bindings.authProvider.sessionCancelToken,
                forDay: day,
              )
              .timeout(const Duration(seconds: 10));
        } on TimeoutException {
          return null;
        } catch (_) {
          return null;
        }
      }

      final serverToday = await fetchDay(today);
      if (_isStale) return false;
      final serverYesterday = await fetchDay(yesterday);
      if (_isStale) return false;
      if (serverToday == null && serverYesterday == null) {
        debugPrint(
          '[SyncedClockScreenController] reconcileWithServer: no server '
          'events returned, keeping local state',
        );
        return false;
      }

      final serverEvents = <AttendanceEvent>[
        ...?serverYesterday,
        ...?serverToday,
      ];

      final localActive = events;
      final localSummary = AttendanceEngine.compute(localActive);

      // Ghost overnight open: check-in was yesterday, server yesterday is
      // closed (or empty after a real fetch), but local still shows Check Out.
      final clearedStale = _clearStaleOvernightOpenIfNeeded(
        localSummary: localSummary,
        serverYesterday: serverYesterday,
        serverToday: serverToday,
      );
      if (clearedStale) {
        blockNextAction = false;
        _lastReconcileAt = DateTime.now();
        return true;
      }

      final serverActive = serverEvents;
      final merged = serverActive.isEmpty
          ? localActive
          : _mergeWithLocal(localActive, serverActive);

      debugPrint(
        '[SyncedClockScreenController] reconcileWithServer: merged '
        '${serverActive.length} server event(s) with ${localActive.length} '
        'local event(s) -> ${merged.length} total (active session window)',
      );
      if (_samePunchList(merged, localActive)) {
        _lastReconcileAt = DateTime.now();
        return true;
      }
      // Replace (not union): merged already includes local∪server minus
      // orphan open tails. restoreEvents would re-add dropped phantoms.
      replaceLiveEvents(merged);
      blockNextAction = false;
      _lastReconcileAt = DateTime.now();
      return true;
    } on TimeoutException {
      // Wi-Fi up but no route to the API is the common case. Keep the
      // local clock state and don't dump a stack — this is expected.
      debugPrint(
        '[SyncedClockScreenController] reconcileWithServer: timed out, '
        'keeping local attendance',
      );
      _lastReconcileAt = DateTime.now();
      return false;
    } catch (e) {
      debugPrint(
        '[SyncedClockScreenController] reconcileWithServer failed: $e',
      );
      _lastReconcileAt = DateTime.now();
      return false;
    } finally {
      _reconcileInFlight = false;
    }
  }

  // Merge policy: UNION of server + local, with one exception —
  // local-only punches that reopen a session the server already closed
  // (failed / phantom check-ins) are dropped so the button matches portal.
  List<AttendanceEvent> _mergeWithLocal(
    List<AttendanceEvent> local,
    List<AttendanceEvent> server,
  ) {
    if (server.isEmpty) return List.of(local);
    if (local.isEmpty) return List.of(server);

    final merged = <AttendanceEvent>[...server];

    for (final localEvent in local) {
      final index = merged.indexWhere(
        (existing) => existing.isSamePunchAs(localEvent),
      );
      if (index >= 0) {
        merged[index] = AttendanceEvent.preferAuthoritative(
          localEvent,
          merged[index],
        );
      } else {
        merged.add(localEvent);
      }
    }

    merged.sort((a, b) => a.effectiveTime.compareTo(b.effectiveTime));
    return _dropOrphanLocalOpenTail(
      AttendanceEngine.collapseDuplicatePunches(merged),
      server,
    );
  }

  /// When the server session is closed, drop local-only punches that land
  /// after the server's last event and would wrongly leave the clock on
  /// Check Out (e.g. smart-attendance check-in that never reached the API).
  List<AttendanceEvent> _dropOrphanLocalOpenTail(
    List<AttendanceEvent> merged,
    List<AttendanceEvent> server,
  ) {
    if (merged.isEmpty || server.isEmpty) return merged;

    final serverSummary = AttendanceEngine.compute(server);
    if (serverSummary.isCheckedIn || serverSummary.isOnBreak) {
      return merged;
    }

    final serverSorted = AttendanceEngine.sortedOldestFirst(server);
    final serverLastAt = serverSorted.last.effectiveTime;

    final kept = <AttendanceEvent>[];
    for (final event in AttendanceEngine.sortedOldestFirst(merged)) {
      final onServer = server.any((s) => s.isSamePunchAs(event));
      if (onServer || !event.effectiveTime.isAfter(serverLastAt)) {
        kept.add(event);
        continue;
      }
      // Local-only punch after server closed — orphan; do not keep.
      debugPrint(
        '[SyncedClockScreenController] dropping orphan local '
        '${event.type.name} at ${event.effectiveTime}',
      );
    }
    return kept;
  }

  /// Returns true when a stale overnight local open was cleared.
  bool _clearStaleOvernightOpenIfNeeded({
    required AttendanceSummary localSummary,
    required List<AttendanceEvent>? serverYesterday,
    required List<AttendanceEvent>? serverToday,
  }) {
    if (!localSummary.isCheckedIn && !localSummary.isOnBreak) return false;
    final openStart = localSummary.openSessionStart ?? localSummary.firstCheckIn;
    if (openStart == null) return false;

    final now = clockNow;
    final openIsToday =
        openStart.year == now.year &&
        openStart.month == now.month &&
        openStart.day == now.day;
    if (openIsToday) return false;

    // Need a successful yesterday fetch to decide.
    if (serverYesterday == null) return false;

    final ySummary = AttendanceEngine.compute(serverYesterday);
    if (ySummary.isCheckedIn || ySummary.isOnBreak) {
      // Server still has a real overnight open — keep it.
      return false;
    }

    // Server finished yesterday (or has no open session). Local Check Out
    // from a ghost 10:42 PM check-in must not stick into today.
    final replacement = <AttendanceEvent>[
      ...serverYesterday,
      ...?serverToday,
    ];
    debugPrint(
      '[SyncedClockScreenController] clearing stale overnight local open '
      '(started $openStart); applying ${replacement.length} server event(s)',
    );
    replaceLiveEvents(replacement);
    return true;
  }

  bool _lastSubmitWasConflict = false;

  /// After a rejected check-out, if local is still open but the server is
  /// not, replace the live session with server punches only.
  Future<void> _forceServerLiveSessionIfStillOpenLocally() async {
    if (_isStale) return;
    final local = AttendanceEngine.compute(events);
    if (!local.isCheckedIn && !local.isOnBreak) return;

    try {
      final today = clockNow;
      final yesterday = today.subtract(const Duration(days: 1));
      final serverToday = await _repository.fetchTodayEvents(
        cancelToken: bindings.authProvider.sessionCancelToken,
        forDay: today,
      );
      if (_isStale) return;
      final serverYesterday = await _repository.fetchTodayEvents(
        cancelToken: bindings.authProvider.sessionCancelToken,
        forDay: yesterday,
      );
      if (_isStale) return;

      final server = <AttendanceEvent>[...?serverYesterday, ...?serverToday];
      final serverSummary = AttendanceEngine.compute(server);
      if (serverSummary.isCheckedIn || serverSummary.isOnBreak) return;

      // Server is checked out — trust it for the live button (replace, no
      // union, so phantom local check-ins cannot stick around).
      replaceLiveEvents(server);
      debugPrint(
        '[SyncedClockScreenController] forced server session after '
        'rejected check-out (${server.length} event(s))',
      );
    } catch (e) {
      debugPrint(
        '[SyncedClockScreenController] '
        '_forceServerLiveSessionIfStillOpenLocally failed: $e',
      );
    }
  }

  Future<bool> _submit(
    String action,
    AttendanceActionResult localResult,
  ) async {
    _lastSubmitWasConflict = false;
    final recorded = lastRecordedEvent;
    final capturedAt = recorded?.time;
    if (capturedAt == null) {
      lastTrustedTimeError = 'No trusted punch timestamp to send.';
      return false;
    }

    LocationModel? location = _lastGpsReading?.location;
    if (location == null) {
      try {
        location = await _locationService.getCurrentLocation();
      } catch (e, st) {
        AppLogger.error(
          'SyncedClockScreenController',
          '_submit (location fetch for "$action")',
          e,
          stackTrace: st,
        );
        // Continue without coordinates rather than dropping a recorded punch.
      }
    }

    String? deviceDetails;
    try {
      final info = await bindings.deviceInfoService.collect();
      deviceDetails = info.deviceDetails;
    } catch (e, st) {
      AppLogger.error(
        'SyncedClockScreenController',
        '_submit (device info for "$action")',
        e,
        stackTrace: st,
      );
    }

    final payload = AttendancePayloadModel(
      action: action,
      capturedAt: capturedAt,
      location: location,
      deviceDetails: deviceDetails,
    );

    try {
      final submitResult = await _repository.submitAttendance(payload);

      blockNextAction = false;

      if (submitResult.synced) {
        if (!recorded!.isValidLocation) {
          _raiseLocationAlert(
            payload.requestId,
            submitResult.notification ??
                'You performed ${_actionLabel(action)} outside office '
                    'premises.',
          );
        }
      }

      return true;
    } on AttendanceBusinessException catch (e) {
      _lastSubmitWasConflict = true;
      lastServerMessage = e.message;

      if (!_isStale) notifyListeners();
      return false;
    } catch (e) {
      lastServerMessage = e.toString();
      blockNextAction = true;

      if (!_isStale) notifyListeners();
      return false;
    }
  }

  String? _apiActionFor(AttendanceActionResult result) {
    switch (result) {
      case AttendanceActionResult.checkedIn:
        return AttendanceAction.checkIn;
      case AttendanceActionResult.checkedOut:
        return AttendanceAction.checkOut;
      case AttendanceActionResult.breakStarted:
        return AttendanceAction.breakStart;
      case AttendanceActionResult.breakEnded:
        return AttendanceAction.breakEnd;
      case AttendanceActionResult.outOfRange:
      case AttendanceActionResult.nonWorkingDay:
      case AttendanceActionResult.breakLimitReached:
      case AttendanceActionResult.timeUnavailable:
      case AttendanceActionResult.none:
        return null;
    }
  }
}
