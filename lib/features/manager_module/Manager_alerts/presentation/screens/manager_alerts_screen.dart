import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/material.dart';

class ManagerAlertsScreen extends StatefulWidget {
  const ManagerAlertsScreen({super.key});

  @override
  State<ManagerAlertsScreen> createState() => _ManagerAlertsScreenState();
}

class _ManagerAlertsScreenState extends State<ManagerAlertsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kbackground1,
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
