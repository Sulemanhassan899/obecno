import 'package:flutter/material.dart';

/// Entry / scroll-reveal animations used when a widget first appears
/// on screen (cards, images, dropdowns, etc).
///
/// Pure Flutter SDK implementation — no external animation packages.
class ScrollAnimations {
  ScrollAnimations._();

  /// Fades in while sliding up from [begin].
  static Widget fadeSlide({
    required Widget child,
    Duration duration = const Duration(milliseconds: 400),
    Offset begin = const Offset(0, 0.2),
    double travel = 40,
    Curve curve = Curves.easeOut,
  }) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: begin, end: Offset.zero),
      duration: duration,
      curve: curve,
      builder: (context, value, builtChild) {
        return Transform.translate(
          offset: Offset(0, value.dy * travel),
          child: Opacity(opacity: 1 - value.dy.abs(), child: builtChild),
        );
      },
      child: child,
    );
  }

  /// Fades in while sliding in horizontally — handy for dropdowns / chips.
  static Widget fadeSlideHorizontal({
    required Widget child,
    Duration duration = const Duration(milliseconds: 400),
    double travel = 20,
    Curve curve = Curves.easeOut,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, value, builtChild) {
        return Transform.translate(
          offset: Offset(travel * (1 - value), 0),
          child: Opacity(opacity: value, child: builtChild),
        );
      },
      child: child,
    );
  }

  /// Fade + slight scale-in, used for images and media.
  static Widget fadeScale({
    required Widget child,
    Duration duration = const Duration(milliseconds: 400),
    double beginScale = 0.96,
    Curve curve = Curves.easeOut,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, builtChild) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: beginScale + ((1 - beginScale) * value),
            child: builtChild,
          ),
        );
      },
      child: child,
    );
  }
}
