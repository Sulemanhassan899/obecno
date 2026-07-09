import 'dart:async';
import 'package:Obecno/core/services/connectivity_service.dart';
import 'package:Obecno/core/services/notification_helper.dart';
import 'package:Obecno/core/services/permission_helper.dart';
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAll();
    }
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
