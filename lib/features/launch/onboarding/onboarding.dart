import 'dart:async';
import 'package:Obecno/features/auth/presentation/screens/login_email.dart';
import 'package:Obecno/features/employee_module/more/presentation/screens/policy.dart';
import 'package:Obecno/features/employee_module/more/presentation/screens/terms.dart';

import 'package:Obecno/core/constants/app_fonts.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/features/launch/book_demo/book_demo.dart';

import 'package:Obecno/shared/widgets/term_text.dart';
import 'package:flutter/material.dart';

import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/generated/assets.dart';

import 'package:Obecno/core/services/token_service.dart';

import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:Obecno/shared/widgets/my_button.dart';
import 'package:Obecno/shared/widgets/text_widget.dart';

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

  /// =========================
  /// SEGMENTED PROGRESS BAR
  /// =========================
  Widget _progressBar() {
    return Row(
      children: List.generate(pages.length, (index) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 4,
            decoration: BoxDecoration(
              color: index <= currentIndex
                  ? kPrimaryColor
                  : kGreyContainerColor,
              borderRadius: BorderRadius.circular(32),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              _progressBar(),

              const SizedBox(height: 20),

              /// 🔥 PAGE VIEW (SWIPEABLE)
              SizedBox(
                height: 550,
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: onPageChanged,
                  itemCount: pages.length,
                  itemBuilder: (context, index) {
                    return Column(
                      children: [
                        AppText.h2(
                          pages[index]["title"]!,
                          fontFamily: AppFonts.Arvo,
                        ),
                        const SizedBox(height: 8),
                        AppText.p1(pages[index]["Subtitle"]!),
                        const SizedBox(height: 16),
                        CommonImageView(
                          imagePath: pages[index]["image"],
                          height: 450,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              /// 🔥 BUTTONS
              MyButton(
                mTop: 20,
                mBottom: 10,
                buttonText: 'Already have an account',
                fontWeight: FontWeight.w400,
                backgroundColor: kPrimaryButtonColor,
                onTap: ()async{
                  await TokenService().markOnboardingCompleted();
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginEmailScreen()),
                  );
                },
              ),

              MyButton(
                mTop: 8,
                mBottom: 16,
                buttonText: 'Book a demo',
                hasiconRight: true,
                fontWeight: FontWeight.w400,
                rightWidget: CommonImageView(
                  imagePath: Assets.imagesRightArrow,
                  height: 12,
                ),
                onTap: () async{
                  await TokenService().markOnboardingCompleted();
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookDemoScreen()),
                  );
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

                textType: AppTextType.p2, // ✅ uses 14 from system
              ),
            ],
          ),
        ),
      ),
    );
  }
}
