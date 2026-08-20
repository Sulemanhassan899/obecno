import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/features/launch/onboarding/onboarding.dart';
import 'package:obecno/core/generated/assets.dart';

import 'package:obecno/widgets/bottom_sheet.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class ForgotPasswordSheet extends StatelessWidget {
  const ForgotPasswordSheet({super.key, required this.email});

  final String email;

  /// ✅ UPDATED SHOW METHOD
  static void show(BuildContext context, String email) {
    CommonBottomSheet.show(
      context: context,
      height: 520,
      buttonText: "",
      onButtonTap: () {},
      children: [_ForgotPasswordContent(email: email)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ForgotPasswordContent(email: email);
  }
}

class _ForgotPasswordContent extends StatelessWidget {
  const _ForgotPasswordContent({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ButtonAnimations.press(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 40),

        CommonImageView(imagePath: Assets.imagesForgotPassEmail, height: 100),

        const SizedBox(height: 20),

        AppText.h3("Check your email"),

        const SizedBox(height: 20),

        /// ✅ DYNAMIC EMAIL
        AppText.p1(
          "You will receive instruction on $email in a few minutes.",
          color: kSubText,
          weight: FontWeight.w400,
        ),

        const SizedBox(height: 40),

        MyButton(
          mTop: 8,
          mhoriz: 40,
          mBottom: 20,
          buttonText: "Sign in",
          backgroundColor: kBlack,
          fontColor: kWhite,
          onTap: () async {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const OnBoardingScreen()),
              (route) => false,
            );
          },
        ),

        AppText.p2(
          "Need help? Contact support",
          color: kBlue,
          weight: FontWeight.w400,
        ),
      ],
    );
  }
}
