
import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/animations/scroll_animations.dart';
import 'package:Obecno/core/constants/app_fonts.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:Obecno/shared/widgets/text_widget.dart';
import 'package:flutter/material.dart';

import 'package:Obecno/core/constants/all_colors.dart';

class MyButton extends StatefulWidget {
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
    this.choiceIcon,
    this.choiceIconRight,
    this.mhoriz = 0,
    this.mBottom = 0,
    this.mTop = 0,
    this.isactive = true,
    this.fontWeight,
    this.hasicon = false,
    this.hasiconRight = false,
    this.leftWidget,
    this.rightWidget,
    this.isLoadingExternally = false,
  });

  final String buttonText;
  final Future<void> Function()? onTap;

  final double? height, width;
  final double radius;
  final double? fontSize;
  final Color outlineColor;

  final Color? backgroundColor, fontColor;

  final String? choiceIcon, choiceIconRight;

  final double mTop, mBottom, mhoriz;

  final bool isactive;
  final bool hasicon, hasiconRight;

  final FontWeight? fontWeight;

  final Widget? customChild;
  final Widget? leftWidget;
  final Widget? rightWidget;

  /// 🔥 allow external loading control if needed
  final bool isLoadingExternally;

  @override
  State<MyButton> createState() => _MyButtonState();
}

class _MyButtonState extends State<MyButton> {
  bool _isLoading = false;

  bool get _isDisabled =>
      !widget.isactive || _isLoading || widget.isLoadingExternally;

  Future<void> _handleTap() async {
    if (_isDisabled) return;

    setState(() => _isLoading = true);

    try {
      await widget.onTap?.call();
    } catch (e) {
      debugPrint("Button Error: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.backgroundColor ?? kSecondaryButtonColor;

    final Color bgColor = _isDisabled ? baseColor.withOpacity(0.6) : baseColor;

    final Color textColor = _isDisabled
        ? (widget.fontColor ?? kWhite).withOpacity(0.7)
        : (widget.fontColor ?? kWhite);

    return ScrollAnimations.fadeSlide(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastLinearToSlowEaseIn,
      travel: 50,
      child: ButtonAnimations.press(
        onTap: _handleTap,
        child: Container(
          margin: EdgeInsets.only(
            top: widget.mTop,
            bottom: widget.mBottom,
            left: widget.mhoriz,
            right: widget.mhoriz,
          ),
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: widget.outlineColor.withOpacity(_isDisabled ? 0.4 : 1),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.radius),
              onTap: _isDisabled ? null : _handleTap,
              child: Center(
                child: widget.customChild ?? _buildContent(textColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Color textColor) {
    /// 🔥 LOADING STATE
    if (_isLoading || widget.isLoadingExternally) {
      return const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(kWhite),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.hasicon)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child:
                widget.leftWidget ??
                (widget.choiceIcon != null
                    ? Image.asset(widget.choiceIcon!, height: 20)
                    : const SizedBox()),
          ),

        if (widget.hasicon) const SizedBox(width: 10),

        _buildText(textColor),

        if (widget.hasiconRight) const SizedBox(width: 10),

        if (widget.hasiconRight)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child:
                widget.rightWidget ??
                (widget.choiceIconRight != null
                    ? CommonImageView(imagePath: widget.choiceIconRight!)
                    : const SizedBox()),
          ),
      ],
    );
  }

  Widget _buildText(Color textColor) {
    if (widget.fontSize == null && widget.fontWeight == null) {
      return AppText.p3(
        widget.buttonText,
        color: textColor,
        align: TextAlign.center,
      );
    }

    return TextWidget(
      text: widget.buttonText,
      textAlign: TextAlign.center,
      size: widget.fontSize ?? 18,
      letterSpacing: 0.5,
      fontFamily: AppFonts.Poppins,
      color: textColor,
      weight: widget.fontWeight ?? FontWeight.w400,
    );
  }
}
