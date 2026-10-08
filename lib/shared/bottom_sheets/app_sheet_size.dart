import 'package:flutter/material.dart';
import 'package:obecno/core/responsive/responsive.dart';

/// Bottom sheets wrap their content and never grow past 90% of the screen.
/// On tablets/iPads they are also width-capped and centered.
class AppSheetSize {
  AppSheetSize._();

  static const double maxFactor = 0.9;

  static double maxHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height * maxFactor;
  }

  static double maxWidth(BuildContext context) {
    // Prefer the real window width so sheets stay correctly capped on iPad
    // even when the app shell has already constrained MediaQuery.size.
    return Breakpoints.contentMaxWidth(Responsive.widthOf(context));
  }

  static BoxConstraints constraintsOf(BuildContext context) {
    return BoxConstraints(
      maxWidth: maxWidth(context),
      maxHeight: maxHeight(context),
    );
  }

  /// Constraints for [showModalBottomSheet] so sheets stay centered on iPad.
  static BoxConstraints modalConstraintsOf(BuildContext context) {
    return constraintsOf(context);
  }
}
