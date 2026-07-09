import 'package:Obecno/core/constants/app_fonts.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/widgets/text_widget.dart';
import 'package:flutter/material.dart';

import '../core/animations/button_animations.dart';
import '../core/animations/scroll_animations.dart';
import '../core/constants/all_colors.dart';

/// =====================
/// MY BUTTON
/// =====================
class MyButton extends StatelessWidget {
  const MyButton({
    super.key,
    required this.onTap,
    required this.buttonText,
    this.height = 59,
    this.width,
    this.backgroundColor,
    this.fontColor,
    this.fontSize,
    this.customChild,
    this.outlineColor = kBorderColor,
    this.radius = 50,
    this.svgIcon,
    this.haveSvg = false,
    this.choiceIcon,
    this.choiceIconRight,
    this.isleft = false,
    this.isRight = false,
    this.mhoriz = 0,
    this.hasicon = false,
    this.hasshadow = false,
    this.mBottom = 0,
    this.hasgrad = false,
    this.isactive = true,
    this.mTop = 0,
    this.fontWeight,
    this.hasiconRight = false,
    this.leftWidget,
    this.rightWidget,
  });

  final String buttonText;
  final VoidCallback onTap;
  final double? height;
  final Widget? customChild;
  final double? width;
  final double radius;
  final double? fontSize;
  final Color outlineColor;

  final bool hasicon,
      hasiconRight,
      isRight,
      isleft,
      hasshadow,
      hasgrad,
      isactive;

  final Color? backgroundColor, fontColor;
  final String? svgIcon, choiceIcon, choiceIconRight;
  final bool haveSvg;
  final double mTop, mBottom, mhoriz;
  final FontWeight? fontWeight;

  final Widget? leftWidget;
  final Widget? rightWidget;

  @override
  Widget build(BuildContext context) {
    return ScrollAnimations.fadeSlide(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastLinearToSlowEaseIn,
      travel: 50,
      child: ButtonAnimations.press(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(
            top: mTop,
            bottom: mBottom,
            left: mhoriz,
            right: mhoriz,
          ),
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: isactive
                ? backgroundColor ?? kSecondaryButtonColor
                : backgroundColor ?? kPrimaryButtonColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: outlineColor),
          ),
          child: Material(
            color: Colors.transparent,
            child:
                customChild ??
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    /// LEFT ICON
                    if (hasicon)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child:
                            leftWidget ??
                            (choiceIcon != null
                                ? Image.asset(choiceIcon!, height: 20)
                                : const SizedBox()),
                      ),

                    if (hasicon) const SizedBox(width: 10),

                    /// ✅ TEXT LOGIC (UPDATED)
                    _buildText(),

                    if (hasiconRight) const SizedBox(width: 10),

                    /// RIGHT ICON
                    if (hasiconRight)
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child:
                            rightWidget ??
                            (choiceIconRight != null
                                ? CommonImageView(imagePath: choiceIconRight!)
                                : const SizedBox()),
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  /// =====================
  /// TEXT BUILDER (SMART)
  /// =====================
  Widget _buildText() {
    final Color textColor = fontColor ?? kWhite;

    if (fontSize == null && fontWeight == null) {
      return AppText.p3(buttonText, color: textColor, align: TextAlign.center);
    }

    /// ✅ IF CUSTOM PROVIDED → OVERRIDE
    return TextWidget(
      text: buttonText,
      textAlign: TextAlign.center,
      size: fontSize ?? 18,
      letterSpacing: 0.5,
      fontFamily: AppFonts.Poppins,
      color: textColor,
      weight: fontWeight ?? FontWeight.w400,
    );
  }
}
