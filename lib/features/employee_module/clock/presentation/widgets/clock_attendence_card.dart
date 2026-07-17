
import 'dart:async';
import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/features/employee_module/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:Obecno/shared/bottom_sheets/clock_attendance_details_sheet.dart';

import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/shared/widgets/common_image_view_widget.dart';

class AttendanceCard extends StatefulWidget {
  final DateTime day;
  final List<AttendanceEvent> events;
  final VoidCallback? onEditAttendance;

  const AttendanceCard({
    super.key,
    required this.day,
    required this.events,
    this.onEditAttendance,
  });

  @override
  State<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<AttendanceCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  late AttendanceSummary _summary;

  @override
  void initState() {
    super.initState();
    _recompute();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant AttendanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recompute();
    _startTimer();
  }

  void _recompute() {
    _summary = AttendanceEngine.compute(widget.events);
    _elapsed = _summary.liveWorkingDuration();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _summary = AttendanceEngine.compute(widget.events);
        _elapsed = _summary.liveWorkingDuration();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String formatTime(DateTime? time) => AttendanceFormat.time(time);

  // CHANGED: was `AttendanceFormat.duration(d)` -- now formatted locally
  // as "Hh Mm Ss", e.g. "2h 05m 09s", so it always reads as
  // hour / minutes / seconds regardless of what AttendanceFormat.duration
  // used to produce.
  String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return "${hours}h ${mm}m ${ss}s";
  }

  void _openDetails() {
    ClockAttendanceDetailsSheet.show(
      context: context,
      day: widget.day,
      events: widget.events,
      summary: _summary,
      onEditAttendance: widget.onEditAttendance,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstCheckIn = _summary.firstCheckIn;
    final lastCheckOut = _summary.lastCheckOut;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                /// FIRST CHECK-IN
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText.p2("Check-In", color: kPrimaryColor),
                      const SizedBox(height: 4),
                      AppText.h4(
                        formatTime(firstCheckIn),
                        color: kPrimaryColor,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          CommonImageView(
                            imagePath: Assets.imagesLocationDot,
                            height: 12,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: AppText.p2(
                              "Head Office",
                              color: kGreyColor,
                              weight: FontWeight.w500,
                              align: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                /// TOTAL WORKING DURATION
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: kGreyColor.withOpacity(0.3),
                    ),
                    Container(
                      width: 20,
                      height: 2,
                      color: kGreyColor.withOpacity(0.3),
                    ),
                    const SizedBox(width: 6),
                    AppText.p2(
                      firstCheckIn == null ? "--" : formatDuration(_elapsed),
                      weight: FontWeight.w600,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 20,
                      height: 2,
                      color: kGreyColor.withOpacity(0.3),
                    ),
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: kGreyColor.withOpacity(0.3),
                    ),
                  ],
                ),

                /// LAST CHECK-OUT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppText.p2("Check-Out", color: kredColor),
                      const SizedBox(height: 4),
                      AppText.h4(formatTime(lastCheckOut), color: kredColor),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: AppText.p2(
                              lastCheckOut == null ? "--" : "Head Office",
                              color: kGreyColor,
                              weight: FontWeight.w500,
                              align: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 6),
                          CommonImageView(
                            imagePath: Assets.imagesLocationDot,
                            height: 12,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: kBorderColor),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CommonImageView(imagePath: Assets.imagesPen, height: 12),
                    const SizedBox(width: 6),
                    AppText.p2("Fix time"),
                  ],
                ),
                InkWell(
                  onTap: _openDetails,
                  child: Row(
                    children: [
                      AppText.p2("View details"),
                      const SizedBox(width: 6),
                      CommonImageView(
                        imagePath: Assets.imagesArrowNextBlack,
                        height: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
