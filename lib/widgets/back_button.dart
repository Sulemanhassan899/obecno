import 'package:flutter/material.dart';
import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';

/// 42px grey circle used for back on every screen and sheet.
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({
    super.key,
    this.onTap,
    this.icon = Icons.arrow_back,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final IconData icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: !enabled ? null : (onTap ?? () => Navigator.pop(context)),
      child: Container(
        height: 42,
        width: 42,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: kGreyContainerColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: kBlack),
      ),
    );
  }
}

class BackButtonBg extends StatelessWidget {
  const BackButtonBg({
    super.key,
    this.title,
    this.showBack = true,
    this.rightWidget,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.onTap,
  });

  /// 🔹 OPTIONAL TITLE
  final String? title;

  /// 🔹 BACK BUTTON CONTROL
  final bool showBack;

  /// 🔹 OPTIONAL RIGHT WIDGET (icon / button)
  final Widget? rightWidget;

  /// 🔹 PADDING CONTROL
  final EdgeInsets padding;

  /// 🔹 OPTIONAL TAP OVERRIDE -- defaults to `Navigator.pop(context)`.
  /// Pass this on screens that are the root of their own Navigator stack
  /// (reached via `context.go(...)`, e.g. login_email.dart, book_demo.dart)
  /// where a plain pop has nothing to pop back to.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack)
          BackCircleButton(onTap: onTap)
        else
          const SizedBox(width: 42),

        /// 🔹 CENTER TITLE (ONLY IF PROVIDED)
        if (title != null)
          Expanded(
            child: Center(child: AppText.h6(title!, weight: FontWeight.w600)),
          )
        else
          const Spacer(),

        /// 🔹 RIGHT WIDGET (ONLY IF PROVIDED)
        if (rightWidget != null) rightWidget! else const SizedBox(width: 42),
      ],
    );
  }
}
