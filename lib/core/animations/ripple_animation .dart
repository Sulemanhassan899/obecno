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

  double _calcOpacity(double progress) {
    return (1 - progress) * widget.opacityFactor;
  }
  double _calcScale(double progress) {
    return widget.minScale + (widget.maxScale - widget.minScale) * progress;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(widget.rippleCount, (index) {
            final double delay = index / widget.rippleCount;

            return AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                double progress = (_controller.value + delay) % 1;

                return Transform.scale(
                  scale: _calcScale(progress),
                  child: Opacity(
                    opacity: _calcOpacity(progress),
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color,
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}
