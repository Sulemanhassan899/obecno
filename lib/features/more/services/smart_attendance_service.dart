import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:obecno/core/services/logger.dart';
import 'package:obecno/core/services/network_checker.dart';
import 'package:obecno/features/auth/data/models/auth_location_model.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:obecno/features/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:obecno/features/clock/repositories/clock_attendance_repository.dart';
import 'package:obecno/features/clock/services/employee_trusted_time.dart';
import 'package:obecno/features/employee_module/attendance/domain/attendance_timeline_assembler.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';
import 'package:obecno/features/more/providers/reminder_settings_provider.dart';
import 'package:obecno/shared/location/data/location_model.dart';
import 'package:obecno/shared/location/service/attendance_payload_model.dart';
import 'package:obecno/shared/location/service/geofence_helper.dart';
import 'package:obecno/shared/location/service/location_service.dart';
import 'package:obecno/shared/location/service/office_geofence_matcher.dart';
import 'package:obecno/core/constants/app_enums.dart';

/// Production Smart Attendance: auto check-in when inside an assigned office.
/// Checkout is always manual; while outside and still checked in, nags every
/// 5 minutes. Enter/Leave reminder toggles are notifications only.
class SmartAttendanceService extends ChangeNotifier {
  SmartAttendanceService({
    required ReminderSettingsProvider reminders,
    required AuthProvider auth,
    required AttendanceRepository repository,
    required EmployeeTrustedTime trustedTime,
    required NetworkChecker networkChecker,
    required Future<String?> Function() deviceDetailsProvider,
    LocationService? locationService,
    Duration pollInterval = const Duration(seconds: 45),
    Duration checkoutNagInterval = const Duration(minutes: 5),
  }) : _reminders = reminders,
       _auth = auth,
       _repository = repository,
       _trustedTime = trustedTime,
       _networkChecker = networkChecker,
       _deviceDetailsProvider = deviceDetailsProvider,
       _locationService = locationService ?? LocationServiceImpl(),
       _pollInterval = pollInterval,
       _checkoutNagInterval = checkoutNagInterval;

  final ReminderSettingsProvider _reminders;
  final AuthProvider _auth;
  final AttendanceRepository _repository;
  final EmployeeTrustedTime _trustedTime;
  final NetworkChecker _networkChecker;
  final Future<String?> Function() _deviceDetailsProvider;
  final LocationService _locationService;
  final Duration _pollInterval;
  final Duration _checkoutNagInterval;

  Timer? _timer;
  bool _inFlight = false;
  bool _running = false;
  bool? _lastInside;
  String? _lastInsideOfficeName;
  DateTime? _lastEvaluateAt;
  DateTime? _lastCheckoutNagAt;
  String? _lastEnterNotifyKey;
  String? _lastLeaveNotifyKey;

  /// When the Clock screen is open it owns geofence sampling; the service
  /// still exposes [handleTransition] for that path and skips polling.
  bool clockScreenActive = false;

  bool get smartAttendanceEnabled =>
      _reminders.isEnabled(ReminderType.smartAttendance);
  bool get enterNotifyEnabled =>
      _reminders.isEnabled(ReminderType.enterLocation);
  bool get leaveNotifyEnabled =>
      _reminders.isEnabled(ReminderType.leaveLocation);

  /// Runs while any smart/geofence feature needs GPS.
  bool get isEnabled =>
      smartAttendanceEnabled || enterNotifyEnabled || leaveNotifyEnabled;
  bool get isRunning => _running;

  void syncWithToggles() {
    if (isEnabled) {
      start();
    } else {
      stop();
    }
  }

  void start() {
    if (_running) {
      _schedule();
      return;
    }
    if (!isEnabled) return;
    _running = true;
    _schedule();
    unawaited(evaluate(reason: 'start'));
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _lastInside = null;
    _lastCheckoutNagAt = null;
    _lastEnterNotifyKey = null;
    _lastLeaveNotifyKey = null;
    notifyListeners();
  }

  void onAppResumed() {
    if (!_running || !isEnabled) return;
    unawaited(evaluate(reason: 'resume'));
  }

  void _schedule() {
    _timer?.cancel();
    if (!_running || !isEnabled) return;
    _timer = Timer.periodic(_pollInterval, (_) {
      unawaited(evaluate(reason: 'poll'));
    });
  }

  /// Clock-screen geofence edge — auto check-in only (never auto check-out).
  Future<bool> handleTransition({
    required bool entered,
    required String locationName,
    LocationModel? location,
  }) async {
    if (entered) {
      if (smartAttendanceEnabled) {
        final punched = await _punchCheckIn(
          locationName: locationName,
          location: location,
        );
        await _notifyPresence(
          inside: true,
          locationName: locationName,
          force: true,
        );
        return punched;
      }
      await _notifyPresence(
        inside: true,
        locationName: locationName,
        force: true,
      );
      return false;
    }

    // Leaving: never auto check-out. Notify + optional 5‑min nag.
    if (locationName.trim().isNotEmpty) {
      _lastInsideOfficeName = locationName.trim();
    }
    await _notifyPresence(
      inside: false,
      locationName: _lastInsideOfficeName ?? locationName,
      force: true,
    );
    if (smartAttendanceEnabled) {
      await _maybeCheckoutNag(
        locationName: _lastInsideOfficeName ?? locationName,
        force: true,
      );
    }
    return false;
  }

