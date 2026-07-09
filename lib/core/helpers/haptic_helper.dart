import 'package:flutter/services.dart';

/// Thin wrapper around [HapticFeedback] (Flutter SDK, no plugin required)
/// so call sites use one consistent, semantic API.
class HapticHelper {
  HapticHelper._();

  static void light() => HapticFeedback.lightImpact();

  static void medium() => HapticFeedback.mediumImpact();

  static void heavy() => HapticFeedback.heavyImpact();

  static void selection() => HapticFeedback.selectionClick();
}
