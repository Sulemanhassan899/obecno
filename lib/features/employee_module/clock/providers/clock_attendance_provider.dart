import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/employee_module/clock/repositories/clock_attendance_repository.dart';
import 'package:Obecno/shared/location/data/location_model.dart';
import 'package:Obecno/shared/location/service/attendance_payload_model.dart';
import 'package:Obecno/shared/location/service/attendance_permission_service.dart';
import 'package:Obecno/shared/location/service/location_service.dart';
import 'package:flutter/foundation.dart';

import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/features/employee_module/clock/presentation/widgets/clock_attendance_engine.dart';

enum AttendanceSubmitStatus {
  idle,
  submitting,
  success,
  permissionDenied,
  failure,
}

@Deprecated(
  'Unused legacy attendance path. Bypasses geofence validation, tap '
  'cooldown, and synced-result checks present in '
  'SyncedClockScreenController. Do not wire this into the app.',
)
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
  bool isCheckInDisabled = false;

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

    final LocationModel location;
    try {
      location = await _locationService.getCurrentLocation();
    } catch (_) {
      status = AttendanceSubmitStatus.failure;
      errorMessage = 'Unable to get your location. Please try again.';
      notifyListeners();
      return false;
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
          id: '${DateTime.now().microsecondsSinceEpoch}',
          type: eventType,
          time: capturedAt,
          location: location.currentLocation,
        ),
      );

      status = AttendanceSubmitStatus.success;
      notifyListeners();
      return true;
    } on AttendanceBusinessException catch (e) {
      status = AttendanceSubmitStatus.failure;
      errorMessage = e.message;
      isCheckInDisabled = true;
      notifyListeners();
      return false;
    } catch (_) {
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
