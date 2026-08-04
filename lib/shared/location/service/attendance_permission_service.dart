import 'package:geolocator/geolocator.dart';

import 'package:Obecno/core/services/permission_helper.dart';

class AttendancePermissionService {
  const AttendancePermissionService();

  Future<bool> checkAndRequestPermissions() async {
    try {
      final locationOk = await _ensureGranted(AppPermission.location);
      final notificationOk = await _ensureGranted(AppPermission.notification);

      if (!locationOk || !notificationOk) return false;

      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
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
