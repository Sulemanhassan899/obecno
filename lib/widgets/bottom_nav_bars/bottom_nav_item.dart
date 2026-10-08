import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_fonts.dart';
import 'package:obecno/widgets/bottom_nav_bars/alerts_nav_icon.dart';
import 'package:obecno/widgets/bottom_nav_bars/bottom_nav_metrics.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/text_widget.dart';
import 'package:flutter/material.dart';

/// Equal-width bottom-nav tab: icon + label, centered on both axes.
class BottomNavItem extends StatelessWidget {
  const BottomNavItem({
    super.key,
    required this.metrics,
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.selected,
    required this.onTap,
    this.isAlerts = false,
    this.showAlertsBadge = false,
  });

  final BottomNavMetrics metrics;
  final String label;
  final String activeIcon;
  final String inactiveIcon;
  final bool selected;
  final VoidCallback onTap;
  final bool isAlerts;
  final bool showAlertsBadge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? kPrimaryColor : kGreyColor;

    return Expanded(
      child: ButtonAnimations.press(
        pressedScale: 0.97,
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: metrics.slotSize,
                width: metrics.slotSize,
                child: Center(
                  child: isAlerts
                      ? AlertsNavIcon(
                          selected: selected,
                          showBadge: showAlertsBadge,
                          size: metrics.iconSize,
                        )
                      : CommonImageView(
                          imagePath: selected ? activeIcon : inactiveIcon,
                          height: metrics.iconSize,
                          width: metrics.iconSize,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              SizedBox(height: metrics.iconLabelGap),
              SizedBox(
                width: double.infinity,
                child: TextWidget(
                  text: label,
                  size: metrics.labelSize,
                  fontFamily: AppFonts.Poppins,
                  weight: FontWeight.w400,
                  color: color,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: metrics.bottomGap),
            ],
          ),
        ),
      ),
    );
  }
}
