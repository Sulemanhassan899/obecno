import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum AppPermission { location, notification, motion }

class PermissionService {
  PermissionService._();

  static Permission _map(AppPermission p) {
    switch (p) {
      case AppPermission.location:
        // FIXED (root cause of "keeps asking for location permission even
        // though it was given"): this used to return `Permission.location`
        // ("Always"/background-location scope), but the only place the app
        // ever actually *requests* location -- `EnablePermissionsScreen.
        // _handleContinue` -- requests `Permission.locationWhenInUse`
        // (foreground-only), which is also what `areAllPermissionsAllowed`
        // below checks. Checking a *different, broader* permission here
        // than the one that was actually granted meant `status`/`request`
        // for `AppPermission.location` could report "not granted" forever
        // -- so `AppGuard._checkAll()` kept re-showing the "Permission
        // Required" dialog on every 10s tick and app resume even right
        // after the user tapped "Allow" and the OS granted when-in-use
        // access. Aligning this mapping with what's actually requested
        // elsewhere fixes the loop.
        return Permission.locationWhenInUse;
      case AppPermission.notification:
        return Permission.notification;
      case AppPermission.motion:
        return Permission.activityRecognition;
    }
  }

  static Future<PermissionStatus> status(AppPermission p) async {
    final result = await _map(p).status;
    debugPrint('[PermissionService] status($p) -> $result');
    return result;
  }

  static Future<PermissionStatus> request(AppPermission p) async {
    final result = await _map(p).request();
    debugPrint('[PermissionService] request($p) -> $result');
    return result;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }

  static bool isAllowed(PermissionStatus s) {
    return s.isGranted || s.isLimited || s.isProvisional;
  }

  static Future<bool> areAllPermissionsAllowed() async {
    final loc = await Permission.locationWhenInUse.status;
    final notif = await Permission.notification.status;
    final motion = await Permission.activityRecognition.status;
    final result = isAllowed(loc) && isAllowed(notif) && isAllowed(motion);
    debugPrint(
      '[PermissionService] areAllPermissionsAllowed() -> location: $loc, '
      'notification: $notif, motion: $motion => $result',
    );
    return result;
  }

  /// FIXED (bug: "won't let me check in" even though Location shows as
  /// Allowed in Android's own App permissions screen): `areAllPermissionsAllowed`
  /// treated notification as just as blocking as location/motion. But
  /// notification isn't a runtime entry on Android's "Permissions" page at
  /// all -- it lives under a separate "Notifications" toggle in system
  /// settings (that's why the OS screen the user screenshotted shows
  /// Location/Physical activity/Storage as Allowed with nothing about
  /// notifications). So a user who has location + motion granted but has
  /// notifications switched off at the OS level had every check-in attempt
  /// silently blocked by a dialog that (misleadingly) still said "Location
  /// and notification permissions are required."
  ///
  /// Attendance is recorded via GPS, not push notifications, so the actual
  /// check-in flow should only be gated on the permissions attendance
  /// depends on. Notification is surfaced separately (see
  /// [missingPermissions]) as a non-blocking nudge instead.
  static Future<bool> areCriticalPermissionsAllowed() async {
    final loc = await Permission.locationWhenInUse.status;
    final motion = await Permission.activityRecognition.status;
    final result = isAllowed(loc) && isAllowed(motion);
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
      if (!isAllowed(s)) missing.add(p);
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
