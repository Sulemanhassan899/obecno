import 'package:Obecno/core/constants/app_fonts.dart';
import 'package:flutter/material.dart';

import '../core/constants/all_colors.dart';
import 'common_image_view_widget.dart';
import 'text_widget.dart';

class TabButton extends StatelessWidget {
  final String title;
  final String iconPath;
  final String selectedTab;
  final VoidCallback onTap;

  const TabButton({
    super.key,
    required this.title,
    required this.iconPath,
    required this.selectedTab,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isSelected = selectedTab == title;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          gradient: isSelected
              ? kContainerBackgroundGradeintColor
              : const LinearGradient(colors: [kGreyColor6, kGreyColor6]),
        ),
        child: Row(
          spacing: 5,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CommonImageView(imagePath: iconPath, height: 16),
            TextWidget(
              text: title,
              size: 12,
              fontFamily: AppFonts.Poppins,
              paddingRight: 6,
              color: isSelected ? kWhite : kBlack,
              textAlign: TextAlign.start,
              weight: FontWeight.w400,
            ),
          ],
        ),
      ),
    );
  }
}
