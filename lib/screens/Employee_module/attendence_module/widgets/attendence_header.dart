import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/model/attendence_model.dart';
import 'package:Obecno/screens/bottom_sheets/monthly_picker.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/widgets/my_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AttendanceMonthHeader extends StatelessWidget {
  const AttendanceMonthHeader({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    this.onTapDropdown,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onTapDropdown;

  static const _monthNames = [
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

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ButtonAnimations.press(
          onTap: () {
            onPrevious();
          },
          child: GestureDetector(
            child: const Icon(CupertinoIcons.left_chevron, color: kBlack),
          ),
        ),
        ButtonAnimations.press(
          onTap: onTapDropdown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CommonImageView(imagePath: Assets.imagesCalender, height: 18),
              const SizedBox(width: 8),
              AppText.p3(
                "${_monthNames[month.month - 1]} ${month.year}",
                weight: FontWeight.w400,
                color: kSubText,
              ),
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.chevron_down, size: 20, color: kBlack),
            ],
          ),
        ),
        ButtonAnimations.press(
          onTap: () {
            onNext();
          },
          child: const Icon(CupertinoIcons.chevron_right, color: kBlack),
        ),
      ],
    );
  }
}

class MonthYearPickerSheet {
  static void show(
    BuildContext context, {
    required DateTime initialDate,
    required Function(DateTime) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kWhite,
      builder: (_) {
        return MonthYearContent(
          initialDate: initialDate,
          onSelected: onSelected,
        );
      },
    );
  }
}
