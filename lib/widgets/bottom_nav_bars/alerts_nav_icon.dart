import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class AlertsNavIcon extends StatelessWidget {
  const AlertsNavIcon({
    super.key,
    required this.selected,
    required this.showBadge,
    this.size = 18,
  });

  final bool selected;
  final bool showBadge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = CommonImageView(
      imagePath: selected
          ? Assets.navigationActiveAlertsIcon
          : Assets.navigationUnactiveAlertsIcon,
      height: size,
      width: size,
      fit: BoxFit.contain,
    );

    // Same footprint as other nav icons so gaps stay even with/without badge.
    return SizedBox(
      width: size + 6,
      height: size + 4,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          icon,
          if (showBadge)
            Positioned(
              right: 0,
              top: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: kredColor,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: size * 0.45,
                  height: size * 0.45,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
