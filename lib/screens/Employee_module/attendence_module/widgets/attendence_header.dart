import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/model/attendence_model.dart';
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
        return _MonthYearContent(
          initialDate: initialDate,
          onSelected: onSelected,
        );
      },
    );
  }
}

class _MonthYearContent extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onSelected;

  const _MonthYearContent({
    required this.initialDate,
    required this.onSelected,
  });

  @override
  State<_MonthYearContent> createState() => _MonthYearContentState();
}

class _MonthYearContentState extends State<_MonthYearContent> {
  static const months = [
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

  int selectedMonth = 0;
  int selectedYear = 2000;

  @override
  void initState() {
    selectedMonth = widget.initialDate.month - 1;
    selectedYear = widget.initialDate.year;
    super.initState();
  }

  Widget wheel({
    required int min,
    required int max,
    required int initial,
    required Function(int) onChanged,
    List<String>? labels,
    bool loop = false,
  }) {
    final count = max - min + 1;

    final controller = FixedExtentScrollController(
      initialItem: loop ? (1000 * count + (initial - min)) : (initial - min),
    );

    return SizedBox(
      width: 120,
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          /// 🔥 CENTER HIGHLIGHT (correct position)
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          /// 🔥 WHEEL (moved OUTSIDE container)
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 44,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (val) {
              final index = loop ? (val % count) : val;
              onChanged(min + index);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: loop ? null : count,
              builder: (context, index) {
                final realIndex = loop ? (index % count) : index;

                final text = labels != null
                    ? labels[realIndex]
                    : (min + realIndex).toString();

                return Center(child: AppText.p1(text, weight: FontWeight.w500));
              },
            ),
          ),
        ],
      ),
    );
  }

  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText.h5("Select Month & Year", weight: FontWeight.w600),
                ButtonAnimations.press(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 40),

            Row(
              spacing: 50,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                /// Month (looping)
                wheel(
                  min: 0,
                  max: 11,
                  initial: selectedMonth,
                  labels: months,
                  loop: true,
                  onChanged: (v) => selectedMonth = v,
                ),

                /// Year (NOT looping)
                wheel(
                  min: 1800,
                  max: 4000,
                  initial: selectedYear,
                  loop: false,
                  onChanged: (v) => selectedYear = v,
                ),
              ],
            ),

            const SizedBox(height: 40),

            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: MyButton(
                    backgroundColor: kWhite,
                    buttonText: "Reset",
                    fontColor: kBlack,
                    onTap: () {
                      setState(() {
                        selectedMonth = widget.initialDate.month - 1;
                        selectedYear = widget.initialDate.year;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
                Expanded(
                  child: MyButton(
                    buttonText: "Done",
                    onTap: () {
                      widget.onSelected(
                        DateTime(selectedYear, selectedMonth + 1),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
