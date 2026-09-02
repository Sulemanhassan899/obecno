import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AttendanceSummaryCard extends StatefulWidget {
  const AttendanceSummaryCard({super.key, required this.summary});

  final MonthSummary summary;

  @override
  State<AttendanceSummaryCard> createState() => _AttendanceSummaryCardState();
}

class _AttendanceSummaryCardState extends State<AttendanceSummaryCard> {
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
                  value: "${widget.summary.workingDays}",
                  suffix: " / ${widget.summary.totalDays}",
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
                  value: "${widget.summary.absentOrLeaves}",
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
                  value: widget.summary.lateCheckIns.toString().padLeft(2, '0'),
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
                  value: "${widget.summary.lateCheckOuts}",
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

  bool _isInvalidCheckOut(String? value) {
    return value == null || value.trim() == "--:-- PM";
  }

  bool get _isOnLeave =>
      record.status == AttendanceDayStatus.onLeave ||
      record.checkIn == "Leave" ||
      record.checkOut == "Leave";

  bool get _isAbsent =>
      record.status == AttendanceDayStatus.absent ||
      (!_isOnLeave &&
          record.status != AttendanceDayStatus.holiday &&
          record.status != AttendanceDayStatus.weekend &&
          !_hasPunchTime(record.checkIn) &&
          !_hasPunchTime(record.checkOut));

  bool _hasPunchTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return false;
    final lower = value.toLowerCase();
    return lower != 'leave' &&
        lower != 'holiday' &&
        lower != '--' &&
        !lower.startsWith('--:--');
  }

  bool _isHolidayOrLeave() {
    return _isOnLeave ||
        _isAbsent ||
        record.status == AttendanceDayStatus.holiday ||
        record.checkIn == "Holiday" ||
        record.checkOut == "Holiday";
  }

  Widget? _statusIcon() {
    if (_isHolidayOrLeave()) {
      return null;
    }

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
      case AttendanceDayStatus.onLeave:
      case AttendanceDayStatus.absent:
      case AttendanceDayStatus.holiday:
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

            /// TIME / ON LEAVE ROW
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isAbsent) ...[
                    const _EmptyAttendanceMark(),
                  ] else if (_isOnLeave) ...[
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: kGreyColor.withOpacity(0.3),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F1FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: AppText.p2(
                        "On Leave",
                        color: Color(0xFF6B9EFF),
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 18,
                      color: kGreyColor,
                    ),
                  ] else ...[
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

                    const SizedBox(width: 10),
                    const _Dot(),
                    const SizedBox(width: 10),

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

                    const SizedBox(width: 10),
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 18,
                      color: kGreyColor,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAttendanceMark extends StatelessWidget {
  const _EmptyAttendanceMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kGreyColor.withOpacity(0.2),
      ),
      child: AppText.caption("-", color: kGreyColor, weight: FontWeight.w500),
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

class AttendanceHolidayCard extends StatelessWidget {
  const AttendanceHolidayCard({
    super.key,
    required this.title,
    required this.date,
    this.onTap,
  });

  final String title;
  final String date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ButtonAnimations.press(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            AppText.h5(
              title,
              weight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
            const SizedBox(height: 6),
            AppText.p2(date, color: kSubText, weight: FontWeight.w400),
          ],
        ),
      ),
    );
  }
}
