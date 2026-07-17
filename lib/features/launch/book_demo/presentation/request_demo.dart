import 'dart:async';

import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';

import 'package:Obecno/shared/widgets/back_button.dart';
import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:Obecno/shared/widgets/my_button.dart';
import 'package:Obecno/shared/widgets/text_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DemoRequestScreen extends StatefulWidget {
  const DemoRequestScreen({super.key});

  @override
  State<DemoRequestScreen> createState() => _DemoRequestScreenState();
}

class _DemoRequestScreenState extends State<DemoRequestScreen> {
  /// This screen is reached via `Navigator.push` from `BookDemoScreen`,
  /// which itself sits on a route entered with `context.go('/bookdemo')`.
  /// Relying on `BackButtonBg`'s default `Navigator.pop(context)` is what
  /// made this button appear dead: depending on how deep/shallow the
  /// pushed stack is at the time this builds, there can be nothing left
  /// for a plain pop to reveal, so Flutter just no-ops instead of
  /// throwing anything visible. Sending it straight back to onboarding
  /// (same destination as the form's own back button) removes that
  /// ambiguity entirely.
  void _backToOnboarding(BuildContext context) {
    if (!context.mounted) return;
    try {
      context.go('/onboarding');
    } catch (_) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _backToOnboarding(context);
      },
      child: Scaffold(
        body: Padding(
          padding: AppSizes.DEFAULT,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),

                    /// BACK
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: BackButtonBg(
                        onTap: () => _backToOnboarding(context),
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(height: 16),
                    CommonImageView(
                      imagePath: Assets.imagesDemoReq,
                      height: 200,
                      width: 400,
                    ),
                    AppText.h4("Demo Request Sent"),
                    SizedBox(height: 8),
                    AppText.p2(
                      "Thanks for your interest!",
                      color: kGreyColor,
                      weight: FontWeight.w400,
                    ),
                    SizedBox(height: 8),
                    AppText.p2(
                      "Our team has received your request and will contact you shortly to schedule your demo.",
                      color: kGreyColor,
                      weight: FontWeight.w400,
                    ),
                  ],
                ),
                MyButton(
                  mTop: 8,
                  mBottom: 16,
                  buttonText: "Close",
                  backgroundColor: kWhite,
                  fontColor: kBlack,
                  onTap: () async {
                    _backToOnboarding(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
