import 'package:flutter/material.dart';

import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/api/api_client.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/core/constants/text_styles.dart';

import 'package:Obecno/features/employee_module/attendance/data/models/attendence_event.dart';
import 'package:Obecno/features/employee_module/attendance/presentation/widgets/history_attendance_engine.dart';

import 'package:Obecno/generated/assets.dart';

import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:Obecno/shared/bottom_sheets/add_attendance_bottom_sheet.dart';

class AttendanceDetailsSheet {
  AttendanceDetailsSheet._();

  static Future<void> show({
    required BuildContext context,
    required DateTime day,
    required List<HistoryAttendanceEvent> events,
    required HistoryAttendanceSummary summary,
    // needed to fire the POST /api/employee/tickets fix request from
    // AddAttendanceBottomSheet. Pass whatever your DI locator /
    // AuthProvider gives you for these two.
    required ApiClient apiClient,
    required String userEmail,
    VoidCallback? onEditAttendance,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _AttendanceDetailsSheetBody(
          pageContext: context,
          day: day,
          events: events,
          summary: summary,
          apiClient: apiClient,
          userEmail: userEmail,
          onEditAttendance: onEditAttendance,
        );
      },
    );
  }
}

class _AttendanceDetailsSheetBody extends StatelessWidget {
  final BuildContext pageContext;
  final DateTime day;
  final List<HistoryAttendanceEvent> events;
  final HistoryAttendanceSummary summary;
  final ApiClient apiClient;
  final String userEmail;
  final VoidCallback? onEditAttendance;

  const _AttendanceDetailsSheetBody({
    required this.pageContext,
    required this.day,
    required this.events,
    required this.summary,
    required this.apiClient,
    required this.userEmail,
    required this.onEditAttendance,
  });

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

  // DateTime -> TimeOfDay, used to seed AddAttendanceBottomSheet.
  TimeOfDay _timeOfDay(DateTime dt) =>
      TimeOfDay(hour: dt.hour, minute: dt.minute);

  @override
  Widget build(BuildContext context) {
    HistoryAttendanceEvent? checkIn;
    HistoryAttendanceEvent? checkOut;
    HistoryAttendanceEvent? breakIn; // 🟢 break end
    HistoryAttendanceEvent? breakOut; // 🔴 break start

    for (final e in events) {
      switch (e.type) {
        case AttendanceHisotryEventType.checkIn:
          checkIn ??= e;
          break;

        case AttendanceHisotryEventType.checkOut:
          checkOut ??= e;
          break;

        case AttendanceHisotryEventType.breakStart:
          breakOut ??= e; // 🔴 correct
          break;

        case AttendanceHisotryEventType.breakEnd:
          breakIn ??= e; // 🟢 correct
          break;
      }
    }

    final now = DateTime.now();

    /// ✅ Fake event generator
    HistoryAttendanceEvent fakeEvent(AttendanceHisotryEventType type) {
      return HistoryAttendanceEvent(
        type: type,
        time: now,
        location: "__fake__",
      );
    }

    final timeline = [
      checkIn ?? fakeEvent(AttendanceHisotryEventType.checkIn),
      breakOut ?? fakeEvent(AttendanceHisotryEventType.breakStart),
      breakIn ?? fakeEvent(AttendanceHisotryEventType.breakEnd),
      checkOut ?? fakeEvent(AttendanceHisotryEventType.checkOut),
    ];

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

                      ...timeline.map(
                        (e) =>
                            _TimelineTile(event: e, color: _colorFor(e.type)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      // close this sheet, open the editable one seeded
                      // with the real tapped-day times, using
                      // `pageContext` (still mounted after this pop).
                      onTap: () {
                        Navigator.of(context).pop();

                        AddAttendanceBottomSheet.show(
                          pageContext,
                          day: day,
                          apiClient: apiClient,
                          userEmail: userEmail,
                          initialCheckIn: checkIn != null
                              ? _timeOfDay(checkIn.time)
                              : null,
                          initialCheckOut: checkOut != null
                              ? _timeOfDay(checkOut.time)
                              : null,
                          initialBreakStart: breakOut != null
                              ? _timeOfDay(breakOut.time)
                              : null,
                          initialBreakEnd: breakIn != null
                              ? _timeOfDay(breakIn.time)
                              : null,
                        );

                        onEditAttendance?.call();
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
                                imagePath: Assets.imagesPen,
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
              ),
              const SizedBox(height: 10),
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

class _TimelineTile extends StatelessWidget {
  final HistoryAttendanceEvent event;
  final Color color;

  const _TimelineTile({required this.event, required this.color});

  @override
  Widget build(BuildContext context) {
    final isZero = event.location == "__fake__";

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
          isZero
              ? const SizedBox(height: 6)
              : AppText.h6(
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
