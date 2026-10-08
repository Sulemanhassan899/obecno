import 'package:flutter/material.dart';

/// Layout buckets used across the app.
///
/// - [phone]: phones and compact widths (&lt; 600)
/// - [smallTablet]: small tablets / large phones in landscape (600–839)
/// - [mediumTablet]: typical iPad portrait (840–1023)
/// - [largeTablet]: iPad Pro / iPad landscape and up (≥ 1024)
enum AppBreakpoint { phone, smallTablet, mediumTablet, largeTablet }

/// Shared breakpoints and sizing helpers for phone → tablet → iPad.
class Breakpoints {
  Breakpoints._();

  static const double phoneMax = 599;
  static const double smallTabletMax = 839;
  static const double mediumTabletMax = 1023;

  /// Readable content column width for a given viewport width.
  static double contentMaxWidth(double width) {
    if (width <= phoneMax) return width;
    if (width <= smallTabletMax) return 640;
    if (width <= mediumTabletMax) return 720;
    return 840;
  }

  static AppBreakpoint fromWidth(double width) {
    if (width <= phoneMax) return AppBreakpoint.phone;
    if (width <= smallTabletMax) return AppBreakpoint.smallTablet;
    if (width <= mediumTabletMax) return AppBreakpoint.mediumTablet;
    return AppBreakpoint.largeTablet;
  }
}

/// Carries the real window size so breakpoints stay correct after the app
/// shell clamps content width.
class ResponsiveScope extends InheritedWidget {
  const ResponsiveScope({
    super.key,
    required this.windowSize,
    required super.child,
  });

  final Size windowSize;

  static ResponsiveScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ResponsiveScope>();
  }

  @override
  bool updateShouldNotify(ResponsiveScope oldWidget) {
    return windowSize != oldWidget.windowSize;
  }
}

/// Context helpers for responsive layout decisions.
class Responsive {
  Responsive._();

  /// Full window width (prefers [ResponsiveScope] when present).
  static double widthOf(BuildContext context) {
    return ResponsiveScope.maybeOf(context)?.windowSize.width ??
        MediaQuery.sizeOf(context).width;
  }

  static Size windowSizeOf(BuildContext context) {
    return ResponsiveScope.maybeOf(context)?.windowSize ??
        MediaQuery.sizeOf(context);
  }

  static AppBreakpoint of(BuildContext context) =>
      Breakpoints.fromWidth(widthOf(context));

  static bool isPhone(BuildContext context) =>
      of(context) == AppBreakpoint.phone;

  static bool isTablet(BuildContext context) => !isPhone(context);

  static bool isSmallTablet(BuildContext context) =>
      of(context) == AppBreakpoint.smallTablet;

  static bool isMediumTablet(BuildContext context) =>
      of(context) == AppBreakpoint.mediumTablet;

  static bool isLargeTablet(BuildContext context) =>
      of(context) == AppBreakpoint.largeTablet;

  /// Max content width for the current window.
  static double contentMaxWidth(BuildContext context) =>
      Breakpoints.contentMaxWidth(widthOf(context));

  /// Horizontal page gutter that scales with breakpoint.
  static double pagePadding(BuildContext context) {
    switch (of(context)) {
      case AppBreakpoint.phone:
        return 16;
      case AppBreakpoint.smallTablet:
        return 24;
      case AppBreakpoint.mediumTablet:
        return 32;
      case AppBreakpoint.largeTablet:
        return 40;
    }
  }

  /// Pick a value per breakpoint. Falls back to the next-smaller defined value.
  static T value<T>(
    BuildContext context, {
    required T phone,
    T? smallTablet,
    T? mediumTablet,
    T? largeTablet,
  }) {
    switch (of(context)) {
      case AppBreakpoint.phone:
        return phone;
      case AppBreakpoint.smallTablet:
        return smallTablet ?? phone;
      case AppBreakpoint.mediumTablet:
        return mediumTablet ?? smallTablet ?? phone;
      case AppBreakpoint.largeTablet:
        return largeTablet ?? mediumTablet ?? smallTablet ?? phone;
    }
  }
}

/// Rebuilds when the active [AppBreakpoint] changes.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, AppBreakpoint breakpoint) builder;

  @override
  Widget build(BuildContext context) {
    return builder(context, Responsive.of(context));
  }
}
