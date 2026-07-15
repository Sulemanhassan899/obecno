import 'package:geolocator/geolocator.dart';

// NOTE: adjust this import to wherever `permission_helper.dart` actually
// lives in the project. It provides the EXISTING `PermissionService`
// (static) and `AppPermission` enum -- neither is modified here.
import 'package:Obecno/core/services/permission_helper.dart';

/// Attendance-specific permission orchestration, built ONLY on top of
/// the existing `PermissionService` (permission_helper.dart) -- no new
/// permission logic, no new UI/dialogs. This just:
///   1. Checks location + notification status via the existing service
///   2. Requests them via the existing service's `request()` if not
///      already granted (triggers the OS system dialog -- not a custom
///      screen)
///   3. Additionally checks that location services (GPS) are switched
///      on at the OS level, since that's a device setting, not a
///      runtime permission, and `PermissionService` doesn't cover it
class AttendancePermissionService {
  const AttendancePermissionService();

  /// Returns true only if everything needed to submit an attendance
  /// action is in place. Never throws.
  Future<bool> checkAndRequestPermissions() async {
    try {
      final locationOk = await _ensureGranted(AppPermission.location);
      final notificationOk = await _ensureGranted(AppPermission.notification);

      if (!locationOk || !notificationOk) return false;

      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      // Never let a permission-plugin hiccup crash the attendance flow.
      return false;
    }
  }

  Future<bool> _ensureGranted(AppPermission permission) async {
    final status = await PermissionService.status(permission);
    if (PermissionService.isAllowed(status)) return true;

    final requested = await PermissionService.request(permission);
    return PermissionService.isAllowed(requested);
  }
}
