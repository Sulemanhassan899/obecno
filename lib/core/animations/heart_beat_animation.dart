
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ ADDED

class HeartbeatRippleLayer extends StatefulWidget {
  const HeartbeatRippleLayer({
    super.key,
    required this.color,
    this.size = 560,
    this.rippleCount = 2,
    this.maxScale = 1.15,
    this.opacityFactor = 1,
  });

  final double size;
  final Color color;

  /// number of ripple rings
  final int rippleCount;

  /// how far ripple expands (keep small!)
  final double maxScale;

  /// overall glow strength
  final double opacityFactor;

  @override
  State<HeartbeatRippleLayer> createState() => _HeartbeatRippleLayerState();
}

class _HeartbeatRippleLayerState extends State<HeartbeatRippleLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  double _lastBeatPhase = 0; // ✅ ADDED

  @override
  void initState() {
    super.initState();

    /// One controller = perfectly synced system
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _controller.addListener(() {
      final t = _controller.value;

      /// Detect LUB (~0.1) and DUB (~0.35)
      if (_lastBeatPhase < 0.1 && t >= 0.1) {
        HapticFeedback.lightImpact(); // ✅ LUB
      }

      if (_lastBeatPhase < 0.35 && t >= 0.35) {
        HapticFeedback.lightImpact(); // ✅ DUB
      }

      _lastBeatPhase = t;
    }); // ✅ ADDED
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// ❤️ Double beat curve (lub-dub)
  double _heartbeatCurve(double t) {
    if (t < 0.15) {
      return Curves.easeOut.transform(t / 0.15); // LUB
    } else if (t < 0.3) {
      return 1 - (Curves.easeIn.transform((t - 0.15) / 0.15) * 0.4);
    } else if (t < 0.45) {
      return 0.6 + (Curves.easeOut.transform((t - 0.3) / 0.15) * 0.4); // DUB
    } else {
      return 0.6 * (1 - ((t - 0.45) / 0.55)); // relax
    }
  }

  Widget _buildRipple(int index) {
    final delay = index / widget.rippleCount;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        double t = (_controller.value + delay) % 1;

        /// Sync ripple with heartbeat energy
        final beat = _heartbeatCurve(_controller.value);

        final scale = 1.0 + (t * (widget.maxScale - 1.0)) * (0.7 + beat * 0.3);

        final opacity =
            (1 - Curves.easeOut.transform(t)) *
            widget.opacityFactor *
            (0.6 + beat * 0.4);

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.color.withOpacity(0.25),
                    widget.color.withOpacity(0.25),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenterPulse() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final beat = _heartbeatCurve(_controller.value);

        /// subtle scaling
        final scale = 0.96 + (beat * 0.08);

        return Transform.scale(scale: scale, child: child);
      },
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            width: widget.size * 0.72,
            height: widget.size * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.color,
                  widget.color.withOpacity(0.8),
                  widget.color.withOpacity(0.6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              /// 🔵 Ripple layers
              ...List.generate(widget.rippleCount, _buildRipple),

              /// 🟢 Soft glow aura (blur layer)
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    color: widget.color.withOpacity(0.05),
                  ),
                ),
              ),

              /// ❤️ Center pulse
              _buildCenterPulse(),
            ],
          ),
        ),
      ),
    );
  }
}