import 'package:permission_handler/permission_handler.dart';

enum AppPermission {
  location,
  notification,
  motion,
}

class PermissionService {
  PermissionService._();

  static Permission _map(AppPermission p) {
    switch (p) {
      case AppPermission.location:
        return Permission.location;
      case AppPermission.notification:
        return Permission.notification;
      case AppPermission.motion:
        return Permission.activityRecognition;
    }
  }

  static Future<PermissionStatus> status(AppPermission p) {
    return _map(p).status;
  }

  static Future<PermissionStatus> request(AppPermission p) {
    return _map(p).request();
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }

  static bool isAllowed(PermissionStatus s) {
    return s.isGranted || s.isLimited || s.isProvisional;
  }
}