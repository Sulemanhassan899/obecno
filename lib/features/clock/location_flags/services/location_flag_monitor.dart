import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/auth/data/models/auth_location_model.dart';
import 'package:obecno/features/clock/location_flags/data/models/location_flag_record.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_evaluator.dart';
import 'package:obecno/features/clock/location_flags/repositories/location_flag_repository.dart';
import 'package:obecno/shared/location/service/geofence_helper.dart';
import 'package:obecno/shared/location/service/location_service.dart';

class LocationFlagMonitorService with WidgetsBindingObserver {
  LocationFlagMonitorService({
    required LocationFlagRepository repository,
    required LocationService locationService,
    required String? Function() employeeIdProvider,
    required AuthLocationModel? Function() officeProvider,
    required int Function() sessionEpochProvider,
    Future<bool> Function()? isOnline,
    void Function()? onRecordsChanged,
    DateTime Function()? now,
  }) : _repository = repository,
       _locationService = locationService,
       _employeeIdProvider = employeeIdProvider,
       _officeProvider = officeProvider,
       _sessionEpochProvider = sessionEpochProvider,
       _isOnline = isOnline,
       _onRecordsChanged = onRecordsChanged,
       _now = now ?? DateTime.now;

  final LocationFlagRepository _repository;
  final LocationService _locationService;
  final String? Function() _employeeIdProvider;
  final AuthLocationModel? Function() _officeProvider;
  final int Function() _sessionEpochProvider;
  final Future<bool> Function()? _isOnline;
  final void Function()? _onRecordsChanged;
  final DateTime Function() _now;

  Timer? _timer;
  bool _observing = false;
  bool _capturing = false;

  String? _employeeId;
  int? _sessionEpoch;
  bool _checkedIn = false;
  bool _onBreak = false;
  bool _checkedOut = true;

  bool get isMonitoring =>
      _checkedIn && !_checkedOut && _employeeId != null;

  Future<void> handleAttendanceState({
    required String employeeId,
    required bool checkedIn,
    required bool onBreak,
    required bool checkedOut,
    bool captureImmediately = false,
  }) async {
    if (employeeId.isEmpty) return;
    if (_employeeId != null && _employeeId != employeeId) {
      await stop();
    }

    _employeeId = employeeId;
    _sessionEpoch = _sessionEpochProvider();
    _checkedIn = checkedIn;
    _onBreak = onBreak;
    _checkedOut = checkedOut || !checkedIn;

    if (!checkedIn || _checkedOut) {
      _cancelTimer();
      return;
    }

    _ensureObserver();
    _scheduleNext();
    if (captureImmediately) {
      await captureNow();
    }
  }

  Future<void> stop() async {
    _cancelTimer();
    _checkedIn = false;
    _onBreak = false;
    _checkedOut = true;
    _employeeId = null;
    _sessionEpoch = null;
    _removeObserver();
  }

  Future<void> captureNow() async {
    if (_capturing) return;
    if (!isMonitoring) return;
    final employeeId = _currentEmployee();
    if (employeeId == null) return;

    final at = _now();
    final existing = await _repository.existingSlot(
      employeeId: employeeId,
      at: at,
    );
    if (existing != null) return;
    if (!_stillCurrent(employeeId)) return;

    _capturing = true;
    try {
      final record = await _buildRecord(employeeId: employeeId, at: at);
      if (record == null) return;
      if (!_stillCurrent(employeeId)) return;
      await _repository.saveCheck(record);
      _onRecordsChanged?.call();
    } catch (e, st) {
      AppLogger.error('LocationFlagMonitor', 'captureNow', e, stackTrace: st);
    } finally {
      _capturing = false;
      if (isMonitoring) _scheduleNext();
    }
  }

  Future<LocationFlagRecord?> _buildRecord({
    required String employeeId,
    required DateTime at,
  }) async {
    final office = _officeProvider();
    final officePoint = GeoPoint.tryParse(office?.latLon);
    final radius = GeofenceHelper.normalizeRadius(office?.radiusMeters);

    double? latitude;
    double? longitude;
    double? accuracy;
    double? distance;
    bool? inside;
    var status = LocationCaptureStatus.unavailable;

    try {
      final reading = await _locationService.getFreshReading();
      if (reading.isMocked) {
        status = LocationCaptureStatus.mockDetected;
      } else {
        latitude = reading.location.lat;
        longitude = reading.location.lon;
        accuracy = reading.accuracyMeters;
        status = LocationCaptureStatus.available;
        if (officePoint != null) {
          distance = GeofenceHelper.distanceMeters(
            GeoPoint(lat: latitude, lon: longitude),
            officePoint,
          );
          inside = LocationFlagEvaluator.isInsideRadius(
            distance,
            radius.toDouble(),
          );
        }
      }
    } on LocationPermissionDeniedException {
      status = LocationCaptureStatus.permissionDenied;
    } on LocationServiceDisabledException {
      status = LocationCaptureStatus.serviceDisabled;
    } on LocationAccuracyTooLowException {
      status = LocationCaptureStatus.accuracyTooLow;
    } on MockLocationDetectedException {
      status = LocationCaptureStatus.mockDetected;
    } on LocationTimeoutException {
      status = LocationCaptureStatus.timeout;
    } catch (_) {
      status = LocationCaptureStatus.unavailable;
    }

    final online = await (_isOnline?.call() ?? Future.value(true));
    final workingIssue =
        _checkedIn && !_onBreak && inside == false;
    final syncStatus = workingIssue
        ? (online
              ? LocationFlagSyncStatus.pending
              : LocationFlagSyncStatus.pending)
        : LocationFlagSyncStatus.local;

    return LocationFlagRecord(
      id: LocationFlagRepository.newEventId(at),
      employeeId: employeeId,
      date: LocationFlagEvaluator.calendarDate(at),
      latitude: latitude,
      longitude: longitude,
      timestamp: at,
      locationAccuracy: accuracy,
      assignedLocationId: office?.id,
      officeLatitude: officePoint?.lat,
      officeLongitude: officePoint?.lon,
      allowedRadius: radius.toDouble(),
      distance: distance,
      checkInStatus: _checkedIn,
      breakStatus: _onBreak,
      checkOutStatus: _checkedOut,
      locationStatus: status,
      insideRadius: inside,
      flagNumber: LocationFlagEvaluator.flagNumberFor(at),
      cycleId: LocationFlagEvaluator.cycleIdFor(
        employeeId: employeeId,
        at: at,
      ),
      requiresServerSync: workingIssue,
      syncStatus: syncStatus,
      createdTimestamp: DateTime.now(),
    );
  }

  void _scheduleNext() {
    _cancelTimer();
    if (!isMonitoring) return;
    final now = _now();
    final next = LocationFlagEvaluator.nextAlignedCheck(now);
    var wait = next.difference(now);
    if (wait.isNegative || wait == Duration.zero) {
      wait = LocationFlagEvaluator.flagInterval;
    }
    _timer = Timer(wait, () {
      unawaited(captureNow());
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String? _currentEmployee() {
    final live = _employeeIdProvider();
    if (live == null || live.isEmpty) return null;
    if (_employeeId != live) return null;
    if (_sessionEpochProvider() != _sessionEpoch) return null;
    return live;
  }

  bool _stillCurrent(String employeeId) {
    return _currentEmployee() == employeeId && isMonitoring;
  }

  void _ensureObserver() {
    if (_observing) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  void _removeObserver() {
    if (!_observing) return;
    WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isMonitoring) {
      unawaited(captureNow());
    }
  }

  void dispose() {
    unawaited(stop());
  }
}
