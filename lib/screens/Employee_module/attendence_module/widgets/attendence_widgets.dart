

import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/model/attendence_model.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AttendanceSummaryCard extends StatelessWidget {
  const AttendanceSummaryCard({super.key, required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: kWhite,
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  value: "${summary.workingDays}",
                  suffix: " / ${summary.totalDays}",
                  valueColor: kPrimaryColor,
                  label: "Working Days",
                ),
              ),
              const SizedBox(
                height: 40,
                width: 30,
                child: VerticalDivider(width: 1, color: kDividerColor),
              ),
              Expanded(
                child: _StatItem(
                  value: "${summary.absentOrLeaves}",
                  valueColor: kPurple,
                  label: "Absent / Leaves",
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: kDividerColor),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  value: summary.lateCheckIns.toString().padLeft(2, '0'),
                  valueColor: kredColor,
                  label: "Late Check-in",
                ),
              ),
              const SizedBox(
                height: 40,
                width: 30,
                child: VerticalDivider(width: 1, color: kDividerColor),
              ),
              Expanded(
                child: _StatItem(
                  value: "${summary.lateCheckOuts}",
                  valueColor: kPrimaryColor,
                  label: "Late Check-out",
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
  });

  final String value;
  final String? suffix;
  final Color valueColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppText.h5(value, color: valueColor, weight: FontWeight.w600),
            if (suffix != null)
              AppText.h5(suffix!, color: kSubText, weight: FontWeight.w600),
          ],
        ),
        const SizedBox(height: 4),
        AppText.caption(label, color: kGreyColor, weight: FontWeight.w500),
      ],
    );
  }
}

class AttendanceDayTile extends StatelessWidget {
  const AttendanceDayTile({super.key, required this.record, this.onTap});

  final AttendanceDayRecord record;
  final VoidCallback? onTap;

  /// ✅ check invalid checkout
  bool _isInvalidCheckOut(String? value) {
    return value == null || value.trim() == "--:-- PM";
  }

  Widget? _statusIcon() {
    /// ✅ PRIORITY: show warning if checkout is invalid
    if (_isInvalidCheckOut(record.checkOut)) {
      return CommonImageView(
        imagePath: Assets.imagesTriangleExclamation,
        height: 20,
      );
    }

    /// existing logic
    switch (record.status) {
      case AttendanceDayStatus.missingCheckOut:
        return CommonImageView(
          imagePath: Assets.imagesTriangleExclamation,
          height: 20,
        );
      case AttendanceDayStatus.manuallyEdited:
        return CommonImageView(imagePath: Assets.imagesUserPen, height: 20);
      case AttendanceDayStatus.normal:
      case AttendanceDayStatus.weekend:
        return null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _statusIcon();

    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            /// DATE BOX
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kWhite,
                border: Border.all(color: kGreyColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppText.p1("${record.day}", weight: FontWeight.w700),
                  AppText.p2(record.weekday, color: kGreyColor),
                ],
              ),
            ),

            const SizedBox(width: 16),

            /// ✅ STATUS ICON (LEFT SIDE)
            if (icon != null) ...[icon],

            const SizedBox(width: 30),

            /// TIME ROW
            Expanded(
              child: Row(
                spacing: 10,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  /// CHECK-IN
                  AppText.p1(
                    record.checkIn ?? "--:-- AM",
                    weight: FontWeight.w400,
                    color:
                        (record.checkIn == null ||
                            record.checkIn!.trim() == "--:-- AM")
                        ? kredColor
                        : kSubText,
                  ),

                  Row(children: [const _Dot()]),

                  /// CHECK-OUT
                  AppText.p1(
                    record.checkOut ?? "--:-- PM",
                    weight: FontWeight.w400,
                    color:
                        (record.checkOut == null ||
                            record.checkOut!.trim() == "--:-- PM")
                        ? kredColor
                        : kSubText,
                  ),

                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: kGreyColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.circle, size: 7, color: kGreyColor.withOpacity(0.3)),
        Container(width: 20, height: 2, color: kGreyColor.withOpacity(0.3)),
        Icon(Icons.circle, size: 7, color: kGreyColor.withOpacity(0.3)),
      ],
    );
  }
}

class AttendanceWeekendCard extends StatelessWidget {
  const AttendanceWeekendCard({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: kContainerYellowColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          AppText.p1(label.split(",").first, weight: FontWeight.w600),
          SizedBox(height: 6),
          AppText.p5(label.split(",").last.trim(), color: kSubText),
        ],
      ),
    );
  }
}
