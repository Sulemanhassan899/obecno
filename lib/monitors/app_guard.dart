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
  bool _checkInProgress = false;

  bool _internetDialogDismissedForOutage = false;

  AuthProvider? _authProvider;
  bool? _lastAuthenticated;

  final List<AppPermission> _permissions = [
    AppPermission.location,
    AppPermission.motion,
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    ConnectivityService.start();

    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkAll());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAll();

      _authProvider = context.read<AuthProvider>();
      _lastAuthenticated = _authProvider?.isAuthenticated;
      _authProvider?.addListener(_onAuthChanged);
    });

    // Listen real-time internet changes
    ConnectivityService.stream.listen((connected) {
      if (!connected) {
        if (_internetDialogDismissedForOutage) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showInternetDialog();
        });
      } else {
        _internetDialogDismissedForOutage = false;
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

  Future<void> _checkAll() async {
    if (!mounted || _dialogOpen || _checkInProgress) return;
    _checkInProgress = true;

    try {
      // 1️⃣ Permissions
      for (final p in _permissions) {
        final status = await PermissionService.status(p).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('[AppGuard] $p status check timed out');
            return PermissionStatus.denied;
          },
        );
        debugPrint('[AppGuard] _checkAll: $p status = $status');

        if (!PermissionService.isAllowed(status)) {
          debugPrint('[AppGuard] $p not allowed, showing permission dialog.');
          await _showPermissionDialog(p, status);
          return;
        }
      }

      final notif = await NotificationService.isEnabled().timeout(
        const Duration(seconds: 5),
        onTimeout: () => true,
      );
      if (!notif) {
        await _showNotificationDialog();
        return;
      }

      final connected = await ConnectivityService.isConnected().timeout(
        const Duration(seconds: 5),
        onTimeout: () => true,
      );
      if (!connected) {
        if (_internetDialogDismissedForOutage) return;
        await _showInternetDialog();
        return;
      }
      _internetDialogDismissedForOutage = false;
    } finally {
      _checkInProgress = false;
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
      message: "${PermissionService.label(p)} permission is turned OFF",
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

      onLater: () => _internetDialogDismissedForOutage = true,
      recheckAfterLater: false,
    );

    _dialogOpen = false;
  }

  Future<void> _dialog({
    required String title,
    required String message,
    required String button,
    required VoidCallback onPressed,
    VoidCallback? onLater,

    bool recheckAfterLater = true,
  }) async {
    if (!mounted) return;

    var laterPressed = false;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              laterPressed = true;
              Navigator.pop(context);
              onLater?.call();
            },
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

    if (mounted && (!laterPressed || recheckAfterLater)) _checkAll();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}