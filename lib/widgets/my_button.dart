import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/animations/scroll_animations.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

import 'package:Obecno/core/constants/all_colors.dart';

enum MyButtonSize { big, normal }

class MyButton extends StatefulWidget {
  const MyButton({
    super.key,
    required this.onTap,
    required this.buttonText,
    this.size = MyButtonSize.big,
    this.height = 48,
    this.width,
    this.backgroundColor,
    this.fontColor,
    this.customChild,
    this.outlineColor = kBorderColor,
    this.radius = 50,
    this.choiceIcon,
    this.choiceIconRight,
    this.mhoriz = 0,
    this.mBottom = 0,
    this.mTop = 0,
    this.isactive = true,
    this.hasicon = false,
    this.hasiconRight = false,
    this.leftWidget,
    this.rightWidget,
    this.isLoadingExternally = false,
    this.compact = false,
  });

  static const double defaultHeight = 48;

  final String buttonText;
  final Future<void> Function()? onTap;
  final MyButtonSize size;

  final double height;
  final double? width;
  final double radius;
  final Color outlineColor;

  final Color? backgroundColor, fontColor;

  final String? choiceIcon, choiceIconRight;

  final double mTop, mBottom, mhoriz;

  final bool isactive;
  final bool hasicon, hasiconRight;

  final Widget? customChild;
  final Widget? leftWidget;
  final Widget? rightWidget;

  /// 🔥 allow external loading control if needed
  final bool isLoadingExternally;

  /// When true, the button hugs its label instead of expanding to the parent.
  final bool compact;

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

  /// Filled buttons (non-white bg) use a matching border so gray outlines
  /// don't show around green/red/black CTAs. White/outlined buttons keep
  /// [outlineColor].
  Color get _resolvedBorderColor {
    final bg = widget.backgroundColor;
    if (bg != null && bg != kWhite && bg != kTransperentColor) {
      return bg;
    }
    return widget.outlineColor;
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.backgroundColor ?? kSecondaryButtonColor;

    final Color bgColor = _isDisabled ? baseColor.withOpacity(0.6) : baseColor;

    final Color textColor = _isDisabled
        ? (widget.fontColor ?? kWhite).withOpacity(0.7)
        : (widget.fontColor ?? kWhite);

    final Color borderColor = _resolvedBorderColor.withOpacity(
      _isDisabled ? 0.4 : 1,
    );

    final button = Container(
      margin: EdgeInsets.only(
        top: widget.mTop,
        bottom: widget.mBottom,
        left: widget.mhoriz,
        right: widget.mhoriz,
      ),
      height: widget.height,
      width: widget.compact ? null : widget.width,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.radius),
          onTap: _isDisabled ? null : _handleTap,
          child: widget.compact
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: widget.customChild ?? _buildContent(textColor),
                )
              : Center(child: widget.customChild ?? _buildContent(textColor)),
        ),
      ),
    );

    return ScrollAnimations.fadeSlide(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastLinearToSlowEaseIn,
      travel: 50,
      child: ButtonAnimations.press(
        onTap: _handleTap,
        child: widget.compact
            ? Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: button,
              )
            : button,
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 0 : 12),
      child: Row(
        mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.hasicon)
            widget.leftWidget ??
                (widget.choiceIcon != null
                    ? Image.asset(widget.choiceIcon!, height: 20)
                    : const SizedBox()),

          if (widget.hasicon) const SizedBox(width: 8),

          widget.compact
              ? _buildText(textColor)
              : Flexible(child: _buildText(textColor)),

          if (widget.hasiconRight) const SizedBox(width: 8),

          if (widget.hasiconRight)
            widget.rightWidget ??
                (widget.choiceIconRight != null
                    ? CommonImageView(imagePath: widget.choiceIconRight!)
                    : const SizedBox()),
        ],
      ),
    );
  }

  Widget _buildText(Color textColor) {
    if (widget.size == MyButtonSize.normal) {
      return AppText.ButtonTextSmall(
        widget.buttonText,
        color: textColor,
        align: TextAlign.center,
      );
    }

    return AppText.ButtonText(
      widget.buttonText,
      color: textColor,
      align: TextAlign.center,
    );
  }
}
