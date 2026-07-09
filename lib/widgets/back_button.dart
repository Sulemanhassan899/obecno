import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/widgets/back_button.dart';

class BackButtonBg extends StatelessWidget {
  const BackButtonBg({
    super.key,
    this.title,
    this.showBack = true,
    this.rightWidget,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  /// 🔹 OPTIONAL TITLE
  final String? title;

  /// 🔹 BACK BUTTON CONTROL
  final bool showBack;

  /// 🔹 OPTIONAL RIGHT WIDGET (icon / button)
  final Widget? rightWidget;

  /// 🔹 PADDING CONTROL
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack)
          ButtonAnimations.press(
            onTap: () => Navigator.pop(context),

            child: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: kGreyContainerColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back, size: 16),
            ),
          )
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
