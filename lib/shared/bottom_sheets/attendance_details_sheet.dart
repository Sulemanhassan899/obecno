import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendence_event.dart';
import 'package:Obecno/features/employee_module/attendance/presentation/widgets/history_attendance_engine.dart';

import 'package:Obecno/features/employee_module/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:Obecno/features/employee_module/clock/presentation/widgets/clock_attendence_card.dart';
import 'package:Obecno/shared/bottom_sheets/hoilday_detail_sheet.dart';

import 'package:flutter/material.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:Obecno/shared/widgets/my_button.dart';

class AttendanceDetailsSheet {
  AttendanceDetailsSheet._();

  static Future<void> show({
    required BuildContext context,
    required DateTime day,
    required List<HistoryAttendanceEvent> events,
    required HistoryAttendanceSummary summary,
    VoidCallback? onEditAttendance,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AttendanceDetailsSheetBody(
          day: day,
          events: events,
          summary: summary,
          onEditAttendance: onEditAttendance,
        );
      },
    );
  }
}

class _AttendanceDetailsSheetBody extends StatelessWidget {
  final DateTime day;
  final List<HistoryAttendanceEvent> events;
  final HistoryAttendanceSummary summary;
  final VoidCallback? onEditAttendance;

  const _AttendanceDetailsSheetBody({
    required this.day,
    required this.events,
    required this.summary,
    required this.onEditAttendance,
  });

  /// ✅ FIXED TYPE
  Color _colorFor(AttendanceHisotryEventType type) {
    switch (type) {
      case AttendanceHisotryEventType.checkIn:
        return kPrimaryColor;
      case AttendanceHisotryEventType.checkOut:
        return kredColor;
      case AttendanceHisotryEventType.breakStart:
      case AttendanceHisotryEventType.breakEnd:
        return kYellowColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    /// ✅ FIX: engine must accept HistoryAttendanceEvent
    final timeline = HistoryAttendanceEngine.sortedNewestFirst(events);

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
              /// HEADER
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
                      /// SUMMARY CARD (UNCHANGED)
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
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      /// TIMELINE
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
                          (e) => _TimelineTile(
                            event: e,
                            color: _colorFor(e.type), // ✅ FIXED
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dot() =>
      Icon(Icons.circle, size: 7, color: kGreyColor.withOpacity(0.3));

  Widget _line() =>
      Container(width: 18, height: 2, color: kGreyColor.withOpacity(0.3));
}

/// ================= TILE =================
class _TimelineTile extends StatelessWidget {
  final HistoryAttendanceEvent event;
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
          AppText.h6(
            AttendanceFormat.time(event.time),
            weight: FontWeight.w700,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              AppText.h5(event.label, color: color, weight: FontWeight.w700),
            ],
          ),
        ],
      ),
    );
  }
}
