

import 'dart:async';
import 'package:Obecno/core/services/connectivity_service.dart';
import 'package:Obecno/core/services/notification_helper.dart';
import 'package:Obecno/core/services/permission_helper.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AppGuard extends StatefulWidget {
  final Widget child;

  const AppGuard({super.key, required this.child});

  @override
  State<AppGuard> createState() => _AppGuardState();
}

class _AppGuardState extends State<AppGuard> with WidgetsBindingObserver {
  Timer? _timer;
  bool _dialogOpen = false;

  // FIXED (missing logic): nothing was watching AuthProvider for a session
  // dying mid-app-use (401/419 interceptor, or app-resume revalidation
  // below), so a user could be left stranded on an authenticated screen
  // with no valid session and no way back to Login except a manual
  // restart. `_authProvider`/`_lastAuthenticated` back that watcher.
  AuthProvider? _authProvider;
  bool? _lastAuthenticated;

  final List<AppPermission> _permissions = [
    AppPermission.location,
    AppPermission.motion,
    AppPermission.notification,
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    ConnectivityService.start();

    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkAll());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAll();

      // FIXED (missing logic): subscribe to AuthProvider so a session
      // invalidated from anywhere (401/419 -> AuthProvider.
      // validateSessionOnUnauthorized, or an explicit logout()) is
      // automatically followed by a redirect back to Splash instead of
      // leaving the user stuck on a now-unauthenticated screen.
      _authProvider = context.read<AuthProvider>();
      _lastAuthenticated = _authProvider?.isAuthenticated;
      _authProvider?.addListener(_onAuthChanged);
    });

    // Listen real-time internet changes
    ConnectivityService.stream.listen((connected) {
      if (!connected) {
        _showInternetDialog();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    ConnectivityService.stop();
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAll();

      // FIXED (missing logic, spec: "Trigger /api/auth/me ... App resume"):
      // previously only app start (Splash) and a live 401/419 ever
      // re-checked the session -- a session that expired while the app
      // was backgrounded was never caught until some other API call
      // happened to fail.
      _revalidateSession();
    }
  }

  /// Re-validates the session against `GET /api/auth/me` on app resume.
  /// Only runs if the user currently looks authenticated -- no point
  /// hitting `/me` for someone sitting on Login/Onboarding. Never
  /// navigates itself (per spec); [_onAuthChanged] reacts to the
  /// resulting state change and does the actual redirect.
  Future<void> _revalidateSession() async {
    final authProvider = _authProvider;
    if (!mounted || authProvider == null) return;
    if (!authProvider.isAuthenticated) return;

    await authProvider.validateSessionOnUnauthorized();
  }

  /// Fires whenever [AuthProvider] notifies. Only reacts to an
  /// authenticated -> unauthenticated transition (expired cookie
  /// confirmed via `/api/auth/me`, or an explicit logout) that happens
  /// while the user is elsewhere in the app -- routes back through
  /// Splash, which re-runs the single centralized routing decision
  /// (Onboarding vs Login vs Dashboard) instead of leaving a dead screen
  /// on display.
  ///
  /// Uses the global `router` singleton (not `context.go`) because this
  /// widget's own BuildContext sits *above* the Router/Navigator that
  /// `MaterialApp.router`'s `builder` wraps, so `GoRouter.of(context)`
  /// isn't reachable from here.
  void _onAuthChanged() {
    if (!mounted || _authProvider == null) return;

    final isAuth = _authProvider!.isAuthenticated;

    if (_lastAuthenticated == true && isAuth == false) {
      // FIXED: previously routed to '/' (Splash), which re-runs the
      // whole bootstrap (permissions/connectivity checks, etc.) just to
      // land back on Login anyway. Per spec, logout / an invalidated
      // session should go straight to the email login screen -- Splash
      // and Onboarding are first-run-only concerns, not part of the
      // logout flow.
      router.go('/login');
    }

    _lastAuthenticated = isAuth;
  }

  Future<void> _checkAll() async {
    if (!mounted || _dialogOpen) return;

    // 1️⃣ Permissions
    for (final p in _permissions) {
      final status = await PermissionService.status(p);

      if (!PermissionService.isAllowed(status)) {
        await _showPermissionDialog(p, status);
        return;
      }
    }

    // 2️⃣ Notifications
    final notif = await NotificationService.isEnabled();
    if (!notif) {
      await _showNotificationDialog();
      return;
    }

    // 3️⃣ Internet
    final connected = await ConnectivityService.isConnected();
    if (!connected) {
      await _showInternetDialog();
      return;
    }
  }

  Future<void> _showPermissionDialog(
    AppPermission p,
    PermissionStatus status,
  ) async {
    _dialogOpen = true;

    final isPermanent = status.isPermanentlyDenied || status.isRestricted;

    await _dialog(
      title: "Permission Required",
      message: "$p permission is turned OFF",
      button: isPermanent ? "Open Settings" : "Allow",
      onPressed: () async {
        if (isPermanent) {
          await PermissionService.openSettings();
        } else {
          await PermissionService.request(p);
        }
      },
    );

    _dialogOpen = false;
  }

  Future<void> _showNotificationDialog() async {
    _dialogOpen = true;

    await _dialog(
      title: "Notifications Disabled",
      message: "Enable notifications to continue",
      button: "Enable",
      onPressed: () async {
        await NotificationService.request();
      },
    );

    _dialogOpen = false;
  }

  Future<void> _showInternetDialog() async {
    if (_dialogOpen) return;

    _dialogOpen = true;

    await _dialog(
      title: "No Internet",
      message: "Check your connection",
      button: "Retry",
      onPressed: () {},
    );

    _dialogOpen = false;
  }

  Future<void> _dialog({
    required String title,
    required String message,
    required String button,
    required VoidCallback onPressed,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onPressed();
            },
            child: Text(button),
          ),
        ],
      ),
    );

    if (mounted) _checkAll();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
