import 'package:flutter/material.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/widgets/bottom_nav_bars/manager_nav.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';

/// Which Alerts chip to open from the Clock banner.
enum ClockAlertKind { leave, device, reminder, general }

/// Pink alert banner on Clock for managers when there is a new alert.
class ClockAlertCard extends StatelessWidget {
  const ClockAlertCard({
    super.key,
    this.onView,
    this.kind = ClockAlertKind.general,
  });

  final VoidCallback? onView;
  final ClockAlertKind kind;

  String get _message => switch (kind) {
    ClockAlertKind.leave => 'You have leave alert',
    ClockAlertKind.device => 'You have device alert',
    ClockAlertKind.reminder => 'You have reminder alert',
    ClockAlertKind.general => 'You have an alert',
  };

  String? get _alertsFilter => switch (kind) {
    ClockAlertKind.leave => 'leaves',
    ClockAlertKind.device => 'device',
    ClockAlertKind.reminder => 'reminder',
    ClockAlertKind.general => null,
  };

  void _openAlerts() {
    if (onView != null) {
      onView!();
      return;
    }
    ManagerBottomNavBar.goToAlerts(filter: _alertsFilter);
  }

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: _openAlerts,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kredColor.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            CommonImageView(imagePath: Assets.imagesRedBell, height: 22),
            const SizedBox(width: 10),
            Expanded(
              child: AppText.p2(
                _message,
                weight: FontWeight.w500,
                align: TextAlign.left,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(30),
              ),
              child: AppText.caption('View Alert', weight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
