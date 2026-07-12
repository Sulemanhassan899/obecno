import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/screens/auth/login_pass.dart';
import 'package:Obecno/screens/launch/onboarding/onboarding.dart';
import 'package:Obecno/widgets/bottom_sheet.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class ForgotPasswordSheet extends StatelessWidget {
  const ForgotPasswordSheet({super.key});

  /// ✅ SHOW METHOD (THIS IS WHAT YOU NEED)
  static void show(BuildContext context) {
    CommonBottomSheet.show(
      context: context,
      height: 520,
      buttonText: "",
      onButtonTap: () {},
      children: const [_ForgotPasswordContent()],
    );
  }

  @override
  Widget build(BuildContext context) {
    return const _ForgotPasswordContent();
  }
}

class _ForgotPasswordContent extends StatelessWidget {
  const _ForgotPasswordContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // ✅ important for bottom sheet
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

        AppText.p1(
          "You will receive instruction on your given [email/phone] in a few minutes.",
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
          onTap: () async{
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
