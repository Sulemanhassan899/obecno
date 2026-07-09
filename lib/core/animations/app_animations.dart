import 'package:flutter/material.dart';

import 'button_animations.dart';
import 'loading_animations.dart';
import 'scroll_animations.dart';

export 'button_animations.dart';
export 'loading_animations.dart';
export 'scroll_animations.dart';

/// Single entry point that aggregates every animation module.
///
/// Kept as a thin façade over [ButtonAnimations], [ListAnimations],
/// [LoadingAnimations] and [ScrollAnimations] so existing call sites using
/// `AppAnimations.press(...)`, `AppAnimations.fadeSlide(...)`,
/// `AppAnimations.listItem(...)` and `AppAnimations.loading(...)` keep
/// working unchanged after the split into dedicated files.
class AppAnimations {
  AppAnimations._();

  /// Button press (delegates to [ButtonAnimations.press]).
  static Widget press({
    required Widget child,
    required VoidCallback? onTap,
    Duration duration = const Duration(milliseconds: 120),
    bool haptic = true,
  }) {
    return ButtonAnimations.press(child: child, onTap: onTap, haptic: haptic);
  }

  /// Fade + slide entry animation (delegates to [ScrollAnimations.fadeSlide]).
  static Widget fadeSlide({
    required Widget child,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return ScrollAnimations.fadeSlide(child: child, duration: duration);
  }


  /// Loading spinner (delegates to [LoadingAnimations.spinner]).
  static Widget loading({Color? color}) {
    return LoadingAnimations.spinner(color: color);
  }
}
