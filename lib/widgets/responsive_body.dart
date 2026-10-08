import 'package:flutter/material.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/responsive/responsive.dart';

/// App-wide shell that keeps UI readable on tablets and iPads.
///
/// Centers a capped content column and rewrites [MediaQuery.size] so
/// width-based layouts (grids, cards, sheets) measure the column, not the
/// full window. [ResponsiveScope] keeps the real window size for breakpoints.
class ResponsiveAppShell extends StatelessWidget {
  const ResponsiveAppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final windowSize = media.size;
    final maxContent = Breakpoints.contentMaxWidth(windowSize.width);

    Widget content = child;
    if (windowSize.width > maxContent + 0.5) {
      content = ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor == Colors.transparent
            ? kbackground1
            : Theme.of(context).scaffoldBackgroundColor,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContent),
            child: MediaQuery(
              data: media.copyWith(
                size: Size(maxContent, windowSize.height),
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    return ResponsiveScope(windowSize: windowSize, child: content);
  }
}

/// Optional per-screen content width clamp (forms, detail pages, etc.).
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
    this.backgroundColor,
  });

  final Widget child;
  final double? maxWidth;
  final Alignment alignment;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final cap = maxWidth ?? Responsive.contentMaxWidth(context);

    return ColoredBox(
      color: backgroundColor ?? Colors.transparent,
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cap),
          child: child,
        ),
      ),
    );
  }
}
