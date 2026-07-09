import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/screens/bottom_sheets/add_attendance_bottom_sheet.dart';
import 'package:Obecno/widgets/bottom_sheet.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class HolidayBottomSheet extends StatefulWidget {
  const HolidayBottomSheet({super.key});

  @override
  State<HolidayBottomSheet> createState() => _HolidayBottomSheetState();
}

class _HolidayBottomSheetState extends State<HolidayBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            AppText.h5("12 October 2025"),
            const Spacer(),
            ButtonAnimations.press(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 40),
        CommonImageView(imagePath: Assets.imagesCalendarStar, height: 125),
        const SizedBox(height: 20),
        AppText.h3("National Day"),
        const SizedBox(height: 20),
        AppText.p1(
          "Sat, 12 Oct 2025",
          color: kSubText,
          weight: FontWeight.w400,
        ),
        const SizedBox(height: 40),
        MyButton(
          mTop: 8,
          mhoriz: 40,
          mBottom: 49,
          buttonText: "Add Attendance",
          backgroundColor: kWhite,
          fontColor: kBlack,
          onTap: () {
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class AddAttendanceBottomSheet {
  static void show(BuildContext context) {
    CommonBottomSheet.show(
      context: context,
      height: 750,
      buttonText: "",
      onButtonTap: () {
        // Navigator.pop(context);
      },
      children: [],
    );
  }
}
