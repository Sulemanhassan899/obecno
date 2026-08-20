// import 'dart:async';
// import 'package:Obecno/core/services/connectivity_service.dart';
// import 'package:Obecno/core/services/notification_helper.dart';
// import 'package:Obecno/core/services/permission_helper.dart';
// import 'package:Obecno/core/state/change_notifier_provider.dart';
// import 'package:Obecno/features/auth/providers/auth_provider.dart';
// import 'package:Obecno/routes/app_routes.dart';
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';

// class AppGuard extends StatefulWidget {
//   final Widget child;

//   const AppGuard({super.key, required this.child});

//   @override
//   State<AppGuard> createState() => _AppGuardState();
// }

// class _AppGuardState extends State<AppGuard> with WidgetsBindingObserver {
//   Timer? _timer;
//   bool _dialogOpen = false;

//   bool _internetDialogDismissedForOutage = false;

//   AuthProvider? _authProvider;
//   bool? _lastAuthenticated;

//   final List<AppPermission> _permissions = [
//     AppPermission.location,
//     AppPermission.motion,
//   ];

//   @override
//   void initState() {
//     super.initState();

//     WidgetsBinding.instance.addObserver(this);

//     ConnectivityService.start();

//     _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkAll());

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _checkAll();

//       _authProvider = context.read<AuthProvider>();
//       _lastAuthenticated = _authProvider?.isAuthenticated;
//       _authProvider?.addListener(_onAuthChanged);
//     });

//     // Listen real-time internet changes
//     ConnectivityService.stream.listen((connected) {
//       if (!connected) {
//         if (_internetDialogDismissedForOutage) return;
//         _showInternetDialog();
//       } else {
//         _internetDialogDismissedForOutage = false;
//       }
//     });
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _timer?.cancel();
//     ConnectivityService.stop();
//     _authProvider?.removeListener(_onAuthChanged);
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       _checkAll();

//       _revalidateSession();
//     }
//   }

//   Future<void> _revalidateSession() async {
//     final authProvider = _authProvider;
//     if (!mounted || authProvider == null) return;
//     if (!authProvider.isAuthenticated) return;

//     await authProvider.validateSessionOnUnauthorized();
//   }

//   void _onAuthChanged() {
//     if (!mounted || _authProvider == null) return;

//     final isAuth = _authProvider!.isAuthenticated;

//     if (_lastAuthenticated == true && isAuth == false) {
//       router.go('/login');
//     }

//     _lastAuthenticated = isAuth;
//   }

//   Future<void> _checkAll() async {
//     if (!mounted || _dialogOpen) return;

//     // 1️⃣ Permissions
//     for (final p in _permissions) {
//       final status = await PermissionService.status(p);
//       debugPrint('[AppGuard] _checkAll: $p status = $status');

//       if (!PermissionService.isAllowed(status)) {
//         debugPrint('[AppGuard] $p not allowed, showing permission dialog.');
//         await _showPermissionDialog(p, status);
//         return;
//       }
//     }

//     final notif = await NotificationService.isEnabled();
//     if (!notif) {
//       await _showNotificationDialog();
//       return;
//     }

//     final connected = await ConnectivityService.isConnected();
//     if (!connected) {
//       if (_internetDialogDismissedForOutage) return;
//       await _showInternetDialog();
//       return;
//     }
//     _internetDialogDismissedForOutage = false;
//   }

//   Future<void> _showPermissionDialog(
//     AppPermission p,
//     PermissionStatus status,
//   ) async {
//     _dialogOpen = true;

//     final isPermanent = status.isPermanentlyDenied || status.isRestricted;

//     await _dialog(
//       title: "Permission Required",
//       message: "${PermissionService.label(p)} permission is turned OFF",
//       button: isPermanent ? "Open Settings" : "Allow",
//       onPressed: () async {
//         if (isPermanent) {
//           await PermissionService.openSettings();
//         } else {
//           await PermissionService.request(p);
//         }
//       },
//     );

//     _dialogOpen = false;
//   }

//   Future<void> _showNotificationDialog() async {
//     _dialogOpen = true;

//     await _dialog(
//       title: "Notifications Disabled",
//       message: "Enable notifications to continue",
//       button: "Enable",
//       onPressed: () async {
//         await NotificationService.request();
//       },
//     );

