import 'package:Obecno/core/constants/app_fonts.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/constants/all_colors.dart';

class CustomRichText extends StatelessWidget {
  final String prefixText;
  final String linkText1;
  final String middleText;
  final String linkText2;
  final String suffixText;

  final VoidCallback? onTap1;
  final VoidCallback? onTap2;

  final AppTextType textType;

  final TextStyle? normalStyle;
  final TextStyle? linkStyle;

  final TextAlign textAlign;

  const CustomRichText({
    super.key,
    required this.prefixText,
    required this.linkText1,
    required this.middleText,
    required this.linkText2,
    this.suffixText = '',
    this.onTap1,
    this.onTap2,
    this.normalStyle,
    this.linkStyle,
    this.textAlign = TextAlign.start,
    this.textType = AppTextType.p2,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = _getTextStyle();

    final normal = normalStyle ?? baseStyle.copyWith(color: kGreyColor);

    final link =
        linkStyle ??
        baseStyle.copyWith(
          color: kGreyColor,
          fontWeight: FontWeight.w400,
          decoration: TextDecoration.underline,
        );

    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: normal,
        children: [
          TextSpan(text: prefixText),
          TextSpan(
            text: linkText1,
            style: link,
            recognizer: TapGestureRecognizer()..onTap = onTap1,
          ),
          TextSpan(text: middleText),
          TextSpan(
            text: linkText2,
            style: link,
            recognizer: TapGestureRecognizer()..onTap = onTap2,
          ),
          TextSpan(text: suffixText),
        ],
      ),
    );
  }

  TextStyle _getTextStyle() {
    switch (textType) {
      case AppTextType.h1:
        return _style(32, FontWeight.w700);
      case AppTextType.h2:
        return _style(28, FontWeight.w700);
      case AppTextType.h3:
        return _style(24, FontWeight.w600);
      case AppTextType.h4:
        return _style(22, FontWeight.w600);
      case AppTextType.h5:
        return _style(18, FontWeight.w500);
      case AppTextType.h6:
        return _style(16, FontWeight.w500);
      case AppTextType.h7:
        return _style(11, FontWeight.w500);
      case AppTextType.p1:
        return _style(16, FontWeight.w400);
      case AppTextType.p2:
        return _style(14, FontWeight.w400);
      case AppTextType.p3:
        return _style(18, FontWeight.w400);
      case AppTextType.caption:
        return _style(12, FontWeight.w400);
      case AppTextType.small:
        return _style(11, FontWeight.w400);
    }
  }

  TextStyle _style(double size, FontWeight weight) {
    return TextStyle(
      fontFamily: AppFonts.Poppins,
      fontSize: size,
      fontWeight: weight,
    );
  }
}

enum AppTextType { h1, h2, h3, h4, h5, h6, h7, p1, p2, p3, caption, small }
