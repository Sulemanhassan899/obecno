import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/api/api_client.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/shared/bottom_sheets/attendance_sheet/add_attendance_bottom_sheet.dart';

import 'package:Obecno/widgets/bottom_sheet.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/material.dart';

class HolidayBottomSheet extends StatefulWidget {
  final DateTime day;
  final String title;
  final ApiClient apiClient;
  final String userEmail;

  const HolidayBottomSheet({
    super.key,
    required this.day,
    required this.title,
    required this.apiClient,
    required this.userEmail,
  });

  static void show(
    BuildContext context, {
    required DateTime day,
    required String title,
    required ApiClient apiClient,
    required String userEmail,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: HolidayBottomSheet(
            day: day,
            title: title,
            apiClient: apiClient,
            userEmail: userEmail,
          ),
        );
      },
    );
  }

  @override
  State<HolidayBottomSheet> createState() => _HolidayBottomSheetState();
}

class _HolidayBottomSheetState extends State<HolidayBottomSheet> {
  static const _months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];
  static const _monthsShort = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];
  static const _weekdaysShort = [
    "Mon",
    "Tue",
    "Wed",
    "Thu",
    "Fri",
    "Sat",
    "Sun",
  ];

  String get _headerDate =>
      "${widget.day.day} ${_months[widget.day.month - 1]} ${widget.day.year}";

  String get _subDate =>
      "${_weekdaysShort[widget.day.weekday - 1]}, ${widget.day.day} ${_monthsShort[widget.day.month - 1]} ${widget.day.year}";

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            AppText.h5(_headerDate),
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
        AppText.h3(widget.title),
        const SizedBox(height: 20),
        AppText.p1(_subDate, color: kSubText, weight: FontWeight.w400),
        const SizedBox(height: 40),
        MyButton(
          mTop: 8,
          mhoriz: 40,
          mBottom: 49,
          buttonText: "Add Attendance",
          backgroundColor: kWhite,
          fontColor: kBlack,
          onTap: () async {
            Navigator.pop(context);
            Future.delayed(Duration.zero, () {
              AddAttendanceBottomSheet.show(
                context,
                day: widget.day,
                apiClient: widget.apiClient,
                userEmail: widget.userEmail,
              );
            });
          },
        ),
      ],
    );
  }
}
