import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// ===============================================================
/// 🔥 ADVANCED SHIMMER SYSTEM (PRODUCTION READY)
/// ===============================================================
///
/// Supports:
/// - Box shimmer
/// - Overlay shimmer (on real UI)
/// - Circle / rectangle shapes
/// - Custom gradients
/// - Animation control (speed, direction, loop)
/// - Enable/disable shimmer dynamically
///
/// ===============================================================

class AppShimmer extends StatelessWidget {
  final bool isLoading;

  /// Optional child (used when NOT loading)
  final Widget? child;

  /// Size (for skeleton mode)
  final double? height;
  final double? width;

  /// Shape control
  final BoxShape shape;
  final BorderRadius? borderRadius;

  /// Colors
  final Color baseColor;
  final Color highlightColor;

  /// Animation controls
  final Duration period;
  final ShimmerDirection direction;
  final int loop;
  final bool enabled;

  /// Optional full gradient override
  final Gradient? gradient;

  const AppShimmer({
    super.key,
    required this.isLoading,
    this.child,
    this.height,
    this.width,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
    this.period = const Duration(milliseconds: 1200),
    this.direction = ShimmerDirection.ltr,
    this.loop = 0,
    this.enabled = true,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    /// If not loading → return actual widget
    if (!isLoading) return child ?? const SizedBox();

    final shimmerBox = Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: baseColor,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : borderRadius ?? BorderRadius.zero,
      ),
    );

    return Shimmer(
      child: shimmerBox,
      gradient: gradient ?? _defaultGradient,
      period: period,
      direction: direction,
      loop: loop,
      enabled: enabled,
    );
  }

  /// Default smooth gradient
  Gradient get _defaultGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          baseColor,
          highlightColor,
          baseColor,
        ],
        stops: const [0.25, 0.5, 0.75],
      );
}

/// ===============================================================
/// 🔁 OVERLAY SHIMMER (FOR REAL UI SKELETONS)
/// ===============================================================

class AppShimmerOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  final Color baseColor;
  final Color highlightColor;

  final Duration period;
  final ShimmerDirection direction;
  final int loop;
  final bool enabled;

  final Gradient? gradient;

  const AppShimmerOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
    this.period = const Duration(milliseconds: 1200),
    this.direction = ShimmerDirection.ltr,
    this.loop = 0,
    this.enabled = true,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;

    return Shimmer(
      child: child,
      gradient: gradient ?? _defaultGradient,
      period: period,
      direction: direction,
      loop: loop,
      enabled: enabled,
    );
  }

  Gradient get _defaultGradient => LinearGradient(
        colors: [baseColor, highlightColor, baseColor],
        stops: const [0.25, 0.5, 0.75],
      );
}

/// ===============================================================
/// 🎯 PRESET HELPERS (OPTIONAL USAGE)
/// ===============================================================

class ShimmerPresets {
  /// Avatar shimmer (circle)
  static Widget avatar({
    required bool isLoading,
    double size = 50,
  }) {
    return AppShimmer(
      isLoading: isLoading,
      height: size,
      width: size,
      shape: BoxShape.circle,
    );
  }

  /// Text line shimmer
  static Widget text({
    required bool isLoading,
    double width = 120,
    double height = 14,
  }) {
    return AppShimmer(
      isLoading: isLoading,
      height: height,
      width: width,
      borderRadius: BorderRadius.circular(4),
    );
  }

  /// Card shimmer
  static Widget card({
    required bool isLoading,
    double height = 100,
  }) {
    return AppShimmer(
      isLoading: isLoading,
      height: height,
      width: double.infinity,
      borderRadius: BorderRadius.circular(12),
    );
  }
}