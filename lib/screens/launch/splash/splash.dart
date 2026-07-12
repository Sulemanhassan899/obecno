import 'dart:async';

import 'package:Obecno/core/services/permission_helper.dart';
import 'package:Obecno/core/services/token_service.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/widgets/text_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void initState() {
    super.initState();

    /// Animation Controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    /// Fade Animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    /// Scale Animation (slight zoom-in)
    _scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final startTime = DateTime.now();

    final authProvider = context.read<AuthProvider>();
    
    // Check onboarding completion
    final tokenService = TokenService();
    final onboardingCompleted = await tokenService.isOnboardingCompleted;

    bool loggedIn = false;
    bool permissionsAllowed = false;

    if (onboardingCompleted) {
      // Check session
      loggedIn = await authProvider.checkSession();
      if (loggedIn) {
        // Check if permissions allowed
        permissionsAllowed = await PermissionService.areAllPermissionsAllowed();
      }
    }

    // Ensure we wait at least 4 seconds for splash animation
    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(seconds: 4) - elapsed;
    if (remaining.inMilliseconds > 0) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;

    if (!onboardingCompleted) {
      context.go('/onboarding');
    } else if (!loggedIn) {
      context.go('/login');
    } else if (permissionsAllowed) {
      context.go('/employee_nav');
    } else {
      context.go('/enable_permissions');
    }
  }

  @override
  void dispose() {
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
