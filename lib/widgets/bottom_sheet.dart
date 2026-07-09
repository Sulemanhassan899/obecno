// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';

import '../core/constants/all_colors.dart';
import 'common_image_view_widget.dart';
import 'custom_dropdown.dart';
import 'custom_textfield.dart';
import 'my_button.dart';
import 'text_widget.dart';

class CommonBottomSheet extends StatelessWidget {
  final double height;
  final Color mainColor;
  final Color topColor;
  final double handleHeight;
  final BorderRadius borderRadius;

  final String? title;
  final String? subtitle;
  final String? imagePath;

  final List<TextEditingController>? textControllers;
  final List<String>? textFieldHints;

  final List<String>? dropdownItems;
  final String? selectedDropdownValue;
  final Function(String)? onDropdownChanged;

  final String? buttonText;
  final VoidCallback? onButtonTap;
  final String? buttonRightIcon;
  final bool hasRightIcon;
  final double buttonRadius;
  final Color buttonColor;
  final Color buttonFontColor;

  final List<Widget>? children;

  const CommonBottomSheet({
    super.key,
    this.height = 550,
    this.mainColor = kWhite,
    this.topColor = kWhite,
    this.handleHeight = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.title,
    this.subtitle,
    this.imagePath,
    this.textControllers,
    this.textFieldHints,
    this.dropdownItems,
    this.selectedDropdownValue,
    this.onDropdownChanged,
    this.buttonText,
    this.onButtonTap,
    this.buttonRightIcon,
    this.hasRightIcon = false,
    this.buttonRadius = 28,
    this.buttonColor = kPrimaryColor,
    this.buttonFontColor = kWhite,
    this.children,
  });

  // STATIC HELPER TO SHOW BOTTOM SHEET
  static void show({
    required BuildContext context,
    double height = 550,
    Color mainColor = kWhite,
    Color topColor = kWhite,
    double handleHeight = 14,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(24)),
    String? title,
    String? subtitle,
    String? imagePath,
    List<TextEditingController>? textControllers,
    List<String>? textFieldHints,
    List<String>? dropdownItems,
    String? selectedDropdownValue,
    Function(String)? onDropdownChanged,
    required String buttonText,
    VoidCallback? onButtonTap,
    String? buttonRightIcon,
    bool hasRightIcon = false,
    double buttonRadius = 28,
    Color buttonColor = kPrimaryColor,
    Color buttonFontColor = kWhite,
    List<Widget>? children,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet(
        context: context,
        elevation: 12,
        backgroundColor: Theme.of(context).cardColor,
        isScrollControlled: true,
        enableDrag: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  top: 24,
                  left: 16,
                  right: 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (imagePath != null)
                        Center(
                          child: CommonImageView(
                            imagePath: imagePath,
                            height: 150,
                          ),
                        ),
                      if (imagePath != null) const SizedBox(height: 24),
                      if (title != null)
                        TextWidget(
                          text: title,
                          size: 26,
                          weight: FontWeight.w700,
                          color: Colors.black,
                          textAlign: TextAlign.center,
                        ),
                      if (title != null) const SizedBox(height: 16),
                      if (subtitle != null)
                        TextWidget(
                          text: subtitle,
                          size: 16,
                          weight: FontWeight.w400,
                          color: kSubText2,
                          textAlign: TextAlign.center,
                        ),
                      if (subtitle != null) const SizedBox(height: 24),

                      // Dynamic Text Fields
                      if (textControllers != null && textFieldHints != null)
                        ...List.generate(
                          textControllers.length,
                          (index) => Column(
                            children: [
                              CustomTextField(
                                backgroundColor: kWhite,
                                hintTextFontColor: kSubText2,
                                hintTextFontSize: 16,
                                hintText: textFieldHints[index],
                                controller: textControllers[index],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),

                      // Dropdown
                      if (dropdownItems != null &&
                          selectedDropdownValue != null)
                        CustomDropDown(
                          hint: "Select Option",
                          selectedValue: selectedDropdownValue,
                          items: dropdownItems,
                          onChanged: (value) {
                            if (onDropdownChanged != null) {
                              onDropdownChanged(value.toString());
                              setState(() {});
                            }
                          },
                          bgColor: kWhite,
                        ),
                      if (dropdownItems != null) const SizedBox(height: 20),

                      // Additional Custom Widgets
                      if (children != null) ...children,

                      // Button
                      if (buttonText != null &&
                          buttonText.trim().isNotEmpty) ...[
                        MyButton(
                          onTap:
                              onButtonTap ?? () => Navigator.of(context).pop(),
                          buttonText: buttonText,
                          choiceIconRight: buttonRightIcon,
                          radius: buttonRadius,
                          hasiconRight: hasRightIcon,
                          isRight: hasRightIcon,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          backgroundColor: buttonColor,
                          fontColor: buttonFontColor,
                          height: 56,
                        ),
                        const SizedBox(height: 20),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
