// ignore: must_be_immutable
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_fonts.dart';
import 'package:Obecno/shared/widgets/text_widget.dart';
import 'package:flutter/material.dart';

class CustomTextField2 extends StatelessWidget {
  TextEditingController? controller;

  /// =====================
  /// BORDER CONTROL (FULLY SEPARATED)
  /// =====================
  final double radius;

  final Color enabledBorderColor;
  final double enabledBorderWidth;

  final Color focusedBorderColor;
  final double focusedBorderWidth;

  final Color errorBorderColor;
  final double errorBorderWidth;

  final Color disabledBorderColor;
  final double disabledBorderWidth;

  /// =====================
  /// BASIC
  /// =====================
  final String hintText;
  final int maxlines;
  final double hintTextFontSize;
  final Color hintTextFontColor;

  final bool filled;
  final Color backgroundColor;

  /// =====================
  /// LABEL
  /// =====================
  final bool hasStar;
  final String? labelText;
  final bool haveLebelText;
  final Color lableColor;

  /// =====================
  /// TEXT
  /// =====================
  final Color txtColor;
  final bool obscureText;

  /// =====================
  /// ICONS
  /// =====================
  final bool havePrefixIcon;
  final bool haveSuffixIcon;
  final Widget? preffixWidget, suffixWidget;

  /// =====================
  /// BEHAVIOR
  /// =====================
  final bool enabled;
  final bool readOnly;
  final bool textFieldEnable;

  final GestureTapCallback? onSuffixTap;
  final VoidCallback? onTextFieldTap;

  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  /// =====================
  /// LAYOUT
  /// =====================
  final double contentPaddingLeft;
  final double contentPaddingRight;
  final double contentPaddingBottom;
  final double contentPaddingTop;
  final TextInputType keyboardType;
  final double left;
  final double right;
  final double top;
  final double bottom;

  final bool isExpanded;
  final double height;
  final double width;

  CustomTextField2({
    super.key,
    this.controller,
    this.keyboardType = TextInputType.text,

    /// BORDER DEFAULTS
    this.radius = 12,

    this.enabledBorderColor = kBorderColor,
    this.enabledBorderWidth = 1,

    this.focusedBorderColor = kPrimaryColor,
    this.focusedBorderWidth = 1.5,

    this.errorBorderColor = kRed,
    this.errorBorderWidth = 1.5,

    this.disabledBorderColor = kGreyColor2,
    this.disabledBorderWidth = 1,

    /// BASIC
    this.hintText = 'Hint here',
    this.maxlines = 1,
    this.hintTextFontColor = klightblackColor,
    this.hintTextFontSize = 12,
    this.filled = true,
    this.backgroundColor = kTransperentColor,

    /// LABEL
    this.labelText,
    this.haveLebelText = true,
    this.hasStar = false,
    this.lableColor = kBlack,

    /// TEXT
    this.txtColor = kBlack,
    this.obscureText = false,

    /// ICONS
    this.havePrefixIcon = false,
    this.haveSuffixIcon = false,
    this.preffixWidget,
    this.suffixWidget,

    /// BEHAVIOR
    this.enabled = true,
    this.readOnly = false,
    this.textFieldEnable = true,
    this.onSuffixTap,
    this.onTextFieldTap,
    this.onChanged,
    this.validator,

    /// LAYOUT
    this.contentPaddingLeft = 16,
    this.contentPaddingRight = 16,
    this.contentPaddingBottom = 12,
    this.contentPaddingTop = 12,

    this.left = 0,
    this.right = 0,
    this.top = 0,
    this.bottom = 0,

    this.isExpanded = true,
    this.height = 50,
    this.width = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: left,
        right: right,
        top: top,
        bottom: bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// =====================
          /// LABEL
          /// =====================
          if (haveLebelText)
            Row(
              children: [
                TextWidget(
                  text: labelText ?? '',
                  size: 12,
                  fontFamily: AppFonts.Poppins,
                  weight: FontWeight.w500,
                  color: lableColor,
                ),
                if (hasStar)
                  const TextWidget(
                    text: ' *',
                    size: 14,
                    weight: FontWeight.w600,
                    color: kRed,
                  ),
              ],
            ),

          if (haveLebelText) const SizedBox(height: 6),

          /// =====================
          /// TEXT FIELD
          /// =====================
          SizedBox(
            width: isExpanded ? double.infinity : width,
            height: height,
            child: TextFormField(
              keyboardType: keyboardType,
              validator: validator,
              controller: controller,
              maxLines: maxlines,
              obscureText: obscureText,
              readOnly: readOnly,
              enabled: enabled,
              enableInteractiveSelection: textFieldEnable,
              cursorColor: kPrimaryColor,
              style: TextStyle(
                color: txtColor,
                fontSize: 12,
                fontFamily: AppFonts.Poppins,
                fontWeight: FontWeight.w400,
              ),

              onTap: onTextFieldTap,
              onChanged: onChanged,

              decoration: InputDecoration(
                /// ICONS
                prefixIcon: havePrefixIcon
                    ? SizedBox(width: 40, child: Center(child: preffixWidget))
                    : null,

                suffixIcon: haveSuffixIcon
                    ? GestureDetector(
                        onTap: onSuffixTap,
                        child: SizedBox(
                          width: 40,
                          child: Center(child: suffixWidget),
                        ),
                      )
                    : null,

                /// STYLE
                filled: filled,
                fillColor: backgroundColor,
                hintText: hintText,

                hintStyle: TextStyle(
                  color: hintTextFontColor,
                  fontSize: hintTextFontSize,
                  fontWeight: FontWeight.w400,
                  fontFamily: AppFonts.Poppins,
                ),

                contentPadding: EdgeInsets.only(
                  left: contentPaddingLeft,
                  right: contentPaddingRight,
                  top: contentPaddingTop,
                  bottom: contentPaddingBottom,
                ),

                /// =====================
                /// BORDERS (ALL STATES)
                /// =====================
                border: _border(enabledBorderColor, enabledBorderWidth),

                enabledBorder: _border(enabledBorderColor, enabledBorderWidth),

                focusedBorder: _border(focusedBorderColor, focusedBorderWidth),

                errorBorder: _border(errorBorderColor, errorBorderWidth),

                focusedErrorBorder: _border(errorBorderColor, errorBorderWidth),

                disabledBorder: _border(
                  disabledBorderColor,
                  disabledBorderWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// =====================
  /// BORDER BUILDER
  /// =====================
  OutlineInputBorder _border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
