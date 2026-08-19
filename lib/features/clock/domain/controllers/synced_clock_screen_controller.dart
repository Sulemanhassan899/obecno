

import 'dart:async';

import 'package:Obecno/core/constants/app_strings.dart';
import 'package:Obecno/core/services/logger.dart';
import 'package:Obecno/features/auth/services/company_policy_service.dart';
import 'package:Obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:flutter/foundation.dart';
import 'package:Obecno/features/clock/domain/controllers/clock_controller.dart';
import 'package:Obecno/shared/location/data/location_model.dart';
import 'package:Obecno/shared/location/service/attendance_payload_model.dart';
import 'package:Obecno/shared/location/service/attendance_permission_service.dart';
import 'package:Obecno/shared/location/service/location_service.dart';
import 'package:Obecno/shared/location/service/geofence_helper.dart';
import 'package:Obecno/shared/location/service/reverse_geocoding_service.dart';

import '../../../../core/constants/app_enums.dart'
    hide AttendanceActionResult;
import '../../repositories/clock_attendance_repository.dart';
import '../../presentation/widgets/clock_attendance_engine.dart';
import '../../services/sync_service.dart';
import 'package:Obecno/main.dart';

class SyncedClockScreenController extends ClockScreenController {
  SyncedClockScreenController({
    required AttendanceRepository repository,
    required CompanyPolicyService companyPolicyService,
    required String userId,
    AttendancePermissionService permissionService =
        const AttendancePermissionService(),
    LocationService? locationService,
    SyncService? syncService,
  }) : _repository = repository,
       _companyPolicyService = companyPolicyService,
       _permissionService = permissionService,
       _locationService = locationService ?? LocationServiceImpl(),
       _sessionEpoch = bindings.authProvider.sessionEpoch, super(userId: userId) {
    isProcessing = true;
    syncService?.onQueuedItemSynced = _onQueuedItemSynced;
    // Phase 6: when the background sync service completes a pass that
    // actually pushed queued items to the server, pull fresh server state
    // and refresh the UI -- previously nothing drove this after a sync.
    syncService?.onSyncCompleted = () {
      unawaited(reconcileWithServer());
    };
    unawaited(_loadBreakDurationPolicy());
    unawaited(
      reconcileWithServer().whenComplete(() {
        if (!_isStale) {
          isProcessing = false;
          notifyListeners();
        }
      }),
    );
  }

  final AttendanceRepository _repository;
  final CompanyPolicyService _companyPolicyService;
  final AttendancePermissionService _permissionService;
  final LocationService _locationService;

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

