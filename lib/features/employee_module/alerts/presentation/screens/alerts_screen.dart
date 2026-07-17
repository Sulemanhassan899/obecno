import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/shared/bottom_sheets/hoilday_detail_sheet.dart';
import 'package:Obecno/shared/widgets/bottom_sheet.dart';
import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:Obecno/shared/widgets/my_button.dart';
import 'package:flutter/material.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              CommonImageView(
                imagePath: Assets.imagesCalendarStar,
                height: 125,
              ),
              const SizedBox(height: 20),
              AppText.h1("Alerts Coming soon", weight: FontWeight.w600),
            ],
          ),
        ),
      ),
    );
  }
}
