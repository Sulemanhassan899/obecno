import 'package:flutter/material.dart';

/// Loading indicators built entirely on Material SDK widgets.
///
/// Pure Flutter SDK implementation — no external animation packages.
class LoadingAnimations {
  LoadingAnimations._();

  /// Centered circular progress indicator.
  static Widget spinner({Color? color, double strokeWidth = 3}) {
    return Center(
      child: CircularProgressIndicator(color: color, strokeWidth: strokeWidth),
    );
  }

  /// Small inline spinner sized for buttons / list tiles.
  static Widget small({Color? color, double size = 18, double strokeWidth = 2}) {
    return SizedBox(
      height: size,
      width: size,
      child: CircularProgressIndicator(color: color, strokeWidth: strokeWidth),
    );
  }

  /// Simple pulse "shimmer-like" placeholder box, built with AnimatedOpacity
  /// looped by a StatefulWidget — no shimmer package required.
  static Widget pulseBox({
    double width = double.infinity,
    double height = 16,
    Color color = const Color(0xFFE0E0E0),
    BorderRadius? borderRadius,
  }) {
    return PulseBox(width: width, height: height, color: color, borderRadius: borderRadius);
  }
}

class PulseBox extends StatefulWidget {
  final double width;
  final double height;
  final Color color;
  final BorderRadius? borderRadius;

  const PulseBox({
    super.key,
    required this.width,
    required this.height,
    required this.color,
    this.borderRadius,
  });

  @override
  State<PulseBox> createState() => _PulseBoxState();
}

class _PulseBoxState extends State<PulseBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity =
      Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: widget.borderRadius ?? BorderRadius.circular(6),
            ),
          ),
        );
      },
    );
  }
}