  void _captureRealLocationIfOutOfRange(AttendanceActionResult result) {
    if (isInRange || result == AttendanceActionResult.none) return;
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

  Duration get liveBreakDuration => _summary.liveBreakDuration();

  int get breakDurationMinutes => liveBreakDuration.inMinutes;

  Duration? lastBreakDuration;

  final List<Duration> recordedBreakDurations = [];

  Duration? _policyBreakDuration;

  Duration get policyBreakDuration =>
      _policyBreakDuration ??
      (maxBreakDuration.inMinutes > 0 ? maxBreakDuration : Duration.zero);

  bool get hasPolicyBreakDuration =>
      (_policyBreakDuration != null &&
          _policyBreakDuration!.inMinutes > 0) ||
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
    final now = DateTime.now();
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
    final now = DateTime.now();
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
      return await _syncIfNeeded(result, previousEvents);
    } finally {
      isProcessing = false;
      _isHandlingTap = false;
      if (!_isStale) notifyListeners();
    }
  }

  Future<bool> _validateGeofence() async {
    lastServerMessage = null;

    final selectedLoc = bindings.authProvider.selectedLocation;
    final locName = (selectedLoc?.name != null && selectedLoc!.name.isNotEmpty)
        ? selectedLoc.name
        : selectedLocationName;
    if (locName.isNotEmpty) {
      selectedLocationName = locName;
    }

    final companyPoint = GeoPoint.tryParse(selectedLoc?.latLon);

    final GpsReading reading;
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
      isInRange = false;
      lastServerMessage =
          'Location accuracy too low (${e.accuracyMeters.toStringAsFixed(0)}m). Move to an open area and try again.';
      return false;
    } on LocationTimeoutException {
      isInRange = false;
      lastServerMessage =
          'Getting your location is taking too long. Check your GPS signal and try again.';
      return false;
    } on MockLocationDetectedException {
      isInRange = false;
      lastServerMessage =
          'A mock location was detected. Please disable it to continue.';
      return false;
    } catch (e, st) {
      AppLogger.error(
        'SyncedClockScreenController',
        '_validateGeofence',
        e,
        stackTrace: st,
      );
      isInRange = false;
      lastServerMessage = 'Unable to get your location. Please try again.';
      return false;
    }

    final result = GeofenceHelper.evaluate(
      companyLocation: companyPoint,
      user: GeoPoint(lat: reading.location.lat, lon: reading.location.lon),
      radiusMeters: selectedLoc?.radiusMeters,
      locationName: locName,
    );

    isInRange = result.isInside;
    _lastGpsReading = reading;
    unawaited(persistGeofenceState());
    return true;
  }

  Future<void> refreshGeofenceStatus() async {
    if (_isStale) return;
    await _refreshPolicyBeforeAction();
    if (_isStale) return;
    await _validateGeofence();
    if (!_isStale) notifyListeners();
  }

  Future<void> _refreshPolicyBeforeAction() async {
    // Throttle guard: skip network if we refreshed recently.
    if (!_isPolicyRefreshThrottled) {
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
    final endedAt = events.isNotEmpty ? events.last.time : DateTime.now();

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
        // Do NOT restore previous events (which would drop the local event).
        // Let the reconcile handle merge.
        await reconcileWithServer();
        blockNextAction = false;
        if (!_isStale) notifyListeners();
        return AttendanceActionResult.none;
      }

      await reconcileWithServer();
      return AttendanceActionResult.none;
    }

    return localResult;
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
      final serverEvents = await _repository
          .fetchTodayEvents(
            cancelToken: bindings.authProvider.sessionCancelToken,
          )
          .timeout(const Duration(seconds: 10));
      if (_isStale) return false;
      if (serverEvents == null) {
        debugPrint(
          '[SyncedClockScreenController] reconcileWithServer: no server '
          'events returned, keeping local state',
        );
        return false;
      }

      final today = DateTime.now();
      bool isToday(AttendanceEvent e) =>
          e.effectiveTime.year == today.year &&
          e.effectiveTime.month == today.month &&
          e.effectiveTime.day == today.day;

      // Clock UI must never mix other days into today's timeline.
      final serverToday = serverEvents.where(isToday).toList();
      final localToday = events.where(isToday).toList();

      final merged = serverToday.isEmpty
          ? localToday
          : _mergeWithLocal(localToday, serverToday);

      debugPrint(
        '[SyncedClockScreenController] reconcileWithServer: merged '
        '${serverToday.length} server event(s) with ${localToday.length} '
        'local event(s) -> ${merged.length} total (today only)',
      );
      restoreEvents(merged); // already calls notifyListeners()
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

  // Merge policy: STRICT UNION, never a filtered replace.
  //
  // Server data can legitimately be incomplete (e.g. a backend response
  // shape that only reports the latest check-in/checkout cycle instead of
  // the full day's event list). Treating "not found on server" as "safe to
  // drop" silently destroys real, already-persisted history -- exactly the
  // append-only guarantee this system must never violate.
  //
  // Instead: every server event is kept, and every local event is kept
  // unless it is a confirmed duplicate of a specific server event (same id,
  // or same type + timestamp within clock-skew tolerance). Nothing is ever
  // dropped based on a timestamp cutoff. The merged list can only ever grow
  // relative to both inputs, never shrink.
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
    return merged;
  }

  bool _lastSubmitWasConflict = false;

  Future<bool> _submit(
    String action,
    AttendanceActionResult localResult,
  ) async {
    _lastSubmitWasConflict = false;
    final capturedAt = events.isEmpty ? DateTime.now() : events.last.time;

    final LocationModel location;
    try {
      location = await _locationService.getCurrentLocation();
    } on LocationTimeoutException {
      lastServerMessage =
          'Getting your location is taking too long. Check your GPS signal and try again.';
      if (!_isStale) notifyListeners();
      return false;
    } catch (e, st) {
      AppLogger.error(
        'SyncedClockScreenController',
        '_submit (location fetch for "$action")',
        e,
        stackTrace: st,
      );
      lastServerMessage = 'Unable to get your location. Please try again.';
      if (!_isStale) notifyListeners();
      return false;
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
        final recordedEvent = events.isEmpty ? null : events.last;
        if (recordedEvent != null && !recordedEvent.isValidLocation) {
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
      case AttendanceActionResult.none:
        return null;
    }
  }
}