import 'dart:async';
import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/core/constants/text_styles.dart';

/// ===============================
/// 🔥 ADVANCED TOP TOAST SYSTEM
/// ===============================
class SnackbarHelper {
  SnackbarHelper._();

  static OverlayEntry? _overlayEntry;

  static void showTopToast(
    BuildContext context, {
    required String message,

    /// UI
    String? imagePath,
    Color backgroundColor = const Color(0xFF2F3136),
    Color textColor = kWhite,

    /// Layout
    double radius = 30,
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 16),

    /// Position
    double topOffset = 12,

    /// Animation
    Duration animationDuration = const Duration(milliseconds: 800),
    Curve animationCurve = Curves.easeOutCubic,

    /// Visibility
    Duration duration = const Duration(seconds: 4),

    /// Shadow
    List<BoxShadow>? boxShadow,

    /// Text Style
    FontWeight fontWeight = FontWeight.w500,

    /// Dismiss control
    bool dismissOnTap = true,
    bool swipeToDismiss = true,
    double swipeVelocityThreshold = 600,
  }) {
    _removeCurrent();

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => _TopToastWidget(
        message: message,
        imagePath: imagePath,
        backgroundColor: backgroundColor,
        textColor: textColor,
        radius: radius,
        padding: padding,
        margin: margin,
        topOffset: topOffset,
        animationDuration: animationDuration,
        animationCurve: animationCurve,
        boxShadow: boxShadow,
        fontWeight: fontWeight,
        dismissOnTap: dismissOnTap,
        swipeToDismiss: swipeToDismiss,
        swipeVelocityThreshold: swipeVelocityThreshold,
      ),
    );

    overlay.insert(_overlayEntry!);

    /// AUTO REMOVE (SAFE)
    Future.delayed(duration, () {
      _TopToastWidgetState.dismissCurrent();
    });
  }

  static void _removeCurrent() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

/// ===============================
/// 🔥 TOAST UI
/// ===============================
class _TopToastWidget extends StatefulWidget {
  final String message;
  final String? imagePath;
  final Color backgroundColor;
  final Color textColor;
  final double radius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double topOffset;
  final Duration animationDuration;
  final Curve animationCurve;
  final List<BoxShadow>? boxShadow;
  final FontWeight fontWeight;
  final bool dismissOnTap;
  final bool swipeToDismiss;
  final double swipeVelocityThreshold;

  const _TopToastWidget({
    required this.message,
    this.imagePath,
    required this.backgroundColor,
    required this.textColor,
    required this.radius,
    required this.padding,
    required this.margin,
    required this.topOffset,
    required this.animationDuration,
    required this.animationCurve,
    this.boxShadow,
    required this.fontWeight,
    required this.dismissOnTap,
    required this.swipeToDismiss,
    required this.swipeVelocityThreshold,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  static _TopToastWidgetState? _current;

  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  Offset _dragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();

    _current = this;

    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _controller, curve: widget.animationCurve),
        );

    _fade = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();
  }

  /// ✅ SAFE GLOBAL DISMISS
  static void dismissCurrent() {
    _current?._dismiss();
  }

  void _dismiss() {
    if (!_controller.isAnimating &&
        _controller.status == AnimationStatus.dismissed) {
      SnackbarHelper._removeCurrent();
      return;
    }

    _controller.reverse().then((_) {
      if (mounted) {
        SnackbarHelper._removeCurrent();
      }
    });
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    if (_current == this) {
      _current = null;
    }
    super.dispose();
  }

  bool _isSwipeValid(DragEndDetails details) {
    final vx = details.velocity.pixelsPerSecond.dx;
    final vy = details.velocity.pixelsPerSecond.dy;

    final absX = vx.abs();
    final absY = vy.abs();

    final threshold = widget.swipeVelocityThreshold;

    if (absX > absY && absX > threshold) return true;
    if (vy < -threshold) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + widget.topOffset,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: GestureDetector(
                onTap: widget.dismissOnTap ? _dismiss : null,

                onPanUpdate: widget.swipeToDismiss
                    ? (details) {
                        _dragOffset += details.delta;
                        setState(() {});
                      }
                    : null,

                onPanEnd: widget.swipeToDismiss
                    ? (details) {
                        if (_isSwipeValid(details)) {
                          _dismiss();
                        } else {
                          setState(() => _dragOffset = Offset.zero);
                        }
                      }
                    : null,

                child: Transform.translate(
                  offset: _dragOffset,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                    ),
                    child: Container(
                      padding: widget.padding,
                      decoration: BoxDecoration(
                        color: widget.backgroundColor,
                        borderRadius: BorderRadius.circular(widget.radius),
                        boxShadow:
                            widget.boxShadow ??
                            [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          /// ✅ OPTIONAL IMAGE
                          if (widget.imagePath != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: 10,
                                bottom: 5,
                              ),
                              child: CommonImageView(
                                imagePath: widget.imagePath!,
                                height: 20,
                              ),
                            ),

                          Flexible(
                            child: AppText.p2(
                              widget.message,
                              color: widget.textColor,
                              weight: widget.fontWeight,
                              align: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
