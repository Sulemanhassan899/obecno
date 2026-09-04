import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class DeactivateAccountDialog {
  DeactivateAccountDialog._();

  static Future<bool?> show(
    BuildContext context, {
    required bool activate,
    String? employeeName,
  }) {
    return showDialog<bool>(
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
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CommonImageView(
                  imagePath: Assets.DeactiviateUserIcon,
                  height: 72,
                  width: 72,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 18),
                AppText.h4(
                  activate ? 'Activate Account' : 'Deactivate Account',
                ),
                const SizedBox(height: 10),
                AppText.p1(
                  activate
                      ? '${employeeName ?? 'This employee'} will be able to sign in and mark attendance again.'
                      : '${employeeName ?? 'This employee'} will lose access and will not be able to mark attendance.',
                  color: kGreyColor,
                ),
                const SizedBox(height: 16),
                AppText.p1('Do you want to continue?', color: kGreyColor),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Flexible(
                      flex: 2,
                      child: MyButton(
                        size: MyButtonSize.normal,
                        buttonText: 'Cancel',
                        backgroundColor: kWhite,
                        fontColor: kBlack,
                        outlineColor: kBorderColor,
                        onTap: () async => Navigator.pop(dialogContext, false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      flex: 4,
                      child: MyButton(
                        size: MyButtonSize.normal,
                        buttonText: activate ? 'Activate' : 'Deactivate',
                        backgroundColor: activate
                            ? kPrimaryButtonColor
                            : kredColor,
                        onTap: () async => Navigator.pop(dialogContext, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
