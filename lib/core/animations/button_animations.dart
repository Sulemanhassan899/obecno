import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// ─────────────────────────────────────────────
/// Reusable Button Animation Wrapper
/// ─────────────────────────────────────────────
class ButtonAnimations {
  ButtonAnimations._();

  static Widget press({
    required Widget child,
    required VoidCallback? onTap,
    double pressedScale = 0.90,
    bool haptic = true,
  }) {
    return BouncePress(
      scaleFactor: pressedScale,
      onTap: () {
        if (haptic) HapticFeedback.mediumImpact();
        onTap?.call();
      },
      child: child,
    );
  }
}

/// ─────────────────────────────────────────────
/// 🔥 High-Performance Bounce Press Animation
/// ─────────────────────────────────────────────
class BouncePress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final bool haptic;
  final bool lock;

  const BouncePress({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.90,
    this.haptic = true,
    this.lock = false,
  });

  @override
  State<BouncePress> createState() => _BouncePressState();
}

class _BouncePressState extends State<BouncePress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  bool _locked = false;

  /// 🔽 Press → softer, deeper feel
  SpringDescription get _springPress =>
      const SpringDescription(mass: 1, stiffness: 220, damping: 10);

  /// 🔼 Release → fast snap-back
  SpringDescription get _springRelease =>
      const SpringDescription(mass: 1, stiffness: 500, damping: 18);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController.unbounded(vsync: this)..value = 1.0;
  }

  Future<void> _runSpring({
    required double target,
    required SpringDescription spring,
    double velocity = 0,
  }) async {
    _controller.stop();

    final simulation = SpringSimulation(
      spring,
      _controller.value,
      target,
      velocity,
      tolerance: const Tolerance(velocity: 0.01, distance: 0.01),
    );

    await _controller.animateWith(simulation);
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.lock && _locked) return;

    _runSpring(target: widget.scaleFactor, spring: _springPress);

    if (widget.haptic) {
      HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.lock && _locked) return;

    _locked = true;

    _runSpring(
      target: 1.0,
      spring: _springRelease,
      velocity: 10, // 🔥 instant snap
    );

    widget.onTap?.call();

    Future.delayed(const Duration(milliseconds: 120), () {
      _locked = false;
    });
  }

  void _onCancel() {
    _runSpring(target: 1.0, spring: _springRelease, velocity: 6);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _controller.value.clamp(0.85, 1.05),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