//     _dialogOpen = false;
//   }

//   Future<void> _showInternetDialog() async {
//     if (_dialogOpen) return;

//     _dialogOpen = true;

//     await _dialog(
//       title: "No Internet",
//       message: "Check your connection",
//       button: "Retry",
//       onPressed: () {},

//       onLater: () => _internetDialogDismissedForOutage = true,
//       recheckAfterLater: false,
//     );

//     _dialogOpen = false;
//   }

//   Future<void> _dialog({
//     required String title,
//     required String message,
//     required String button,
//     required VoidCallback onPressed,
//     VoidCallback? onLater,

//     bool recheckAfterLater = true,
//   }) async {
//     if (!mounted) return;

//     var laterPressed = false;

//     await showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text(title),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () {
//               laterPressed = true;
//               Navigator.pop(context);
//               onLater?.call();
//             },
//             child: const Text("Later"),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               onPressed();
//             },
//             child: Text(button),
//           ),
//         ],
//       ),
//     );

//     if (mounted && (!laterPressed || recheckAfterLater)) _checkAll();
//   }

//   @override
//   Widget build(BuildContext context) => widget.child;
// }

import 'dart:async';
import 'package:Obecno/core/helpers/dialog.dart';
import 'package:Obecno/core/services/connectivity_service.dart';
import 'package:Obecno/core/services/logger.dart';
import 'package:Obecno/core/services/notification_helper.dart';
import 'package:Obecno/core/services/permission_helper.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/features/employee_module/more/providers/device_provider.dart';
import 'package:Obecno/features/employee_module/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AppGuard extends StatefulWidget {
  final Widget child;

  const AppGuard({super.key, required this.child});

  /// Set by the first-time-login flow while the user is on Enable
  /// Permissions. While true, AppGuard will not show its own permission
  /// dialogs -- first-time grant belongs to that screen.
  static bool permissionOnboardingPending = false;

  /// True while AppGuard is presenting a permission/notification dialog.
  /// ClockScreen uses this so it does not stack a second prompt on top.
  static bool isPrompting = false;

  /// Drops a permission dialog that raced onto the root navigator before
  /// Enable Permissions became visible.
  static void dismissOpenPromptIfAny() {
    if (!isPrompting) return;
    final nav = rootNavigatorKey.currentState;
    if (nav != null && nav.canPop()) nav.pop();
  }

  @override
  State<AppGuard> createState() => _AppGuardState();
}

class _AppGuardState extends State<AppGuard> with WidgetsBindingObserver {
  Timer? _offlineDebounce;
  StreamSubscription<bool>? _connectivitySub;
  bool _dialogOpen = false;
  bool _checkInProgress = false;
  bool _internetDialogOpen = false;

  bool _internetDialogDismissedForOutage = false;

  AuthProvider? _authProvider;
  bool? _lastAuthenticated;

  // Tracks whether AppGuard has run its very first `_checkAll()` yet, purely
  // for [PERMISSION_CHECK] log accuracy (`isFirstLaunch`). Not used for any
  // gating decision -- the actual "don't prompt before login" behavior is
  // driven entirely by `_authProvider?.isAuthenticated`, see `_checkAll`.
  bool _firstCheckDone = false;

