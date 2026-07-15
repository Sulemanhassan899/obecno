
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/employee_module/clock/repositories/clock_attendance_repository.dart';
import 'package:Obecno/shared/location/data/location_model.dart';
import 'package:Obecno/shared/location/service/attendance_payload_model.dart';
import 'package:Obecno/shared/location/service/attendance_permission_service.dart';
import 'package:Obecno/shared/location/service/location_service.dart';
import 'package:flutter/foundation.dart';

// Existing, untouched clock module files -- reused, not duplicated.
import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/features/employee_module/clock/presentation/widgets/clock_attendance_engine.dart';

enum AttendanceSubmitStatus {
  idle,
  submitting,
  success,
  permissionDenied,
  failure,
}

class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider(
    this._repository,
    this._permissionService,
    this._locationService,
  );

  final AttendanceRepository _repository;
  final AttendancePermissionService _permissionService;
  final LocationService _locationService;

  final List<AttendanceEvent> _events = [];
  List<AttendanceEvent> get events => List.unmodifiable(_events);

  AttendanceSubmitStatus status = AttendanceSubmitStatus.idle;
  String? errorMessage;

  /// Set true when the server explicitly rejects an action (business
  /// failure, e.g. invalid action / out of range) rather than a
  /// connectivity/transport failure. Per spec, the check-in control
  /// stays disabled once this happens until [clearError] resets it.
  bool isCheckInDisabled = false;

  /// Duration/status derived from `_events` via the EXISTING
  /// `AttendanceEngine.compute` -- not reimplemented here.
  AttendanceSummary get summary => AttendanceEngine.compute(_events);

  Future<bool> checkIn() =>
      _handleAction(AttendanceEventType.checkIn, AttendanceAction.checkIn);

  Future<bool> checkOut() =>
      _handleAction(AttendanceEventType.checkOut, AttendanceAction.checkOut);

  Future<bool> startBreak() => _handleAction(
    AttendanceEventType.breakStart,
    AttendanceAction.breakStart,
  );

  Future<bool> endBreak() =>
      _handleAction(AttendanceEventType.breakEnd, AttendanceAction.breakEnd);

  Future<bool> _handleAction(
    AttendanceEventType eventType,
    String apiAction,
  ) async {
    // Capture the time IMMEDIATELY on press. This exact instant is what
    // gets stored locally and (if applicable) what the queue holds --
    // it is never recalculated or overwritten later, including at sync
    // time.
    final capturedAt = DateTime.now();

    status = AttendanceSubmitStatus.submitting;
    errorMessage = null;
    notifyListeners();

    final permitted = await _permissionService.checkAndRequestPermissions();
    if (!permitted) {
      status = AttendanceSubmitStatus.permissionDenied;
      errorMessage = 'Location and notification permissions are required.';
      notifyListeners();
      return false;
    }

    LocationModel? location;
    try {
      location = await _locationService.getCurrentLocation();
    } catch (_) {
      // A GPS fetch failure shouldn't block the attendance action --
      // submit without coordinates rather than losing the event.
      location = null;
    }

    final payload = AttendancePayloadModel(
      action: apiAction,
      capturedAt: capturedAt,
      location: location,
    );

    try {
      await _repository.submitAttendance(payload);

      _events.add(
        AttendanceEvent(
          type: eventType,
          time: capturedAt,
          location: location?.currentLocation,
        ),
      );

      status = AttendanceSubmitStatus.success;
      notifyListeners();
      return true;
    } on AttendanceBusinessException catch (e) {
      // Server explicitly rejected the action (success:false) -- not a
      // connectivity problem, so it was never queued. Surface the exact
      // server message and keep the control disabled per spec.
      status = AttendanceSubmitStatus.failure;
      errorMessage = e.message;
      isCheckInDisabled = true;
      notifyListeners();
      return false;
    } catch (_) {
      // submitAttendance queues transport-level failures internally
      // (offline / timeout / 5xx), but this stays defensive per the
      // "no unhandled exceptions" rule.
      status = AttendanceSubmitStatus.failure;
      errorMessage = 'Failed to record attendance. Please try again.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    if (errorMessage == null && !isCheckInDisabled) return;
    errorMessage = null;
    isCheckInDisabled = false;
    notifyListeners();
  }
}
