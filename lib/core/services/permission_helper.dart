import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' show Geolocator, LocationPermission;
import 'package:permission_handler/permission_handler.dart';

enum AppPermission { location, notification, motion }

class PermissionService {
  PermissionService._();

  static Permission _map(AppPermission p) {
    switch (p) {
      case AppPermission.location:
        // Prefer Always for mapping/request escalation. Status reads are
        // handled by [_locationStatus] so When-In-Use is not reported as OFF.
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
    if (p == AppPermission.location) {
      // AppGuard / UI "is location OFF?" — When-In-Use counts as ON.
      // (Always often lags as denied right after grant until process restart.)
      return _locationStatus(requireAlways: false);
    }
    return _map(p).status;
  }

  /// Background / geofence gate used by [areAllPermissionsAllowed].
  static Future<PermissionStatus> locationAlwaysStatus() async {
    return _locationStatus(requireAlways: true);
  }

  static Future<PermissionStatus> _locationStatus({
    required bool requireAlways,
  }) async {
    final always = await Permission.locationAlways.status;
    if (isAllowed(always)) return always;

    // Cross-check OS via Geolocator — permission_handler Always status is
    // frequently stale after Settings / the system location page.
    try {
      final geo = await Geolocator.checkPermission();
      if (geo == LocationPermission.always) {
        return PermissionStatus.granted;
      }
      if (!requireAlways && geo == LocationPermission.whileInUse) {
        return PermissionStatus.granted;
      }
    } catch (_) {}

    final location = await Permission.location.status;
    if (isAllowed(location)) {
      if (!requireAlways) return location;
      // Permission.location can mean when-in-use on some Android versions.
    }

    final whenInUse = await Permission.locationWhenInUse.status;
    if (!requireAlways && isAllowed(whenInUse)) return whenInUse;

    return always;
  }

  static Future<PermissionStatus> request(AppPermission p) async {
    if (p == AppPermission.location) {
      // Android/iOS require When-In-Use before Always / background.
      final whenInUse = await Permission.locationWhenInUse.status;
      if (!isAllowed(whenInUse)) {
        final whenInUseResult = await Permission.locationWhenInUse.request();
        if (!isAllowed(whenInUseResult)) return whenInUseResult;
      }

      return Permission.locationAlways.request();
    }

    return _map(p).request();
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
    await Permission.locationAlways.request();
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
    // Full onboarding: prefer Always, but accept a Geolocator "always" read
    // when permission_handler status is stale.
    final loc = await locationAlwaysStatus();
    final notif = await status(AppPermission.notification);
    final motion = await status(AppPermission.motion);
    return isAllowed(loc) &&
        isAllowed(notif) &&
        isAllowed(motion, AppPermission.motion);
  }

  /// Splash / cold-start gate: When-In-Use location is enough to enter the app.
  /// (Always is preferred for background geofence but is often still reported
  /// as denied after grant, and Enable Permissions already lets users through
  /// with When-In-Use — requiring Always here caused a restart loop.)
  static Future<bool> areCriticalPermissionsAllowed() async {
    final loc = await _locationStatus(requireAlways: false);
    final motion = await status(AppPermission.motion);
    return isAllowed(loc) && isAllowed(motion, AppPermission.motion);
  }

  /// First-time login gate: location (when-in-use) + notification + motion.
  static Future<bool> areFirstLoginPermissionsAllowed() async {
    final loc = await _locationStatus(requireAlways: false);
    final notif = await status(AppPermission.notification);
    final motion = await status(AppPermission.motion);
    return isAllowed(loc) &&
        isAllowed(notif) &&
        isAllowed(motion, AppPermission.motion);
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