  final List<AppPermission> _permissions = [
    AppPermission.location,
    AppPermission.motion,
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    ConnectivityService.start();

    // No periodic timer: permission/device checks run on app start and when
    // the app resumes (see didChangeAppLifecycleState). Connectivity is
    // handled by the stream below.

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // FIX: resolve AuthProvider *before* the first `_checkAll()` runs.
      // Previously `_checkAll()` was called first and `_authProvider` was
      // assigned only afterwards in this same callback -- so the very
      // first permission/notification check of the app's life always ran
      // with `_authProvider == null`, making the isLoggedIn gate below
      // unreliable to reason about (it happened to skip on that first call
      // only because null == not-authenticated, not because the check was
      // actually looking at real auth state).
      _authProvider = context.read<AuthProvider>();
      _lastAuthenticated = _authProvider?.isAuthenticated;
      _authProvider?.addListener(_onAuthChanged);

      _checkAll(trigger: 'APP_START');
    });

    // Listen real-time internet changes. The Retry popup used to reopen on
    // every `false` tick and on the 10s poll -- including brief flaps while
    // Wi-Fi was coming back -- which is the "keeps appearing after reconnect"
    // bug. Internet UX now lives on Clock (red banner + toast). AppGuard
    // only dismisses a leftover dialog if one is still on screen.
    _connectivitySub = ConnectivityService.stream.listen((connected) {
      _offlineDebounce?.cancel();
      if (connected) {
        _internetDialogDismissedForOutage = false;
        _dismissInternetDialogIfShowing();
        return;
      }
      _offlineDebounce = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        // Confirm we are still offline after the debounce so reconnect
        // flaps never reopen the Retry popup.
        unawaited(_onConfirmedOffline());
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offlineDebounce?.cancel();
    _connectivitySub?.cancel();
    ConnectivityService.stop();
    _authProvider?.removeListener(_onAuthChanged);
    AppGuard.isPrompting = false;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAll(trigger: 'LIFECYCLE_RESUME');

      _revalidateSession();
    }
  }

  Future<void> _revalidateSession() async {
    final authProvider = _authProvider;
    if (!mounted || authProvider == null) return;
    if (!authProvider.isAuthenticated) return;

    await authProvider.validateSessionOnUnauthorized();
  }

  void _onAuthChanged() {
    if (!mounted || _authProvider == null) return;

    final isAuth = _authProvider!.isAuthenticated;

    if (_lastAuthenticated == true && isAuth == false) {
      router.go('/login');
    }

    _lastAuthenticated = isAuth;
  }

  Future<void> _checkAll({String trigger = 'BACKGROUND'}) async {
    if (!mounted || _dialogOpen || _checkInProgress) return;
    _checkInProgress = true;

    final isFirstLaunch = !_firstCheckDone;
    _firstCheckDone = true;

    try {
      // 0️⃣ Device status -- runs regardless of onboarding state. A device
      // that becomes blocked must always be routed to the blocked screen.
      if (_authProvider?.isAuthenticated == true) {
        try {
          final deviceProvider = context.read<DeviceProvider>();
          if (deviceProvider.isDeviceBlocked) {
            debugPrint('[AppGuard] device blocked, routing to /device_blocked');
            // Navigation-only, no BuildContext needed -- safe to call
            // directly. DeviceApprovalGuard remains the single source of
            // truth for the *alert* (toast/dialog) that accompanies a
            // block; this is purely a defensive route guard so periodic
            // polling can never leave a blocked device sitting on a
            // screen it shouldn't be on.
            router.go('/device_blocked');
            return;
          }
        } catch (e) {
          debugPrint('[AppGuard] DeviceProvider unavailable: $e');
        }
      }

      // 1️⃣ Permissions -- only after the user is on a home screen.
      // First-time install shows EnablePermissionsScreen; that screen
      // owns the OS permission requests. AppGuard used to prompt as soon
      // as login flipped isAuthenticated, which overlays "Permission
      // Required" on the enable-permissions page.
      final isLoggedIn = _authProvider?.isAuthenticated == true;
      final watchPermissions = _shouldWatchPermissions();
      final permissionDecision = watchPermissions ? 'ALLOWED' : 'BLOCKED';

      AppLogger.info(
        '[PERMISSION_CHECK]\n'
        'trigger=$trigger\n'
        'isLoggedIn=$isLoggedIn\n'
        'isFirstLaunch=$isFirstLaunch\n'
        'onboardingPending=${AppGuard.permissionOnboardingPending}\n'
        'route=${_currentMatchedLocation()}\n'
        'decision=$permissionDecision',
      );

      if (permissionDecision == 'BLOCKED') {
        AppLogger.info(
          '[PERMISSION_DIALOG]\n'
          'shown=false\n'
          'reason=${_permissionBlockReason()}',
        );
      } else {
        for (final p in _permissions) {
          if (!_shouldWatchPermissions()) return;
          final status = await PermissionService.status(p).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('[AppGuard] $p status check timed out');
              return PermissionStatus.denied;
            },
          );
          debugPrint('[AppGuard] _checkAll: $p status = $status');

          if (!PermissionService.isAllowed(status)) {
            if (!_shouldWatchPermissions()) return;
            debugPrint('[AppGuard] $p not allowed, showing permission dialog.');
            AppLogger.info(
              '[PERMISSION_DIALOG]\n'
              'shown=true\n'
              'reason=permission_not_allowed:$p:${status.name}',
            );
            await _showPermissionDialog(p, status);
            return;
          }
        }

        final notif = await NotificationService.isEnabled().timeout(
          const Duration(seconds: 5),
          onTimeout: () => true,
        );
        if (!notif) {
          AppLogger.info(
            '[PERMISSION_DIALOG]\n'
            'shown=true\n'
            'reason=notifications_disabled',
          );
          await _showNotificationDialog();
          return;
        }
      }

      final connected = await ConnectivityService.isConnected().timeout(
        const Duration(seconds: 5),
        onTimeout: () => true,
      );
      if (connected) {
        _internetDialogDismissedForOutage = false;
        _dismissInternetDialogIfShowing();
      }
      // Offline: do not open the Retry popup from the periodic poll.
      // ClockScreen shows a red "Internet not available" banner/toast.
    } finally {
      _checkInProgress = false;
    }
  }

  Future<void> _onConfirmedOffline() async {
    final stillOffline = !await ConnectivityService.isConnected();
    if (!stillOffline) {
      _dismissInternetDialogIfShowing();
      return;
    }
    // Leave a stale Retry popup dismissed; never reopen it from here.
    if (_internetDialogOpen) return;
  }

  void _dismissInternetDialogIfShowing() {
    if (!_internetDialogOpen) return;
    final nav = rootNavigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    }
  }

  /// Home routes are the only places AppGuard may nag about revoked
  /// permissions. Splash / onboarding / login / enable-permissions must
  /// never show this dialog -- first-time grant belongs to
  /// EnablePermissionsScreen.
  bool _shouldWatchPermissions() {
    if (AppGuard.permissionOnboardingPending) return false;
    if (_authProvider?.isAuthenticated != true) return false;
    final path = _currentMatchedLocation();
    return path == '/employee_nav' ||
        path == '/manager_nav' ||
        path.startsWith('/manager/');
  }

  String _currentMatchedLocation() {
    try {
      return router.state.matchedLocation;
    } catch (_) {
      return '';
    }
  }

  String _permissionBlockReason() {
    if (AppGuard.permissionOnboardingPending) {
      return 'blocked_by_onboarding_flow';
    }
    if (_authProvider?.isAuthenticated != true) {
      return 'blocked_on_first_launch';
    }
    return 'blocked_off_home_route:${_currentMatchedLocation()}';
  }

  Future<void> _showPermissionDialog(
    AppPermission p,
    PermissionStatus status,
  ) async {
    if (!_shouldWatchPermissions()) return;
    if (_dialogOpen || AppGuard.isPrompting) return;

    // Re-read just before prompting so a grant that landed during the
    // previous dialog / OS sheet is not immediately re-prompted.
    if (PermissionService.isAllowed(status)) return;
    final latest = await PermissionService.status(p);
    if (PermissionService.isAllowed(latest)) return;
    if (!_shouldWatchPermissions()) return;

    _dialogOpen = true;
    AppGuard.isPrompting = true;

    final isPermanent = latest.isPermanentlyDenied || latest.isRestricted;
    var laterPressed = false;
    var allowPressed = false;

    try {
      await _dialog(
        title: "Permission Required",
        message: "${PermissionService.label(p)} permission is turned OFF",
        button: isPermanent ? "Open Settings" : "Allow",
        onPressed: () => allowPressed = true,
        onLater: () => laterPressed = true,
      );
    } finally {
      _dialogOpen = false;
      AppGuard.isPrompting = false;
    }

    if (!mounted) return;

    if (allowPressed) {
      if (isPermanent) {
        await PermissionService.openSettings();
      } else {
        await PermissionService.request(p);
      }
      if (mounted) unawaited(_checkAll(trigger: 'AFTER_ALLOW'));
      return;
    }

    // Later / barrier dismiss: do not immediately re-open the same dialog.
    if (laterPressed) return;
    if (!_shouldWatchPermissions()) return;
    unawaited(_checkAll(trigger: 'AFTER_PERMISSION_DISMISS'));
  }

  Future<void> _showNotificationDialog() async {
    if (!_shouldWatchPermissions()) return;
    if (_dialogOpen || AppGuard.isPrompting) return;

    final enabled = await NotificationService.isEnabled();
    if (enabled) return;
    if (!_shouldWatchPermissions()) return;

    _dialogOpen = true;
    AppGuard.isPrompting = true;

    var laterPressed = false;
    var allowPressed = false;

    try {
      await _dialog(
        title: "Notifications Disabled",
        message: "Enable notifications to continue",
        button: "Enable",
        onPressed: () => allowPressed = true,
        onLater: () => laterPressed = true,
      );
    } finally {
      _dialogOpen = false;
      AppGuard.isPrompting = false;
    }

    if (!mounted) return;

    if (allowPressed) {
      await NotificationService.request();
      if (mounted) unawaited(_checkAll(trigger: 'AFTER_ALLOW'));
      return;
    }

    if (laterPressed) return;
    if (!_shouldWatchPermissions()) return;
    unawaited(_checkAll(trigger: 'AFTER_PERMISSION_DISMISS'));
  }

  /// Shows AppGuard's permission/notification/internet dialogs.
  ///
  /// Routed entirely through `DialogHelper.show` (core/helpers/dialog.dart)
  /// instead of a hand-rolled `showDialog` + manual `Navigator.pop`. That
  /// gives this call the same context-mounted guard and root-navigator
  /// attachment as every other dialog in the app, and removes the one
  /// remaining spot where AppGuard built dialog UI by hand.
  Future<void> _dialog({
    required String title,
    required String message,
    required String button,
    required VoidCallback onPressed,
    VoidCallback? onLater,

    bool recheckAfterLater = true,
  }) async {
    if (!mounted) return;

    // ROOT CAUSE FIX: was `rootNavigatorKey.currentContext`, which is the
    // Navigator widget's OWN context -- an ancestor lookup (which is what
    // showDialog/Navigator.of ultimately need) can never resolve *upward*
    // to a Navigator from that Navigator's own element. Using
    // `rootNavigatorKey.currentState?.overlay?.context` instead resolves
    // to the OverlayState's context, which sits *below* the Navigator in
    // the element tree and therefore has a real Navigator ancestor. See
    // the longer explanation in `DeviceApprovalGuard._safeContext`
    // (monitors/device_approval_guard.dart), which had the same bug.
    final dialogContext = rootNavigatorKey.currentState?.overlay?.context;

    AppLogger.info(
      '[UI_EXECUTION]\n'
      'type=DIALOG\n'
      'contextValid=${dialogContext != null}\n'
      'mounted=${dialogContext?.mounted ?? false}\n'
      'navigatorAvailable=${rootNavigatorKey.currentState != null}\n'
      'source=AppGuard',
    );

    if (dialogContext == null || !dialogContext.mounted) {
      AppLogger.error(
        'AppGuard',
        '_dialog',
        '[ERROR]\ntype=NAVIGATOR_CONTEXT_ERROR\nreason=No Navigator ancestor / overlay not ready\nsource=APP_GUARD_DIALOG',
      );
      return;
    }

    var laterPressed = false;

    await DialogHelper.show(
      context: dialogContext,
      title: title,
      subtitle: message,
      // Original dialog always rendered a "Later" action regardless of
      // whether an `onLater` callback was supplied (permission/notification
      // dialogs pass none, and still let the user dismiss for now) --
      // preserved as-is here.
      cancelButtonText: "Later",
      onCancelTap: () {
        laterPressed = true;
        onLater?.call();
      },
      buttonText: button,
      onButtonTap: onPressed,
      // Original hand-rolled `showDialog` call didn't set this, so it used
      // showDialog's own default (true) -- preserved here rather than
      // silently changing behavior.
      barrierDismissible: true,
    );

    // Recheck is owned by the caller *after* `_dialogOpen` is cleared and
    // after any Allow/request() has finished. Rechecking here was reopening
    // the Retry / permission popup immediately.
    if (!mounted || laterPressed || !recheckAfterLater) return;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
