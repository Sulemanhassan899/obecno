import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/features/employee_module/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:Obecno/features/employee_module/clock/presentation/widgets/clock_attendence_card.dart';
import 'package:Obecno/shared/bottom_sheets/hoilday_detail_sheet.dart';

import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:Obecno/shared/widgets/my_button.dart';

class ClockAttendanceDetailsSheet {
  ClockAttendanceDetailsSheet._();

  static Future<void> show({
    required BuildContext context,
    required DateTime day,
    required List<AttendanceEvent> events,
    required AttendanceSummary summary,
    VoidCallback? onEditAttendance,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ClockAttendanceDetailsSheetBody(
          day: day,
          events: events,
          summary: summary,
          onEditAttendance: onEditAttendance,
        );
      },
    );
  }
}

class _ClockAttendanceDetailsSheetBody extends StatelessWidget {
  final DateTime day;
  final List<AttendanceEvent> events;
  final AttendanceSummary summary;
  final VoidCallback? onEditAttendance;

  const _ClockAttendanceDetailsSheetBody({
    required this.day,
    required this.events,
    required this.summary,
    required this.onEditAttendance,
  });

  Color _colorFor(AttendanceEventType type) {
    switch (type) {
      case AttendanceEventType.checkIn:
        return kPrimaryColor;
      case AttendanceEventType.checkOut:
        return kredColor;
      case AttendanceEventType.breakStart:
      case AttendanceEventType.breakEnd:
        return kYellowColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeline = AttendanceEngine.sortedNewestFirst(events);
    final workingDuration = summary.liveWorkingDuration();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              /// ================= HEADER =================
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText.h5(
                      AttendanceFormat.fullDate(day),
                      weight: FontWeight.w600,
                    ),
                    ButtonAnimations.press(
                      onTap: () => Navigator.pop(context),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  color: kbackground2,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kBorderColor),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                /// LEFT (CHECK IN)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppText.p2(
                                        "Check-In",
                                        color: kPrimaryColor,
                                      ),
                                      const SizedBox(height: 6),
                                      AppText.h3(
                                        AttendanceFormat.time(
                                          summary.firstCheckIn,
                                        ),
                                        color: kPrimaryColor,
                                        weight: FontWeight.w700,
                                      ),
                                    ],
                                  ),
                                ),

                                /// CENTER DURATION
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        _dot(),
                                        _line(),
                                        const SizedBox(width: 6),
                                        AppText.p2(
                                          AttendanceFormat.duration(
                                            workingDuration,
                                          ),
                                          weight: FontWeight.w600,
                                        ),
                                        const SizedBox(width: 6),
                                        _line(),
                                        _dot(),
                                      ],
                                    ),
                                  ],
                                ),

                                /// RIGHT (CHECK OUT)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      AppText.p2("Check-Out", color: kredColor),
                                      const SizedBox(height: 6),
                                      AppText.h3(
                                        AttendanceFormat.time(
                                          summary.lastCheckOut,
                                        ),
                                        color: kredColor,
                                        weight: FontWeight.w700,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            /// LOCATION ROW
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _location("Head Office"),
                                _location("Head Office", isRight: true),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      /// ================= TIMELINE HEADER =================
                      Row(
                        children: [
                          CommonImageView(
                            imagePath: Assets.imagesClipboardClock,
                            height: 24,
                          ),
                          const SizedBox(width: 8),
                          AppText.h5("Timeline", weight: FontWeight.w600),
                        ],
                      ),

                      const SizedBox(height: 14),

                      /// ================= TIMELINE =================
                      if (timeline.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: AppText.p2(
                            "No events recorded yet",
                            color: kGreyColor,
                          ),
                        )
                      else
                        ...timeline.map(
                          (e) =>
                              _TimelineTile(event: e, color: _colorFor(e.type)),
                        ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

              /// ================= BUTTON =================
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,

                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            Future.delayed(Duration.zero, () {
                              AddAttendanceBottomSheet.show(context);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: kWhite,
                              border: Border.all(color: kBorderColor),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              spacing: 6,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 4,
                                    left: 6,
                                  ),
                                  child: CommonImageView(
                                    imagePath: Assets.imagesMugHot,
                                    height: 16,
                                  ),
                                ),
                                AppText.caption(
                                  "Edit Attendance",
                                  weight: FontWeight.w500,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dot() {
    return Icon(Icons.circle, size: 7, color: kGreyColor.withOpacity(0.3));
  }

  Widget _line() {
    return Container(width: 18, height: 2, color: kGreyColor.withOpacity(0.3));
  }

  Widget _location(String text, {bool isRight = false}) {
    return Row(
      children: [
        if (!isRight)
          CommonImageView(imagePath: Assets.imagesLocationDot, height: 12),
        if (!isRight) const SizedBox(width: 6),
        AppText.p2(text, color: kGreyColor, weight: FontWeight.w500),
        if (isRight) const SizedBox(width: 6),
        if (isRight)
          CommonImageView(imagePath: Assets.imagesLocationDot, height: 12),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final AttendanceEvent event;
  final Color color;

  const _TimelineTile({required this.event, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TIME
          AppText.h6(
            AttendanceFormat.time(event.time),
            weight: FontWeight.w700,
          ),

          const SizedBox(height: 6),

          /// TITLE + ICON
          Row(
            children: [
              AppText.h5(event.label, color: color, weight: FontWeight.w700),
              const SizedBox(width: 12),
              CommonImageView(imagePath: Assets.imagesUserPen, height: 18),
            ],
          ),

          const SizedBox(height: 8),

          /// LOCATION
          Row(
            children: [
              CommonImageView(imagePath: Assets.imagesLocationDot, height: 12),
              const SizedBox(width: 6),
              AppText.p2(
                event.location ?? "--",
                color: kGreyColor,
                weight: FontWeight.w500,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
