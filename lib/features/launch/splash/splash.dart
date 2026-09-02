import 'dart:async';

import 'package:obecno/core/services/permission_helper.dart';
import 'package:obecno/core/services/token_service.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/employee_module/more/providers/device_provider.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/monitors/app_guard.dart';
import 'package:obecno/core/monitors/device_approval_guard.dart';
import 'package:obecno/features/employee_module/routes/app_routes.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _navigated = false;
  Timer? _failSafe;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Physical-device fail-safe: never stay on splash if storage / session
    // / permission platform channels hang (common with secure storage).
    _failSafe = Timer(const Duration(seconds: 5), () {
      debugPrint('[SplashScreen] fail-safe fired');
      _go(_fallbackPath());
    });

    unawaited(_bootstrap());
  }

  String _fallbackPath() {
    try {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        return auth.homeTarget == AuthHomeTarget.manager
            ? '/manager_nav'
            : '/employee_nav';
      }
    } catch (_) {}
    return '/onboarding';
  }

  void _go(String path) {
    if (_navigated) return;
    _navigated = true;
    _failSafe?.cancel();
    if (!mounted) return;
    try {
      router.go(path);
    } catch (e) {
      debugPrint('[SplashScreen] router.go($path) failed: $e');
    }
  }

  Future<void> _bootstrap() async {
    final startTime = DateTime.now();
    var dest = '/onboarding';

    try {
      dest = await _resolveDestination().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('[SplashScreen] resolve timed out');
          return _fallbackPath();
        },
      );
    } catch (e, st) {
      debugPrint('[SplashScreen] bootstrap failed: $e\n$st');
      dest = _fallbackPath();
    }

    final remaining =
        const Duration(seconds: 2) - DateTime.now().difference(startTime);
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    _go(dest);
  }

  Future<String> _resolveDestination() async {
    final authProvider = context.read<AuthProvider>();
    final tokenService = TokenService();

    final onboardingCompleted = await tokenService.isOnboardingCompleted
        .timeout(const Duration(seconds: 2), onTimeout: () => false);

    if (!onboardingCompleted) return '/onboarding';

    var loggedIn = false;
    try {
      loggedIn = await authProvider.checkSession().timeout(
        const Duration(seconds: 3),
        onTimeout: () => authProvider.isAuthenticated,
      );
    } catch (e) {
      debugPrint('[SplashScreen] checkSession failed: $e');
      loggedIn = authProvider.isAuthenticated;
    }

    if (!loggedIn) return '/login';

    var permissionsAllowed = false;
    try {
      permissionsAllowed = await PermissionService.areCriticalPermissionsAllowed()
          .timeout(const Duration(seconds: 2), onTimeout: () => true);
    } catch (e) {
      debugPrint('[SplashScreen] permission check failed: $e');
      permissionsAllowed = true;
    }

    if (!permissionsAllowed) {
      AppGuard.permissionOnboardingPending = true;
      return '/enable_permissions';
    }

    try {
      final deviceProvider = context.read<DeviceProvider>();
      final userId = authProvider.user?.id;
      unawaited(() async {
        DeviceApprovalGuard.reset();
        await deviceProvider.registerOnLogin();
        await deviceProvider.checkDeviceStatus(
          null,
          loginMessage: false,
          source: 'APP_START',
          userId: userId,
          isFirstLogin: false,
        );
      }());
    } catch (e) {
      debugPrint('[SplashScreen] DeviceProvider unavailable: $e');
    }

    return authProvider.homeTarget == AuthHomeTarget.manager
        ? '/manager_nav'
        : '/employee_nav';
  }

  @override
  void dispose() {
    _failSafe?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CommonImageView(
                  imagePath: Assets.imagesObecnoMainlogoName,
                  height: 155,
                  width: 300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
