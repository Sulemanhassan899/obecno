import 'package:Obecno/screens/launch/onboarding/onboarding.dart';
import 'package:Obecno/screens/launch/splash/splash.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 🔥 GLOBAL TRANSITION BUILDER
CustomTransitionPage _buildPage({required Widget child}) {
  return CustomTransitionPage(
    transitionDuration: const Duration(milliseconds: 600),

    child: child,

    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      /// Fade
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeInOut);

      /// Slight upward motion (premium feel)
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.08), // 👈 subtle bottom → up
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}
