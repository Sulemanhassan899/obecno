import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/model/overview_model.dart';
import 'package:Obecno/screens/bottom_sheets/monthly_picker.dart';
import 'package:Obecno/widgets/share_button.dart';
import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/widgets/text_widget.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:Obecno/core/constants/text_styles.dart';

/// =======================================================
/// 🔥 REUSABLE DATE WIDGET
/// =======================================================
class ReusableDateRow extends StatelessWidget {
  final DateTime date;

  const ReusableDateRow({super.key, required this.date});

  String get formattedDate {
    return "${date.day} ${_monthName(date.month)} ${date.year}";
  }

  String _monthName(int month) {
    const months = [
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
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: () {
        MonthYearPickerSheet.show(
          context,
          initialDate: date,
          onSelected: (selectedDate) {
            // Handle selected date
          },
        );
      },
      child: Row(
        children: [
          CommonImageView(imagePath: Assets.imagesCalender, height: 14),
          const SizedBox(width: 8),
          AppText.p1(formattedDate, color: kSubText, weight: FontWeight.w500),
          const SizedBox(width: 6),
          CommonImageView(imagePath: Assets.imagesDown, height: 8),
        ],
      ),
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

/// =======================================================
/// 🔥 HEADER
/// =======================================================
class OverviewHeader extends StatelessWidget {
  const OverviewHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        /// LEFT
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.h2("Today", align: TextAlign.left),

              const SizedBox(height: 10),

              ReusableDateRow(date: DateTime.now()),
            ],
          ),
        ),
      ],
    );
  }
}

class OverviewStatsCard extends StatelessWidget {
  final OverViewMonthSummary summary;

  const OverviewStatsCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  share: false,

                  value: "${summary.workingDays}",
                  suffix: " / ${summary.totalDays}",
                  valueColor: kPrimaryColor,
                  label: "Present Today",
                ),
              ),
              const SizedBox(
                height: 50,
                child: VerticalDivider(color: kDividerColor),
              ),

              Expanded(
                child: _StatItem(
                  share: true,

                  value: "${summary.absentOrLeaves}",
                  valueColor: kPurple,
                  label: "Active",
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(color: kDividerColor),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _StatItem(
                  share: true,

                  value: summary.lateCheckIns.toString().padLeft(2, '0'),
                  valueColor: kYellowColor,
                  label: "On Break",
                ),
              ),
              const SizedBox(
                height: 50,
                child: VerticalDivider(color: kDividerColor),
              ),
              Expanded(
                child: _StatItem(
                  share: true,

                  value: "${summary.lateCheckOuts}",
                  valueColor: kredColor,
                  label: "Late Check-in",
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(color: kDividerColor),
          const SizedBox(height: 10),

          /// LAST ROW SINGLE ITEM
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  share: true,
                  value: "03",
                  valueColor: kBlack,
                  label: "Absent",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.valueColor,
    required this.label,
    this.suffix,
    required this.share,
  });

  final String value;
  final String? suffix;
  final Color valueColor;
  final String label;
  final bool share;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        /// TEXT SIDE
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppText.h3(value, color: valueColor),
                  if (suffix != null) AppText.h3(suffix!, color: kSubText),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppText.caption(
                    label,
                    color: kGreyColor,
                    weight: FontWeight.w500,
                  ),
                  share == true
                      ? ShareButton(onTap: () {})
                      : SizedBox(width: 10),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: 20),
      ],
    );
  }
}

/// =======================================================
/// 🔥 ACTION GRID
/// =======================================================
class OverviewActionsGrid extends StatelessWidget {
  const OverviewActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GridView.count(
        padding: EdgeInsets.all(0),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
        childAspectRatio: 2,
        children: [
          ActionTile("Add Location", Assets.imagesAddLocationIcon, () {}),
          ActionTile("All Locations", Assets.imagesLocationIcon, () {}),
          ActionTile("Add Employee", Assets.imagesAddEmployee, () {}),
          ActionTile("All Employee", Assets.imagesAllEmployees, () {}),
        ],
      ),
    );
  }
}

/// =======================================================
/// 🔥 ACTION TILE
/// =======================================================
class ActionTile extends StatelessWidget {
  final String title;
  final String icon;
  VoidCallback? onTap;

  ActionTile(this.title, this.icon, VoidCallback onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CommonImageView(imagePath: icon, height: 20),
            const SizedBox(height: 10),
            AppText.p2(title, color: kSubText, weight: FontWeight.w500),
          ],
        ),
      ),
    );
  }
}
