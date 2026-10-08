import 'package:flutter/material.dart';

class WaterRippleEffect extends StatefulWidget {
  const WaterRippleEffect({
    super.key,
    required this.color,
    this.size = 200,
    this.rippleCount = 3,
    this.minScale = 0.3, // ✅ new: how small the ripple starts (near center)
    this.maxScale = 1.6, // ✅ must be > 1 to actually grow outward
    this.opacityFactor = 0.4,
    this.duration = const Duration(milliseconds: 2000),
    this.child,
    this.play = true,
  });

  final double size;
  final Color color;
  final int rippleCount;
  final double minScale; // ✅ new
  final double maxScale;
  final double opacityFactor;
  final Duration duration;
  final Widget? child;
  final bool play;

  @override
  State<WaterRippleEffect> createState() => _WaterRippleEffectState();
}

class _WaterRippleEffectState extends State<WaterRippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.play) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant WaterRippleEffect oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }

    if (oldWidget.play != widget.play) {
      if (widget.play) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _RipplePainter(
                progress: _controller.value,
                color: widget.color,
                rippleCount: widget.rippleCount,
                minScale: widget.minScale,
                maxScale: widget.maxScale,
                opacityFactor: widget.opacityFactor,
              ),
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.progress,
    required this.color,
    required this.rippleCount,
    required this.minScale,
    required this.maxScale,
    required this.opacityFactor,
  });

  final double progress;
  final Color color;
  final int rippleCount;
  final double minScale;
  final double maxScale;
  final double opacityFactor;

  @override
  void paint(Canvas canvas, Size size) {
    if (rippleCount <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    for (var index = 0; index < rippleCount; index++) {
      final delay = index / rippleCount;
      final t = (progress + delay) % 1;
      final scale = minScale + (maxScale - minScale) * t;
      final opacity = ((1 - t) * opacityFactor).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        radius * scale,
        Paint()..color = color.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.rippleCount != rippleCount ||
        oldDelegate.minScale != minScale ||
        oldDelegate.maxScale != maxScale ||
        oldDelegate.opacityFactor != opacityFactor;
  }
}
