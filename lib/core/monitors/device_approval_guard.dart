import 'dart:async';

import 'package:flutter/material.dart';

import 'package:obecno/core/helpers/dialog.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/main.dart';
import 'package:obecno/core/monitors/app_guard.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/core/routes/app_routes.dart';

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

    // Snapshot on policy *changes* (block / unregistered). Approved
    // background polls run every 10s and must not dump GPS telemetry or
    // rebuild routes on each tick.
    if (status != DeviceApprovalStatus.approved) {
      unawaited(logDeviceInfoToConsole());
    }

    // Scenario 2 + 6: show unregistered toast immediately (no frame delay).
    // Retry next frames only if the root overlay is not ready yet.
    if (status == DeviceApprovalStatus.approved) {
      reset();
      _navigateHomeIfOnBlockedScreen();
      return;
    }
    if (status == DeviceApprovalStatus.unregistered) {
      _armIfNewStatus('unregistered');
      _alertUnregistered(context, loginMessage: loginMessage);
      return;
    }
    if (status == DeviceApprovalStatus.blocked) {
      _armIfNewStatus('blocked');
      _navigateToBlockedScreen();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (status) {
        case DeviceApprovalStatus.blocked:
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

  /// Previously dumped device/GPS telemetry to the console. Kept as a
  /// no-op so call sites stay intact without log noise.
  static Future<void> _logDeviceInfoToConsole() async {}

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

    // Once per app open / login. Later device checks must not re-toast.
    if (_toastShown) return;
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
    String location;
    try {
      location = router.state.matchedLocation;
    } catch (_) {
      location = '';
    }
    if (location == '/device_blocked') return;

    AppLogger.info(
      '[UI_EXECUTION]\n'
      'type=NAVIGATION\n'
      'contextValid=true\n'
      'mounted=true\n'
      'navigatorAvailable=${rootNavigatorKey.currentState != null}\n'
      'source=DeviceApprovalGuard',
    );
    router.go('/device_blocked');
  }

  static void _navigateHomeIfOnBlockedScreen() {
    String location;
    try {
      location = router.state.matchedLocation;
    } catch (_) {
      return;
    }
    if (location != '/device_blocked') return;
    final home = bindings.authProvider.homeTarget == AuthHomeTarget.manager
        ? '/manager_nav'
        : '/employee_nav';
    router.go(home);
  }
}
