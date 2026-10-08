import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:shimmer/shimmer.dart';
import 'package:obecno/core/animations/orb_converge.dart';

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
///
/// Set [instagramStyle] for a deep Instagram-like pull: content displaces and
/// an OrbConverge ball plays while loading. When data returns, a short shimmer
/// reveals the updated list.
class ShimmerRefreshIndicator extends StatefulWidget {
  const ShimmerRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.instagramStyle = false,
    this.triggerFraction = 0.48,
    this.refreshIconColor = kPrimaryColor,
    this.orbSize = 200,
    this.revealShimmerDuration = const Duration(milliseconds: 520),
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

  /// Instagram-like deep pull with floating orb + content displace.
  final bool instagramStyle;

  /// Screen-height fraction required to arm refresh when [instagramStyle] is on.
  /// Default ~48% (in the 45–50% range).
  final double triggerFraction;

  /// Particle orb color (Originkit OrbConverge).
  final Color refreshIconColor;

  /// Size of the animated OrbConverge ball during pull/refresh.
  final double orbSize;

  /// How long the post-fetch shimmer runs before showing fresh data
  /// (instagram style only).
  final Duration revealShimmerDuration;

  @override
  State<ShimmerRefreshIndicator> createState() =>
      _ShimmerRefreshIndicatorState();
}

class _ShimmerRefreshIndicatorState extends State<ShimmerRefreshIndicator>
    with TickerProviderStateMixin {
  /// Legacy (non-instagram) finger distance before reload.
  static const double _legacyPullThreshold = 160;

  /// Orb/fetch in progress — list is hidden; only the orb shows.
  bool _refreshing = false;

  /// Data is ready — brief shimmer, then show updated child.
  bool _revealing = false;

  bool _atTop = true;
  double _fingerPull = 0;
  double _pullOffset = 0;
  final GlobalKey _childKey = GlobalKey();

  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;

  bool get _busy => _refreshing || _revealing;

  @override
  void initState() {
    super.initState();
    _snapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
        )..addListener(() {
          final anim = _snapAnimation;
          if (anim == null) return;
          setState(() => _pullOffset = anim.value);
        });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  double _triggerDistance(BuildContext context) {
    if (!widget.instagramStyle) return _legacyPullThreshold;
    final h = MediaQuery.sizeOf(context).height;
    return h * widget.triggerFraction.clamp(0.2, 0.75);
  }

  Future<void> _handleRefresh() async {
    if (_busy) return;
    setState(() {
      _refreshing = true;
      // Hide list under the orb — no need to keep content offset.
      if (widget.instagramStyle) {
        _fingerPull = 0;
        _pullOffset = 0;
      }
    });
    try {
      await widget.onRefresh();
    } finally {
      if (!mounted) return;

      if (widget.instagramStyle) {
        // Data ready → drop orb, shimmer reveal, then show list.
        setState(() {
          _refreshing = false;
          _fingerPull = 0;
          _pullOffset = 0;
          _revealing = true;
        });
        await Future<void>.delayed(widget.revealShimmerDuration);
        if (!mounted) return;
        setState(() => _revealing = false);
      } else {
        setState(() {
          _refreshing = false;
          _fingerPull = 0;
          _pullOffset = 0;
        });
      }
    }
  }

  Future<void> _animateOffsetTo(double target) async {
    _snapController.stop();
    _snapAnimation = Tween<double>(begin: _pullOffset, end: target).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
    );
    await _snapController.forward(from: 0);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_busy || !_atTop) return;

    if (!widget.instagramStyle) {
      if (event.delta.dy <= 0) {
        _fingerPull = 0;
        return;
      }
      _fingerPull += event.delta.dy;
      return;
    }

    // Instagram style: accumulate pull, allow easing back if finger moves up.
    final next = (_fingerPull + event.delta.dy).clamp(0.0, double.infinity);
    if (next == _fingerPull) return;

    final trigger = _triggerDistance(context);
    // Slight resistance so the list eases into the deep pull.
    final visual = next * 0.92;
    setState(() {
      _fingerPull = next;
      _pullOffset = visual.clamp(0.0, trigger * 1.15);
    });
  }

  void _onPointerEnd(PointerEvent event) {
    if (_busy) return;

    if (!widget.instagramStyle) {
      final shouldRefresh = _atTop && _fingerPull >= _legacyPullThreshold;
      _fingerPull = 0;
      if (shouldRefresh) _handleRefresh();
      return;
    }

    final trigger = _triggerDistance(context);
    final shouldRefresh = _atTop && _fingerPull >= trigger;
    _fingerPull = 0;
    if (shouldRefresh) {
      _handleRefresh();
    } else {
      _animateOffsetTo(0);
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (!widget.notificationPredicate(notification)) return false;
    if (notification.depth != 0) return false;

    _atTop =
        notification.metrics.pixels <= notification.metrics.minScrollExtent + 1;
    if (!_atTop) {
      _fingerPull = 0;
      if (widget.instagramStyle && !_busy && _pullOffset != 0) {
        setState(() => _pullOffset = 0);
      }
    }
    return false;
  }

  Widget _buildRefreshIcon(double trigger) {
    final progress = trigger <= 0
        ? 0.0
        : (_pullOffset / trigger).clamp(0.0, 1.0);
    // Orb only during pull / fetch — hide once reveal shimmer starts.
    final show = _refreshing || (!_revealing && _pullOffset > 8);
    if (!show) return const SizedBox.shrink();

    final orb = widget.orbSize;
    final scale = _refreshing ? 1.0 : (0.45 + (0.55 * progress));
    final opacity = _refreshing ? 1.0 : progress.clamp(0.0, 1.0);

    final ball = IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: SizedBox(
            width: orb,
            height: orb,
            child: OrbConverge(
              width: orb,
              height: orb,
              dotColor: widget.refreshIconColor,
              density: 300,
              dotSize: 153,
              speed: 50,
              spinTurns: 0,
              spread: 180,
              turn: 32,
              tilt: -1,
              drag: 0,
              damping: 10,
            ),
          ),
        ),
      ),
    );

    // While loading: list is hidden → center the orb.
    if (_refreshing) {
      return Positioned.fill(child: Center(child: ball));
    }

    final top =
        widget.edgeOffset + (_pullOffset * 0.5) - (orb / 2);
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Center(child: ball),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trigger = _triggerDistance(context);

    // Instagram: shimmer only AFTER data is ready.
    // Legacy: shimmer while the request is in flight.
    final shimmerLoading =
        widget.instagramStyle ? _revealing : _refreshing;

    final content = AppShimmerOverlay(
      isLoading: shimmerLoading,
      baseColor: AppShimmerColors.base,
      highlightColor: AppShimmerColors.highlight,
      period: AppShimmerColors.period,
      child: KeyedSubtree(key: _childKey, child: widget.child),
    );

    final body = widget.instagramStyle
        ? Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Hide all list data while the orb is loading.
              Opacity(
                opacity: _refreshing ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _refreshing,
                  child: Transform.translate(
                    offset: Offset(0, _refreshing ? 0 : _pullOffset),
                    child: content,
                  ),
                ),
              ),
              _buildRefreshIcon(trigger),
            ],
          )
        : content;

    return Listener(
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: body,
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
