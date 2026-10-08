import 'package:obecno/core/responsive/responsive.dart';
import 'package:flutter/material.dart';

/// Scales bottom-nav icon/label/spacing for small → large phones (and tablets).
class BottomNavMetrics {
  const BottomNavMetrics({
    required this.iconSize,
    required this.labelSize,
    required this.iconLabelGap,
    required this.bottomGap,
    required this.paddingH,
    required this.paddingV,
  });

  final double iconSize;
  final double labelSize;
  final double iconLabelGap;
  final double bottomGap;
  final double paddingH;
  final double paddingV;

  double get slotSize => iconSize + 6;

  factory BottomNavMetrics.of(BuildContext context) {
    final width = Responsive.widthOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(0.9, 1.15);

    // Phone continuum (width-based), then tablet breakpoints.
    late final BottomNavMetrics base;
    if (width < 360) {
      // Small phones (SE / compact)
      base = const BottomNavMetrics(
        iconSize: 16,
        labelSize: 11,
        iconLabelGap: 4,
        bottomGap: 4,
        paddingH: 8,
        paddingV: 12,
      );
    } else if (width < 400) {
      // Regular phones
      base = const BottomNavMetrics(
        iconSize: 18,
        labelSize: 12,
        iconLabelGap: 5,
        bottomGap: 5,
        paddingH: 12,
        paddingV: 14,
      );
    } else if (width < 600) {
      // Large phones
      base = const BottomNavMetrics(
        iconSize: 20,
        labelSize: 13,
        iconLabelGap: 6,
        bottomGap: 6,
        paddingH: 16,
        paddingV: 16,
      );
    } else if (width < 840) {
      base = const BottomNavMetrics(
        iconSize: 22,
        labelSize: 13,
        iconLabelGap: 6,
        bottomGap: 6,
        paddingH: 20,
        paddingV: 18,
      );
    } else if (width < 1024) {
      base = const BottomNavMetrics(
        iconSize: 24,
        labelSize: 14,
        iconLabelGap: 7,
        bottomGap: 7,
        paddingH: 24,
        paddingV: 20,
      );
    } else {
      base = const BottomNavMetrics(
        iconSize: 26,
        labelSize: 14,
        iconLabelGap: 8,
        bottomGap: 8,
        paddingH: 28,
        paddingV: 22,
      );
    }

    if (textScale == 1.0) return base;
    return BottomNavMetrics(
      iconSize: base.iconSize * textScale,
      labelSize: base.labelSize * textScale,
      iconLabelGap: base.iconLabelGap,
      bottomGap: base.bottomGap,
      paddingH: base.paddingH,
      paddingV: base.paddingV,
    );
  }
}
