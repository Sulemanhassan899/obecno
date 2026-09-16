import 'package:flutter/material.dart';

class AppSizes {
  static const DEFAULT = EdgeInsets.symmetric(horizontal: 16, vertical: 40);

  static const DEFAULT2 = EdgeInsets.only(left: 16, right: 16, top: 40);

  static const HORIZONTAL = EdgeInsets.symmetric(horizontal: 20);
  static const VERTICAL = EdgeInsets.symmetric(vertical: 16);

  /// Tight gap below the status bar for tab headers.
  static const double headerTop = 8;

  /// Horizontal page padding plus a consistent inset below the status bar.
  static EdgeInsets page(BuildContext context, [EdgeInsets? padding]) {
    final base = padding ?? DEFAULT2;
    return base.copyWith(top: MediaQuery.paddingOf(context).top + headerTop);
  }
}
