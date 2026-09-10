import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Neutral grey palette used by every shimmer in the app. Never green.
abstract final class AppShimmerColors {
  static const Color base = Color(0xFFE0E0E0);
  static const Color highlight = Color(0xFFF5F5F5);
  static const Duration period = Duration(milliseconds: 600);
}

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
    this.baseColor = AppShimmerColors.base,
    this.highlightColor = AppShimmerColors.highlight,
    this.period = AppShimmerColors.period,
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
        borderRadius: shape == BoxShape.circle
            ? null
            : borderRadius ?? BorderRadius.zero,
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
    colors: [baseColor, highlightColor, baseColor],
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
    this.baseColor = AppShimmerColors.base,
    this.highlightColor = AppShimmerColors.highlight,
    this.period = AppShimmerColors.period,
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

/// Drop-in for [CircularProgressIndicator]. Same size, shimmer instead of a spinner.
class ShimmerProgress extends StatelessWidget {
  const ShimmerProgress({super.key, this.color, this.strokeWidth = 4.0});

  // Kept so call sites can pass the same args as CircularProgressIndicator.
  // ignore: unused_field
  final Color? color;
  // ignore: unused_field
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return const FittedBox(
      child: AppShimmer(
        isLoading: true,
        height: 36,
        width: 36,
        shape: BoxShape.circle,
        baseColor: AppShimmerColors.base,
        highlightColor: AppShimmerColors.highlight,
      ),
    );
  }
}

/// Drop-in for [RefreshIndicator]. Same pull-to-refresh, shimmer instead of the circle.
class ShimmerRefreshIndicator extends StatefulWidget {
  const ShimmerRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  // Kept so call sites can pass the same args as RefreshIndicator.
  // ignore: unused_field
  final Color? color;
  // ignore: unused_field
  final double displacement;
  // ignore: unused_field
  final double edgeOffset;
  final ScrollNotificationPredicate notificationPredicate;

  @override
  State<ShimmerRefreshIndicator> createState() =>
      _ShimmerRefreshIndicatorState();
}

class _ShimmerRefreshIndicatorState extends State<ShimmerRefreshIndicator> {
  /// Finger must move this far *down* while already at the top.
  /// Rubber-band / a normal scroll into the list must not reload.
  static const double _pullThreshold = 160;

  bool _refreshing = false;
  bool _atTop = true;
  double _fingerPull = 0;
  final GlobalKey _childKey = GlobalKey();

  Future<void> _handleRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_refreshing || !_atTop) return;
    // Finger up → scrolling the list. Finger down → possible pull-to-refresh.
    if (event.delta.dy <= 0) {
      _fingerPull = 0;
      return;
    }
    _fingerPull += event.delta.dy;
  }

  void _onPointerEnd(PointerEvent event) {
    final shouldRefresh =
        !_refreshing && _atTop && _fingerPull >= _pullThreshold;
    _fingerPull = 0;
    if (shouldRefresh) _handleRefresh();
  }

  bool _onScroll(ScrollNotification notification) {
    if (!widget.notificationPredicate(notification)) return false;
    if (notification.depth != 0) return false;

    _atTop =
        notification.metrics.pixels <= notification.metrics.minScrollExtent + 1;
    if (!_atTop) _fingerPull = 0;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: AppShimmerOverlay(
          isLoading: _refreshing,
          baseColor: AppShimmerColors.base,
          highlightColor: AppShimmerColors.highlight,
          period: AppShimmerColors.period,
          child: KeyedSubtree(
            key: _childKey,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class ShimmerPresets {
  /// Avatar shimmer (circle)
  static Widget avatar({required bool isLoading, double size = 50}) {
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
  static Widget card({required bool isLoading, double height = 100}) {
    return AppShimmer(
      isLoading: isLoading,
      height: height,
      width: double.infinity,
      borderRadius: BorderRadius.circular(12),
    );
  }
}
