import 'package:Obecno/core/constants/text_styles.dart';
import 'package:flutter/material.dart';

import 'package:Obecno/core/constants/all_colors.dart';
import 'common_image_view_widget.dart';
import 'custom_dropdown.dart';
import 'custom_textfield.dart';
import 'my_button.dart';
import 'text_widget.dart';

class DialogHelper {
  static void show({
    required BuildContext context,

    /// UI
    ///
    String? title,
    String? subtitle,
    String? imagePath,
    String? defaultImage,
    Color? backgroundColor,
    cancelButtonBg,
    ButtonBg,
    double? width,
    double? height,
    double? heightImage,

    /// Form
    List<TextEditingController>? textControllers,
    List<String>? textFieldHints,

    /// Dropdown
    List<String>? dropdownItems,
    String? selectedDropdownValue,
    Function(String)? onDropdownChanged,

    /// Buttons
    String? buttonText,
    VoidCallback? onButtonTap,

    String? cancelButtonText,
    VoidCallback? onCancelTap,

    /// Navigation
    Widget? route,
    bool removeAll = false,

    /// Extra UI
    List<Widget>? children,

    bool barrierDismissible = true,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: backgroundColor ?? kWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// ✅ IMAGE (with fallback)
                      if (imagePath != null || defaultImage != null)
                        CommonImageView(
                          imagePath: imagePath ?? defaultImage!,
                          height: heightImage ?? 120,
                        ),

                      if (imagePath != null || defaultImage != null)
                        const SizedBox(height: 16),

                      /// TITLE
                      if (title != null)
                        TextWidget(
                          text: title,
                          size: 22,
                          weight: FontWeight.w700,
                          textAlign: TextAlign.center,
                        ),

                      if (title != null) const SizedBox(height: 12),

                      /// SUBTITLE
                      if (subtitle != null) AppText.p1(subtitle),

                      if (subtitle != null) const SizedBox(height: 20),

                      /// TEXTFIELDS
                      if (textControllers != null && textFieldHints != null)
                        ...List.generate(
                          textControllers.length,
                          (index) => Column(
                            children: [
                              CustomTextField(
                                controller: textControllers[index],
                                hintText: textFieldHints[index],
                                backgroundColor: kWhite,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),

                      /// DROPDOWN
                      if (dropdownItems != null &&
                          selectedDropdownValue != null)
                        CustomDropDown(
                          hint: "Select Option",
                          items: dropdownItems,
                          selectedValue: selectedDropdownValue,
                          onChanged: (value) {
                            if (onDropdownChanged != null) {
                              onDropdownChanged(value.toString());
                              setState(() {});
                            }
                          },
                        ),

                      if (dropdownItems != null) const SizedBox(height: 20),

                      /// EXTRA CHILDREN
                      if (children != null) ...children,

                      const SizedBox(height: 10),

                      /// ✅ BUTTONS IN ROW (SIDE BY SIDE)
                      if (buttonText != null || cancelButtonText != null)
                        Row(
                          children: [
                            /// ❌ CANCEL BUTTON
                            if (cancelButtonText != null)
                              width != null
                                  ? MyButton(
                                      height: height ?? 59,
                                      width:
                                          width, // ✅ fixed width when provided
                                      buttonText: cancelButtonText,
                                      onTap: () async {
                                        Navigator.pop(context);
                                        onCancelTap?.call();
                                      },
                                      backgroundColor: cancelButtonBg ?? kWhite,
                                      fontColor: kBlack,
                                      outlineColor: kBorderColor,
                                    )
                                  : Expanded(
                                      child: MyButton(
                                        height: height ?? 59,
                                        buttonText: cancelButtonText,
                                        onTap: () async {
                                          Navigator.pop(context);
                                          onCancelTap?.call();
                                        },
                                        backgroundColor:
                                            cancelButtonBg ?? kWhite,
                                        fontColor: kBlack,
                                        outlineColor: kBorderColor,
                                      ),
                                    ),

                            if (buttonText != null && cancelButtonText != null)
                              const SizedBox(width: 12),

                            /// ✅ PRIMARY BUTTON
                            if (buttonText != null)
                              Expanded(
                                child: MyButton(
                                  height: height ?? 59,
                                  buttonText: buttonText,
                                  onTap: () async {
                                    Navigator.pop(context);

                                    onButtonTap?.call();

                                    if (route != null) {
                                      if (removeAll) {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => route,
                                          ),
                                          (route) => false,
                                        );
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => route,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  backgroundColor: ButtonBg ?? kPrimaryColor,
                                  fontColor: kWhite,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// ✅ OLD API preserved
  static void successDialog(BuildContext context) {
    show(
      context: context,
      title: "Verification Complete!",
      subtitle: "Enjoy the app features",
      buttonText: "Done",
    );
  }
}
