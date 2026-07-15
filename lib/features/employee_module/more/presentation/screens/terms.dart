import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/shared/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/shared/widgets/my_button.dart';
import 'package:Obecno/core/constants/text_styles.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: AppSizes.DEFAULT,
        children: [
          const SizedBox(height: 20),

          /// HEADER
          BackButtonBg(),

          const SizedBox(height: 20),

          /// TITLE
          AppText.h1("Terms of Use", align: TextAlign.left),

          const SizedBox(height: 6),

          /// DATE
          AppText.p2(
            "Last updated: [Insert date]",
            color: kGreyColor,
            align: TextAlign.left,
          ),

          const SizedBox(height: 20),

          _termsContent(),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _termsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.h6(
          "Welcome to our attendance management application (“App”, “we”, “our”, or “us”). By accessing or using this App, you agree to be bound by these Terms of Use. If you do not agree, please do not use the App.",
          align: TextAlign.left,
        ),

        const SizedBox(height: 10),

        _sectionTitle("1. Use of the App"),
        AppText.h6(
          weight: FontWeight.w400,
          "The App is provided to help employees and organizations manage attendance, including check-ins, check-outs, breaks, leaves, and related activities.",
          align: TextAlign.left,
        ),
        const SizedBox(height: 4),
        _bulletList([
          "For lawful purposes",
          "In accordance with employer policies",
          "In compliance with these terms",
        ]),

        _sectionTitle("2. User Accounts"),
        _bulletList([
          "Maintain confidentiality of credentials",
          "Responsible for all account activities",
        ]),

        _sectionTitle("3. Attendance Accuracy"),
        _bulletList([
          "Provide accurate information",
          "Use only approved devices",
          "Follow organization policies",
        ]),

        _sectionTitle("4. Permissions & Access"),
        _bulletList([
          "Location access",
          "Notifications",
          "Camera (if enabled)",
          "Biometric authentication",
        ]),

        _sectionTitle("5. Employer & Admin Control"),
        _bulletList([
          "Configure rules",
          "Access attendance data",
          "Approve/reject requests",
        ]),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: AppText.h5(text, align: TextAlign.left, weight: FontWeight.w600),
    );
  }

  Widget _bulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 5, top: 5),
              child: Row(
                spacing: 6,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.circle, size: 6),

                  Expanded(
                    child: AppText.h6(
                      e,
                      align: TextAlign.left,
                      weight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
