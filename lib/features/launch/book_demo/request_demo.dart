import 'dart:async';

import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/features/launch/onboarding/onboarding.dart';
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    child: BackButtonBg(),
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
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) =>
                          OnBoardingScreen(), // 👈 replace with your screen
                    ),
                    (Route<dynamic> route) =>
                        false, // 👈 removes all previous routes
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
