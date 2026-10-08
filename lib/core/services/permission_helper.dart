import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum AppPermission { location, notification, motion }

class PermissionService {
  PermissionService._();

  static Permission _map(AppPermission p) {
    switch (p) {
      case AppPermission.location:
        // Require "Allow all the time" (background) for attendance /
        // geofence while the app is closed. Always request When-In-Use
        // first (OS requirement), then escalate to Always — see [request].
        return Permission.locationAlways;
      case AppPermission.notification:
        return Permission.notification;
      case AppPermission.motion:
        // Android: ACTIVITY_RECOGNITION. iOS has no matching group —
        // `Permission.activityRecognition` is permanently denied there —
        // so use Motion & Fitness (`Permission.sensors`) instead.
        return defaultTargetPlatform == TargetPlatform.iOS
            ? Permission.sensors
            : Permission.activityRecognition;
    }
  }

  static Future<PermissionStatus> status(AppPermission p) async {
    final result = await _map(p).status;
    debugPrint('[PermissionService] status($p) -> $result');
    return result;
  }

  static Future<PermissionStatus> request(AppPermission p) async {
    if (p == AppPermission.location) {
      // Android/iOS require When-In-Use before Always / background.
      final whenInUse = await Permission.locationWhenInUse.status;
      if (!isAllowed(whenInUse)) {
        final whenInUseResult = await Permission.locationWhenInUse.request();
        debugPrint(
          '[PermissionService] request(locationWhenInUse) -> $whenInUseResult',
        );
        if (!isAllowed(whenInUseResult)) return whenInUseResult;
      }

      final always = await Permission.locationAlways.request();
      debugPrint('[PermissionService] request(locationAlways) -> $always');
      return always;
    }

    final result = await _map(p).request();
    debugPrint('[PermissionService] request($p) -> $result');
    return result;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Opens the exact **Location permission** screen (Allow all the time /
  /// While using / …). Call only after When-In-Use is already granted.
  ///
  /// Uses the OS background-location request — that is what opens the
  /// "Location permission" page. Do not use MANAGE_APP_PERMISSION (that
  /// opens the generic "App permissions" list on many devices).
  static Future<void> openExactLocationAlwaysPage() async {
    final result = await Permission.locationAlways.request();
    debugPrint(
      '[PermissionService] openExactLocationAlwaysPage -> $result',
    );
  }

  /// @deprecated Use [openExactLocationAlwaysPage].
  static Future<void> openLocationAlwaysSettings() =>
      openExactLocationAlwaysPage();

  static bool isAllowed(PermissionStatus s, [AppPermission? p]) {
    if (s.isGranted || s.isLimited || s.isProvisional) return true;
    // iOS Simulator (and devices without a motion coprocessor) report
    // Core Motion as restricted. Don't block attendance on that.
    if (p == AppPermission.motion &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        s.isRestricted) {
      return true;
    }
    return false;
  }

  static Future<bool> areAllPermissionsAllowed() async {
    final loc = await status(AppPermission.location);
    final notif = await status(AppPermission.notification);
    final motion = await status(AppPermission.motion);
    final result =
        isAllowed(loc) &&
        isAllowed(notif) &&
        isAllowed(motion, AppPermission.motion);
    debugPrint(
      '[PermissionService] areAllPermissionsAllowed() -> location: $loc, '
      'notification: $notif, motion: $motion => $result',
    );
    return result;
  }

  static Future<bool> areCriticalPermissionsAllowed() async {
    final loc = await status(AppPermission.location);
    final motion = await status(AppPermission.motion);
    final result = isAllowed(loc) && isAllowed(motion, AppPermission.motion);
    debugPrint(
      '[PermissionService] areCriticalPermissionsAllowed() -> location: $loc, '
      'motion: $motion => $result',
    );
    return result;
  }

  static Future<List<AppPermission>> missingPermissions() async {
    final missing = <AppPermission>[];
    for (final p in AppPermission.values) {
      final s = await status(p);
      if (!isAllowed(s, p)) missing.add(p);
    }
    return missing;
  }

  static String label(AppPermission p) {
    switch (p) {
      case AppPermission.location:
        return 'Location';
      case AppPermission.notification:
        return 'Notification';
      case AppPermission.motion:
        return 'Motion & Fitness';
    }
  }
}