  Future<void> evaluate({String reason = 'manual'}) async {
    if (!isEnabled || _inFlight) return;
    // Clock screen owns continuous geofence sampling. Still allow checkout
    // nags on the poll tick so "every 5 minutes until check out" keeps
    // firing while Clock is open and the user is already outside.
    if (clockScreenActive && reason == 'poll') {
      if (smartAttendanceEnabled && _lastInside == false) {
        await _maybeCheckoutNag(
          locationName: _lastInsideOfficeName ?? 'work',
        );
      }
      return;
    }

    final userId = _auth.user?.id;
    if (userId == null || userId.isEmpty || !_auth.isAuthenticated) {
      debugPrint('[SmartAttendance] skip evaluate($reason): not authenticated');
      return;
    }

    final now = DateTime.now();
    final last = _lastEvaluateAt;
    if (reason == 'poll' &&
        last != null &&
        now.difference(last) < const Duration(seconds: 20)) {
      return;
    }
    _lastEvaluateAt = now;

    _inFlight = true;
    try {
      final reading = await _readGps();
      if (reading == null) {
        debugPrint('[SmartAttendance] skip evaluate($reason): no GPS');
        return;
      }

      final userPoint = GeoPoint(
        lat: reading.location.lat,
        lon: reading.location.lon,
      );
      final offices = _auth.locations;
      if (offices.isEmpty) {
        debugPrint('[SmartAttendance] skip evaluate($reason): no offices');
        return;
      }

      final insideMatch = OfficeGeofenceMatcher.bestInside(
        offices: offices,
        user: userPoint,
      );
      final isInside = insideMatch != null;
      final officeName = _resolveOfficeName(insideMatch, offices);
      final becameInside = _lastInside != true && isInside;
      final becameOutside = _lastInside == true && !isInside;
      final toggleOn = reason == 'toggle_on' || reason == 'start';

      debugPrint(
        '[SmartAttendance] evaluate($reason) inside=$isInside '
        'office=$officeName smart=$smartAttendanceEnabled '
        'enterNotify=$enterNotifyEnabled leaveNotify=$leaveNotifyEnabled',
      );

      if (isInside && insideMatch != null) {
        _lastInsideOfficeName = officeName;
      }

      _lastInside = isInside;

      var punchedIn = false;
      if (isInside && smartAttendanceEnabled) {
        punchedIn = await _punchCheckIn(
          locationName: officeName,
          location: reading.location,
        );
        debugPrint('[SmartAttendance] auto check-in attempted → $punchedIn');
      }

      final forceNotify =
          becameInside || becameOutside || toggleOn || punchedIn;
      await _notifyPresence(
        inside: isInside,
        locationName: isInside
            ? officeName
            : (_lastInsideOfficeName ?? officeName),
        force: forceNotify,
      );

      if (!isInside && smartAttendanceEnabled) {
        await _maybeCheckoutNag(
          locationName: _lastInsideOfficeName ?? officeName,
          force: becameOutside || toggleOn,
        );
      } else if (isInside) {
        _lastCheckoutNagAt = null;
      }
    } catch (e, st) {
      AppLogger.error('SmartAttendanceService', 'evaluate($reason)', e,
          stackTrace: st);
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _notifyPresence({
    required bool inside,
    required String locationName,
    bool force = false,
  }) async {
    if (inside && !enterNotifyEnabled) return;
    if (!inside && !leaveNotifyEnabled) return;

    final userId = _auth.user?.id ?? '';
    if (userId.isEmpty) return;

    final events = await _loadTodayEvents(userId);
    final summary = AttendanceEngine.compute(events);
    final checkedIn = summary.isCheckedIn || summary.isOnBreak;

    // Smart Attendance owns the repeating "please check out" nag.
    if (!inside && checkedIn && smartAttendanceEnabled) return;

    final key = '${inside ? 'in' : 'out'}_${checkedIn ? 'ci' : 'co'}';

    if (inside) {
      if (!force && _lastEnterNotifyKey == key) return;
      _lastEnterNotifyKey = key;
    } else {
      if (!force && _lastLeaveNotifyKey == key) return;
      _lastLeaveNotifyKey = key;
    }

    await _reminders.notifyPremisesReminder(
      inside: inside,
      checkedIn: checkedIn,
      locationName: locationName,
    );
  }

  Future<void> _maybeCheckoutNag({
    required String locationName,
    bool force = false,
  }) async {
    if (!smartAttendanceEnabled) return;

    final userId = _auth.user?.id ?? '';
    if (userId.isEmpty) return;

    final events = await _loadTodayEvents(userId);
    final summary = AttendanceEngine.compute(events);
    final stillWorking = summary.isCheckedIn || summary.isOnBreak;
    if (!stillWorking) {
      _lastCheckoutNagAt = null;
      return;
    }

    final now = DateTime.now();
    final last = _lastCheckoutNagAt;
    if (!force &&
        last != null &&
        now.difference(last) < _checkoutNagInterval) {
      return;
    }

    _lastCheckoutNagAt = now;
    await _reminders.notifySmartCheckoutNag(locationName: locationName);
  }

  Future<bool> _punchCheckIn({
    required String locationName,
    LocationModel? location,
  }) async {
    final punching = _PunchGate.acquire();
    if (!punching) {
      debugPrint('[SmartAttendance] punch skipped: already in flight');
      return false;
    }

    try {
      final userId = _auth.user?.id ?? '';
      if (userId.isEmpty) return false;

      await _trustedTime.ensureLogin(userId: userId, createIfMissing: true);

      final events = await _loadTodayEvents(userId);
      final summary = AttendanceEngine.compute(events);

      if (summary.isCheckedIn || summary.isOnBreak) {
        debugPrint('[SmartAttendance] skip check-in: already checked in');
        return false;
      }

      final online = await _networkChecker.isConnected;
      final issued = await _trustedTime.issuePunch(networkOnline: online);
      final punch = issued.punch;
      if (!issued.isOk || punch == null) {
        debugPrint(
          '[SmartAttendance] trusted time unavailable: ${issued.error}',
        );
        return false;
      }

      final at = punch.timeSentToServer;
      final place = locationName.trim().isEmpty
          ? (_auth.selectedLocation?.name ?? 'work')
          : locationName.trim();

      final event = AttendanceEvent(
        id: '${at.microsecondsSinceEpoch}_${math.Random().nextInt(10000)}',
        type: AttendanceEventType.checkIn,
        time: at,
        location: place,
        isValidLocation: true,
        phoneWallClock: punch.phoneWallClock,
        calculatedActualTime: punch.calculatedActualTime,
        clockChanged: punch.clockChanged,
        clockDifference: punch.clockDifference,
        timeComparison: punch.comparison,
        monotonicElapsed: punch.monotonicElapsed,
      );

      final nextEvents = [...events, event];
      await _persistTodayEvents(userId, at, nextEvents);

      String? deviceDetails;
      try {
        deviceDetails = await _deviceDetailsProvider();
      } catch (_) {}

      try {
        await _repository.submitAttendance(
          AttendancePayloadModel(
            action: AttendanceAction.checkIn,
            capturedAt: at,
            location: location,
            deviceDetails: deviceDetails,
          ),
        );
      } catch (e, st) {
        AppLogger.error(
          'SmartAttendanceService',
          'submitAttendance',
          e,
          stackTrace: st,
        );
      }

      // Enter-location notify toggle owns banners via [_notifyPresence].

      final punches =
          AttendanceTimelineAssembler.reminderPunchesFromClock(nextEvents);
      await _reminders.syncForDay(
        day: at,
        punches: punches,
        now: at,
        locationName: place,
      );

      debugPrint('[SmartAttendance] checked in at $place');
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.error('SmartAttendanceService', '_punchCheckIn', e,
          stackTrace: st);
      return false;
    } finally {
      _PunchGate.release();
    }
  }

  Future<GpsReading?> _readGps() async {
    try {
      return await _locationService.getCurrentReading();
    } on LocationPermissionDeniedException {
      return null;
    } on LocationServiceDisabledException {
      return null;
    } catch (_) {
      try {
        return await _locationService.getLastKnownReading();
      } catch (_) {
        return null;
      }
    }
  }

  String _resolveOfficeName(
    OfficeMatch? insideMatch,
    List<AuthLocationModel> offices,
  ) {
    if (insideMatch != null && insideMatch.location.name.isNotEmpty) {
      return insideMatch.location.name;
    }
    final selected = _auth.selectedLocation?.name;
    if (selected != null && selected.isNotEmpty) return selected;
    if (offices.isNotEmpty && offices.first.name.isNotEmpty) {
      return offices.first.name;
    }
    return 'work';
  }

  String _prefsKey(String userId, DateTime day) =>
      'clock_events_${userId}_${day.year}-${day.month}-${day.day}';

  Future<List<AttendanceEvent>> _loadTodayEvents(String userId) async {
    final now = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey(userId, now));
      if (raw == null || raw.isEmpty) {
        // Fall back to server/cache when Clock has not written today yet.
        final remote = await _repository.fetchTodayEvents(forDay: now);
        return remote ?? const [];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => AttendanceEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persistTodayEvents(
    String userId,
    DateTime day,
    List<AttendanceEvent> events,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = events
          .where(
            (e) =>
                e.effectiveTime.year == day.year &&
                e.effectiveTime.month == day.month &&
                e.effectiveTime.day == day.day,
          )
          .toList();
      await prefs.setString(
        _prefsKey(userId, day),
        jsonEncode(today.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Process-wide mutex so Clock-screen and background evaluate cannot double-punch.
class _PunchGate {
  static bool _locked = false;

  static bool acquire() {
    if (_locked) return false;
    _locked = true;
    return true;
  }

  static void release() {
    _locked = false;
  }
}
