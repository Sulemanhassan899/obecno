import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:system_clock/system_clock.dart';

import 'package:Obecno/core/helpers/dialog.dart';
import 'package:Obecno/core/helpers/toast_helper.dart';
import 'package:Obecno/core/services/logger.dart';
import 'package:Obecno/main.dart';
import 'package:Obecno/core/monitors/app_guard.dart';
import 'package:Obecno/features/employee_module/routes/app_routes.dart';
import 'package:Obecno/shared/location/service/geofence_helper.dart';

enum DeviceApprovalStatus { approved, unregistered, blocked, permissionDenied }

class DeviceApprovalGuard {
  DeviceApprovalGuard._();

  static bool _dialogShown = false;
  static bool _toastShown = false;
  static String? _lastStatusKey;

  static void reset() {
    _dialogShown = false;
    _toastShown = false;
    _lastStatusKey = null;
  }

  static BuildContext? _safeContext(BuildContext? context) {
    if (context != null && context.mounted) return context;

    final overlayContext = rootNavigatorKey.currentState?.overlay?.context;
    if (overlayContext != null && overlayContext.mounted) {
      return overlayContext;
    }

    return null;
  }

  static void handle({
    required BuildContext? context,
    required DeviceApprovalStatus status,
    bool loginMessage = false,
    bool isRejected = false,
  }) {
    // Suppress device toast/dialog while the custom permission onboarding
    // screen is active (Scenario 1). Blocked still navigates.
    if (AppGuard.permissionOnboardingPending &&
        status != DeviceApprovalStatus.blocked) {
      return;
    }

    AppLogger.info(
      '[DEVICE_POLICY]\n'
      'status=${status.name}\n'
      'policy=${_policyFor(status)}\n'
      'action=${_actionFor(status, loginMessage: loginMessage, isRejected: isRejected)}',
    );

    // Snapshot device + location + clocks whenever policy is evaluated.
    unawaited(logDeviceInfoToConsole());

    // Scenario 2 + 6: show unregistered toast immediately (no frame delay).
    // Retry next frames only if the root overlay is not ready yet.
    if (status == DeviceApprovalStatus.approved) {
      reset();
      return;
    }
    if (status == DeviceApprovalStatus.unregistered) {
      _armIfNewStatus('unregistered');
      _alertUnregistered(context, loginMessage: loginMessage);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (status) {
        case DeviceApprovalStatus.blocked:
          _armIfNewStatus('blocked');
          _alertBlocked(context, isRejected: isRejected);
          _navigateToBlockedScreen();
          return;

        case DeviceApprovalStatus.permissionDenied:
          _alertPermissionDenied(context);
          return;

        case DeviceApprovalStatus.approved:
        case DeviceApprovalStatus.unregistered:
          return;
      }
    });
  }

  /// Public entry used by ClockScreen / other call sites.
  static Future<void> logDeviceInfoToConsole() => _logDeviceInfoToConsole();

  /// Collects device, wall-clock, monotonic time, GPS, and geofence intel
  /// and prints it to the console (Flutter-only; no custom native code).
  static Future<void> _logDeviceInfoToConsole() async {
    final buf = StringBuffer();
    buf.writeln('[DEVICE_TELEMETRY]');

    // ── 1. DEVICE INFORMATION ──────────────────────────────────────────
    try {
      final info = await bindings.deviceInfoService.collect();
      buf.writeln('📦 1. DEVICE INFORMATION');
      buf.writeln('deviceId=${info.deviceId}');
      buf.writeln('deviceName=${info.deviceName}');
      buf.writeln('model=${info.model}');
      buf.writeln('manufacturer=${info.manufacturer}');
      buf.writeln('platform=${info.platform}');
      buf.writeln('os=${info.os}');
      buf.writeln('osVersion=${info.osVersion}');
      buf.writeln('appVersion=${info.appVersion}');
      buf.writeln('deviceDetails=${info.deviceDetails}');
    } catch (e) {
      buf.writeln('📦 1. DEVICE INFORMATION → ERROR: $e');
    }

    // ── 2. TIME & TIMEZONE (WALL CLOCK) ────────────────────────────────
    try {
      final local = DateTime.now();
      final utc = local.toUtc();
      final hour = local.hour;
      final timeBucket = hour < 12
          ? 'morning'
          : (hour < 17 ? 'afternoon' : 'evening');
      const dayNames = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];
      buf.writeln('⏱ 2. TIME & TIMEZONE (WALL CLOCK)');
      buf.writeln('localTime=$local');
      buf.writeln('utcTime=$utc');
      buf.writeln('timezoneName=${local.timeZoneName}');
      buf.writeln('timezoneOffsetMinutes=${local.timeZoneOffset.inMinutes}');
      buf.writeln('isoTimestamp=${local.toIso8601String()}');
      buf.writeln(
        'isWeekend=${local.weekday == DateTime.saturday || local.weekday == DateTime.sunday}',
      );
      buf.writeln('dayOfWeek=${dayNames[local.weekday - 1]}');
      buf.writeln('hourOfDay=$hour');
      buf.writeln('timeBucket=$timeBucket');
    } catch (e) {
      buf.writeln('⏱ 2. TIME & TIMEZONE → ERROR: $e');
    }

    // ── 3. SYSTEM MONOTONIC TIME ───────────────────────────────────────
    try {
      final elapsedMs = SystemClock.elapsedRealtime().inMilliseconds;
      final uptimeMs = SystemClock.uptime().inMilliseconds;
      buf.writeln('⏱ 3. SYSTEM MONOTONIC TIME');
      buf.writeln('elapsedRealtime=$elapsedMs');
      buf.writeln('uptimeMillis=$uptimeMs');
      buf.writeln(
        'platformNote=${Platform.isAndroid ? "android(SystemClock via system_clock ffi)" : Platform.isIOS ? "ios(process uptime via system_clock ffi)" : Platform.operatingSystem}',
      );
    } catch (e) {
      buf.writeln('⏱ 3. SYSTEM MONOTONIC TIME → ERROR: $e');
    }

    // ── 4. LOCATION DATA ──────────────────────────────────────────────
    Position? position;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (!serviceEnabled) {
        buf.writeln('📍 4. LOCATION DATA → location services disabled');
      } else if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        buf.writeln('📍 4. LOCATION DATA → permission denied');
      } else {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 12),
        );
        buf.writeln('📍 4. LOCATION DATA');
        buf.writeln('latitude=${position.latitude}');
        buf.writeln('longitude=${position.longitude}');
        buf.writeln('accuracy=${position.accuracy}');
        buf.writeln('altitude=${position.altitude}');
        buf.writeln('speed=${position.speed}');
        buf.writeln('heading=${position.heading}');
        buf.writeln('timestamp=${position.timestamp}');
        buf.writeln('isMocked=${position.isMocked}');
      }
    } catch (e) {
      buf.writeln('📍 4. LOCATION DATA → ERROR: $e');
    }

    // ── 5. DERIVED LOCATION INTELLIGENCE ───────────────────────────────
    try {
      buf.writeln('🧭 5. DERIVED LOCATION INTELLIGENCE');
      final office = bindings.locationProvider.companyLocation;
      final radius = bindings.locationProvider.radiusMeters;
      final officeName = bindings.locationProvider.companyLocationName;

      if (position == null) {
        buf.writeln('distanceFromOffice=n/a');
        buf.writeln('isWithinRadius=n/a');
        buf.writeln('office=$officeName ($office)');
        buf.writeln('radiusMeters=$radius');
      } else {
        final user = GeoPoint(lat: position.latitude, lon: position.longitude);
        final result = GeofenceHelper.evaluate(
          companyLocation: office,
          user: user,
          radiusMeters: radius,
          locationName: officeName,
        );
        buf.writeln('office=$officeName ($office)');
        buf.writeln('radiusMeters=${result.radiusMeters}');
        buf.writeln(
          'distanceFromOfficeMeters=${result.distanceMeters.isFinite ? result.distanceMeters.toStringAsFixed(2) : "infinity"}',
        );
        buf.writeln('isWithinRadius=${result.isInside}');
        buf.writeln('geofenceMessage=${result.message}');

        final address = await _reverseGeocodeParts(
          lat: position.latitude,
          lon: position.longitude,
        );
        buf.writeln('country=${address['country']}');
        buf.writeln('city=${address['city']}');
        buf.writeln('area=${address['area']}');
        buf.writeln('street=${address['street']}');
      }
    } catch (e) {
      buf.writeln('🧭 5. DERIVED LOCATION INTELLIGENCE → ERROR: $e');
    }

    final log = buf.toString().trimRight();
    AppLogger.info(log);
    debugPrint(log);
  }

  static Future<Map<String, String?>> _reverseGeocodeParts({
    required double lat,
    required double lon,
  }) async {
    final empty = <String, String?>{
      'country': null,
      'city': null,
      'area': null,
      'street': null,
    };
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$lat',
        'lon': '$lon',
        'zoom': '18',
        'accept-language': 'en',
      });
      final response = await http
          .get(
            uri,
            headers: const {
              'User-Agent': 'Obecno-Attendance-App/1.0 (device-telemetry)',
              'Accept-Language': 'en',
            },
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return empty;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return empty;
      final address = decoded['address'];
      if (address is! Map) return empty;

      String? pick(List<String> keys) {
        for (final key in keys) {
          final value = address[key];
          if (value is String && value.trim().isNotEmpty) return value.trim();
        }
        return null;
      }

      return {
        'country': pick(const ['country']),
        'city': pick(const ['city', 'town', 'village', 'municipality']),
        'area': pick(const [
          'suburb',
          'neighbourhood',
          'city_district',
          'county',
          'state_district',
        ]),
        'street': pick(const ['road', 'pedestrian', 'footway', 'path']),
      };
    } catch (_) {
      return empty;
    }
  }

  static String _policyFor(DeviceApprovalStatus status) {
    switch (status) {
      case DeviceApprovalStatus.approved:
        return 'CLEAR_ALERTS';
      case DeviceApprovalStatus.blocked:
        return 'BLOCK_AND_ROUTE';
      case DeviceApprovalStatus.unregistered:
        return 'REGISTER_THEN_PROMPT';
      case DeviceApprovalStatus.permissionDenied:
        return 'PROMPT_ONLY';
    }
  }

  static String _actionFor(
    DeviceApprovalStatus status, {
    required bool loginMessage,
    required bool isRejected,
  }) {
    switch (status) {
      case DeviceApprovalStatus.approved:
        return 'NONE';
      case DeviceApprovalStatus.blocked:
        return 'SHOW_TOAST + SHOW_DIALOG + NAVIGATE(/device_blocked)'
            '${isRejected ? ' [rejected]' : ''}';
      case DeviceApprovalStatus.unregistered:
        return 'SHOW_TOAST${loginMessage ? ' [loginMessage]' : ''}';
      case DeviceApprovalStatus.permissionDenied:
        return 'SHOW_DIALOG';
    }
  }

  static void _armIfNewStatus(String key) {
    if (_lastStatusKey != key) {
      _dialogShown = false;
      _toastShown = false;
      _lastStatusKey = key;
    }
  }

  static void _logUiExecution({
    required String type,
    required BuildContext? rawContext,
    required BuildContext? resolvedContext,
  }) {
    AppLogger.info(
      '[UI_EXECUTION]\n'
      'type=$type\n'
      'contextValid=${resolvedContext != null}\n'
      'mounted=${resolvedContext?.mounted ?? false}\n'
      'navigatorAvailable=${rootNavigatorKey.currentState != null}\n'
      'source=DeviceApprovalGuard',
    );
  }

  static void _alertBlocked(BuildContext? context, {required bool isRejected}) {
    final safeContext = _safeContext(context);
    _logUiExecution(
      type: 'TOAST+DIALOG',
      rawContext: context,
      resolvedContext: safeContext,
    );

    if (safeContext == null) {
      AppLogger.error(
        'DeviceApprovalGuard',
        '_alertBlocked',
        '[ERROR]\ntype=NAVIGATOR_CONTEXT_ERROR\nreason=No Navigator ancestor / overlay not ready\nsource=BLOCKED_ALERT',
      );
      return;
    }

    if (!_toastShown) {
      _toastShown = true;
      ToastHelper.deviceBlockedAlert(safeContext, isRejected: isRejected);
    }

    if (!_dialogShown) {
      _dialogShown = true;
      DialogHelper.show(
        context: safeContext,
        title: 'Device alert',
        subtitle:
            'This device may be restricted. Contact your administrator if access appears unusual.',
        buttonText: 'Okay',
        barrierDismissible: true,
        onButtonTap: () {},
      );
    }
  }

  static void _alertUnregistered(
    BuildContext? context, {
    required bool loginMessage,
    int framesLeft = 12,
  }) {
    final safeContext = _safeContext(context);
    _logUiExecution(
      type: 'TOAST',
      rawContext: context,
      resolvedContext: safeContext,
    );

    if (safeContext == null) {
      if (framesLeft > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _alertUnregistered(
            context,
            loginMessage: loginMessage,
            framesLeft: framesLeft - 1,
          );
        });
        return;
      }
      AppLogger.error(
        'DeviceApprovalGuard',
        '_alertUnregistered',
        '[ERROR]\ntype=NAVIGATOR_CONTEXT_ERROR\nreason=No Navigator ancestor / overlay not ready\nsource=UNREGISTERED_ALERT',
      );
      return;
    }

    // Scenario 2 + 6: ALWAYS toast while not approved (pending counts too).
    ToastHelper.unregisteredDevice(safeContext);
    _toastShown = true;
  }

  static void _alertPermissionDenied(BuildContext? context) {
    final safeContext = _safeContext(context);
    _logUiExecution(
      type: 'DIALOG',
      rawContext: context,
      resolvedContext: safeContext,
    );

    if (safeContext == null) {
      AppLogger.error(
        'DeviceApprovalGuard',
        '_alertPermissionDenied',
        '[ERROR]\ntype=NAVIGATOR_CONTEXT_ERROR\nreason=No Navigator ancestor / overlay not ready\nsource=PERMISSION_DENIED_ALERT',
      );
      return;
    }

    DialogHelper.show(
      context: safeContext,
      title: 'Permission Required',
      subtitle: 'Please enable the required permission to continue.',
      buttonText: 'Okay',
      barrierDismissible: true,
      onButtonTap: () {},
    );
  }

  static void _navigateToBlockedScreen() {
    AppLogger.info(
      '[UI_EXECUTION]\n'
      'type=NAVIGATION\n'
      'contextValid=true\n'
      'mounted=true\n'
      'navigatorAvailable=${rootNavigatorKey.currentState != null}\n'
      'source=DeviceApprovalGuard',
    );
    // `router.go` is safe to call unconditionally: GoRouter no-ops if
    // already on that route, and it never needs a BuildContext.
    router.go('/device_blocked');
  }
}
