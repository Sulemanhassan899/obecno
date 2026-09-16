import 'package:flutter/material.dart';

/// Bottom sheets wrap their content and never grow past 90% of the screen.
/// Taller content scrolls inside that cap.
class AppSheetSize {
  AppSheetSize._();

  static const double maxFactor = 0.9;

  static double maxHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height * maxFactor;
  }

  static BoxConstraints constraintsOf(BuildContext context) {
    return BoxConstraints(maxHeight: maxHeight(context));
  }
}
