import 'package:flutter/services.dart';

class HapticHelper {
  HapticHelper._();

  static void light() => HapticFeedback.lightImpact();

  static void medium() => HapticFeedback.mediumImpact();

  static void heavy() => HapticFeedback.heavyImpact();

  static void selection() => HapticFeedback.selectionClick();
}
