import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/generated/assets.dart';
import 'package:Obecno/shared/bottom_sheets/edit_sheets/monthly_picker.dart';

import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AttendanceMonthHeader extends StatelessWidget {
  const AttendanceMonthHeader({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    this.onTapDropdown,
    this.isNextEnabled = true,
    this.isPreviousEnabled = true,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onTapDropdown;

  final bool isNextEnabled;
  final bool isPreviousEnabled;

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
        Opacity(
          opacity: isPreviousEnabled ? 1 : 0.3,
          child: IgnorePointer(
            ignoring: !isPreviousEnabled,
            child: ButtonAnimations.press(
              onTap: () {
                onPrevious();
              },
              child: const Icon(CupertinoIcons.left_chevron, color: kBlack),
            ),
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
        Opacity(
          opacity: isNextEnabled ? 1 : 0.3,
          child: IgnorePointer(
            ignoring: !isNextEnabled,
            child: ButtonAnimations.press(
              onTap: () {
                onNext();
              },
              child: const Icon(CupertinoIcons.chevron_right, color: kBlack),
            ),
          ),
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
    DateTime? minDate,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // important for rounded corners
      isScrollControlled: true, // 🔥 REQUIRED
      builder: (_) {
        return Wrap(
          children: [
            MonthYearContent(
              initialDate: initialDate,
              onSelected: onSelected,
              minDate: minDate,
            ),
          ],
        );
      },
    );
  }
}
