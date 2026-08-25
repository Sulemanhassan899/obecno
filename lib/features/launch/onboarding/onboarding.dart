import 'dart:async';
import 'package:obecno/features/employee_module/more/presentation/screens/policy.dart';
import 'package:obecno/features/employee_module/more/presentation/screens/terms.dart';

import 'package:obecno/core/constants/app_fonts.dart';
import 'package:obecno/core/constants/text_styles.dart';

import 'package:obecno/widgets/term_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/generated/assets.dart';

import 'package:obecno/core/services/token_service.dart';

import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  final PageController _controller = PageController();

  int currentIndex = 0;
  Timer? timer;

  final List<Map<String, String>> pages = [
    {
      "title": "Attendance Simplified",
      "Subtitle":
          "Track attendance across all locations or remote teams in one clear, organized view.",
      "image": Assets.imagesOnboarding1,
    },
    {
      "title": "Check In & Out",
      "Subtitle":
          "Clock in, take breaks, and check out with a simple tap — accurate, fast, and location-aware.",
      "image": Assets.imagesOnboarding2,
    },
    {
      "title": "Office & Locations",
      "Subtitle":
          "Offices, branches, and remote sites so attendance is always tracked from the right place.",
      "image": Assets.imagesOnboarding3,
    },
    {
      "title": "See Attendance Clearly",
      "Subtitle":
          "Daily records, late check-ins, absences, and working days in one clean view.",
      "image": Assets.imagesOnboarding4,
    },
    {
      "title": "Secure Device Access",
      "Subtitle":
          "Approve trusted phones, and prevent attendance from unknown devices.",
      "image": Assets.imagesOnboarding5,
    },
  ];

  @override
  void initState() {
    super.initState();
    startAutoScroll();
  }

  void startAutoScroll() {
    timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (currentIndex < pages.length - 1) {
        currentIndex++;
      } else {
        currentIndex = 0;
      }

      _controller.animateToPage(
        currentIndex,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
      );

      setState(() {});
    });
  }

  void onPageChanged(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _progressBar() {
    return Row(
      children: List.generate(pages.length, (index) {
        final bool isCompleted = index < currentIndex;
        final bool isActive = index == currentIndex;

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 4,
            decoration: BoxDecoration(
              color: kGreyContainerColor,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Stack(
              children: [
                // Completed (fully filled)
                if (isCompleted)
                  AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 2000,
                    ), // slightly slower
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),

                // Active (slow loading animation)
                if (isActive)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(
                      milliseconds: 2500,
                    ), // ⬅️ slower here
                    curve: Curves.easeInOutCubic, // smoother feel
                    builder: (context, value, child) {
                      return FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          decoration: BoxDecoration(
                            color: kPrimaryColor,
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isTablet = screenSize.shortestSide >= 600;
    final double horizontalPadding = isTablet ? 32 : 10;
    final double titleSpacing = screenSize.height * 0.015;
    final double sectionSpacing = screenSize.height * 0.02;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
        ).add(AppSizes.DEFAULT),
        child: Column(
          children: [
            SizedBox(height: sectionSpacing),
            _progressBar(),
            SizedBox(height: sectionSpacing),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: onPageChanged,
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          AppText.h2(
                            pages[index]["title"]!,
                            fontFamily: AppFonts.Arvo,
                          ),
                          SizedBox(height: titleSpacing * 0.5),
                          AppText.p1(pages[index]["Subtitle"]!),
                          SizedBox(height: titleSpacing),
                          Expanded(
                            child: Center(
                              child: CommonImageView(
                                imagePath: pages[index]["image"],
                                height: constraints.maxHeight,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: sectionSpacing * 0.5),
            MyButton(
              mTop: 10,
              mBottom: 10,
              buttonText: 'Already have an account',
              backgroundColor: kPrimaryButtonColor,
              onTap: () async {
                await TokenService().markOnboardingCompleted();
                if (!context.mounted) return;
                context.push('/login');
              },
            ),

            MyButton(
              mTop: 4,
              mBottom: 12,
              buttonText: 'Book a demo',
              hasiconRight: true,
              rightWidget: CommonImageView(
                imagePath: Assets.imagesRightArrow,
                height: 12,
              ),
              onTap: () async {
                await TokenService().markOnboardingCompleted();
                if (!context.mounted) return;
                context.push('/bookdemo');
              },
            ),

            CustomRichText(
              textAlign: TextAlign.center,
              prefixText: "By continuing, you agree to accept our ",
              linkText1: "Terms of Use",
              middleText: " and ",
              linkText2: "Privacy policy",
              suffixText: ".",

              onTap1: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TermsScreen()),
                );
              },
              onTap2: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PolicyScreen()),
                );
              },

              textType: AppTextType.p2,
            ),
            SizedBox(height: sectionSpacing * 0.3),
          ],
        ),
      ),
    );
  }
}
