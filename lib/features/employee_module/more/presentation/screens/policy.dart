import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/shared/widgets/back_button.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/shared/widgets/my_button.dart';
import 'package:Obecno/core/constants/text_styles.dart';

class PolicyScreen extends StatefulWidget {
  const PolicyScreen({super.key});

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  @override
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
          AppText.h1("Privacy Policy", align: TextAlign.left),

          const SizedBox(height: 6),

          /// DATE
          AppText.p2(
            "Last updated: [Insert date]",
            color: kGreyColor,
            align: TextAlign.left,
          ),

          const SizedBox(height: 16),

          _privacyContent(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }



  Widget _privacyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.h6(
          weight: FontWeight.w400,
          "This Privacy Policy explains how we collect, use, disclose, and protect your information when you use our attendance management application (“App”, “we”, “our”, or “us”). By using this App, you agree to the collection and use of information in accordance with this policy.",
          align: TextAlign.left,
        ),

        _sectionTitle("1. Information We Collect"),

        _subSection("a. Personal Information", [
          "Name",
          "Email address",
          "Phone number",
          "Employee ID",
          "Profile photo (if uploaded)",
        ]),
        const SizedBox(height: 16),
        _subSection("b. Attendance & Work Data", [
          "Check-in and check-out times",
          "Break times",
          "Attendance corrections",
          "Leave requests and approvals",
          "Assigned office/location",
        ]),
        const SizedBox(height: 16),
        _subSection("c. Device Information", [
          "Device type and operating system",
          "Unique device identifiers",
          "App usage information",
        ]),

        _subSection(
          "d. Location Information",
          [
            "Location-based check-in and check-out",
            "Office/site verification",
            "Entry/exit reminders",
          ],
          description:
              "Location data is collected only when required and based on your permissions.",
        ),
        const SizedBox(height: 16),
        _subSection("e. Notifications", [
          "Attendance reminders",
          "Alerts for missed actions",
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

  Widget _subSection(
    String title,
    List<String> bullets, {
    String? description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.h6(title, align: TextAlign.left),
        const SizedBox(height: 6),
        if (description != null) AppText.p2(description, align: TextAlign.left),
        _bulletList(bullets),
        const SizedBox(height: 12),
      ],
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
