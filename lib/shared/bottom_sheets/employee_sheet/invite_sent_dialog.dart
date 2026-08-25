import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class InviteSentDialog {
  InviteSentDialog._();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: kWhite,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CommonImageView(
                  imagePath: Assets.LinkSendIcon,
                  height: 72,
                  width: 72,
                ),
                const SizedBox(height: 20),
                AppText.h4('Invites Sent!', weight: FontWeight.w700),
                const SizedBox(height: 10),
                AppText.p2(
                  'Your employees will receive their onboarding invites shortly. They can log in once they complete the setup.',
                  color: kGreyColor,
                ),
                const SizedBox(height: 24),
                MyButton(
                  width: 200,
                  buttonText: 'Continue  →',
                  backgroundColor: kPrimaryButtonColor,
                  onTap: () async => Navigator.pop(dialogContext),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Circular black + button used in Employees / Locations headers.
class ManagerPlusButton extends StatelessWidget {
  const ManagerPlusButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        height: 42,
        width: 42,
        decoration: const BoxDecoration(
          color: kPrimaryButtonColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: kWhite, size: 22),
      ),
    );
  }
}
