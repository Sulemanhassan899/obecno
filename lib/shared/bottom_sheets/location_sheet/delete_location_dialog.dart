import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class DeleteLocationDialog {
  DeleteLocationDialog._();

  /// Simple confirm: Cancel / Delete location
  static Future<bool?> showSimple(BuildContext context) {
    return showDialog<bool>(
      context: context,
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
                  imagePath: Assets.DeactiviateLocation,
                  height: 80,
                ),
                const SizedBox(height: 18),
                AppText.h4('Deactivate Location', ),
                const SizedBox(height: 10),
                AppText.p1(
                  'Location will be deactivate and user will be moved to the another location.',
                  color: kGreyColor,
                ),
                const SizedBox(height: 20),
                AppText.p1(
                  'Do you want to continue?',
                  color: kGreyColor,
                  weight: FontWeight.w400,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    MyButton(
                      size: MyButtonSize.normal,
                      width: 130,
                      buttonText: 'Cancel',
                      backgroundColor: kWhite,
                      fontColor: kGreyColor,
                      outlineColor: kBorderColor,
                      onTap: () async => Navigator.pop(dialogContext, false),
                    ),
                    const SizedBox(width: 10),
                    MyButton(
                      size: MyButtonSize.normal,
                      width: 200,
                     
                      buttonText: 'Deactivate',
                      backgroundColor: kredColor,
               
                      onTap: () async => Navigator.pop(dialogContext, true),
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

  /// Detailed confirm: Deactivate / Delete Location / Cancel
  static Future<DeleteLocationAction?> showDetailed(BuildContext context) {
    return showDialog<DeleteLocationAction>(
      context: context,
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
                  imagePath: Assets.DeleteLocation,
                  height: 80,
                ),
                const SizedBox(height: 18),
                AppText.h2('Delete Location'),
                const SizedBox(height: 20),
                AppText.p1(
                  'This will be permanent and cannot be undone. User will lose access to this location immediately',
                  color: kGreyColor,
                  weight: FontWeight.w400,
                ),
                const SizedBox(height: 30),
                AppText.p1(
                  'This will permanently remove: Company settings, Employees and teams, Locations, Attendance and leave data.',
                  color: kGreyColor,
                  weight: FontWeight.w400,
                ),
                const SizedBox(height: 30),
                AppText.p1(
                  'Do you want to continue?',
                  color: kGreyColor,
                  weight: FontWeight.w400,
                ),
                const SizedBox(height: 30),
                MyButton(
                  buttonText: 'Delete Location',
                  backgroundColor: kredColor,
                  onTap: () async => Navigator.pop(
                    dialogContext,
                    DeleteLocationAction.deactivate,
                  ),
                ),
                const SizedBox(height: 20),
                // MyButton(
                //   height: 48,
                //   buttonText: 'Delete Location',
                //   backgroundColor: kWhite,
                //   fontColor: kredColor,
                //   outlineColor: kredColor,
                //   onTap: () async =>
                //       Navigator.pop(dialogContext, DeleteLocationAction.delete),
                // ),
                // const SizedBox(height: 20),
                MyButton(
                  buttonText: 'Cancel',
                  backgroundColor: kWhite,
                  fontColor: kGreyColor,
                  outlineColor: kBorderColor,
                  onTap: () async =>
                      Navigator.pop(dialogContext, DeleteLocationAction.cancel),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum DeleteLocationAction { deactivate, delete, cancel }
