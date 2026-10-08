import 'package:flutter/material.dart';
import 'package:obecno/core/responsive/responsive.dart';

class AppSizes {
  static const DEFAULT = EdgeInsets.symmetric(horizontal: 16, vertical: 40);

  static const DEFAULT2 = EdgeInsets.only(left: 16, right: 16, top: 40);

  static const HORIZONTAL = EdgeInsets.symmetric(horizontal: 20);
  static const VERTICAL = EdgeInsets.symmetric(vertical: 16);

  /// Tight gap below the status bar for tab headers.
  static const double headerTop = 8;

  /// Responsive horizontal gutter (16 → 40 by breakpoint).
  static double horizontal(BuildContext context) =>
      Responsive.pagePadding(context);

  /// Symmetric horizontal padding that scales with screen size.
  static EdgeInsets horizontalOnly(BuildContext context) {
    final h = horizontal(context);
    return EdgeInsets.symmetric(horizontal: h);
  }

  /// Default screen padding with responsive horizontal values.
  static EdgeInsets defaultPadding(BuildContext context) {
    final h = horizontal(context);
    return EdgeInsets.symmetric(horizontal: h, vertical: 40);
  }

  /// Alias used by a few screens.
  static EdgeInsets defaultOf(BuildContext context) => defaultPadding(context);

  /// Horizontal page padding plus a consistent inset below the status bar.
  static EdgeInsets page(BuildContext context, [EdgeInsets? padding]) {
    final h = horizontal(context);
    final base = padding ?? DEFAULT2;
    return base.copyWith(
      left: h,
      right: h,
      top: MediaQuery.paddingOf(context).top + headerTop,
    );
  }
}
