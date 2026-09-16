import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class AlertsNavIcon extends StatelessWidget {
  const AlertsNavIcon({
    super.key,
    required this.selected,
    required this.showBadge,
  });

  final bool selected;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final icon = CommonImageView(
      imagePath: selected
          ? Assets.navigationActiveAlertsIcon
          : Assets.navigationUnactiveAlertsIcon,
      height: 20,
    );

    if (!showBadge) return icon;

    return SizedBox(
      width: 24,
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: icon),
          const Positioned(
            right: 0,
            top: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kredColor,
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 8, height: 8),
            ),
          ),
        ],
      ),
    );
  }
}
