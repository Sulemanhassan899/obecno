import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class ConfirmLocationChangeDialog {
  ConfirmLocationChangeDialog._();

  static Future<bool?> show(BuildContext context) {
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
                  imagePath: Assets.LocationDialog,
                  height: 72,
                  width: 72,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 18),
                AppText.h2(
                  'Confirm Location Change',
                ),
                const SizedBox(height: 10),
                AppText.p1(
                  "Changing the default location will update the existing location’s attendance rules and settings to this user.",
                  color: kGreyColor,
                ),
                const SizedBox(height: 16),
                AppText.p1(
                  'Do you want to continue?',
                  color: kGreyColor,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                 Flexible(
                      flex: 2,
                      child: MyButton(
                        height: 48,
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
                        height: 48,
                        buttonText: 'Confirm Change',
                        backgroundColor: kredColor,
                        fontSize: 13,
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
