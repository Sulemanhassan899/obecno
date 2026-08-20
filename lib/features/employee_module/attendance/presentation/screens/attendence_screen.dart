import 'package:Obecno/features/employee_module/attendance/data/models/attendance_day.dart'
    as normalized;
import 'package:Obecno/features/employee_module/attendance/data/models/attendence_event.dart';
import 'package:Obecno/features/employee_module/attendance/domain/controllers/attendence_controller.dart';
import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/animations/button_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';

import 'package:Obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:Obecno/features/employee_module/attendance/presentation/widgets/history_attendance_engine.dart';
import 'package:Obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/features/employee_module/attendance/presentation/widgets/attendence_header.dart';
import 'package:Obecno/features/employee_module/attendance/presentation/widgets/attendence_widgets.dart';
import 'package:Obecno/features/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:Obecno/shared/bottom_sheets/detail_sheets/attendance_details_sheet.dart';
import 'package:Obecno/shared/bottom_sheets/attendance_sheet/hoilday_detail_sheet.dart';

import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class EmployeeAttendanceScreen extends StatefulWidget {
  const EmployeeAttendanceScreen({
    super.key,
    this.employeeName,
    this.embeddedInSheet = false,
  });

  /// When opened from manager profile, shows employee name in the header.
  final String? employeeName;

  /// Embed inside a bottom sheet (no outer Scaffold / SafeArea padding).
  final bool embeddedInSheet;

  @override
  State<EmployeeAttendanceScreen> createState() =>
      _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen> {
  final MonthlyAttendanceController _controller = MonthlyAttendanceController();

  List<AttendanceDayRecord> get processedRecords {
    final ascending = List<AttendanceDayRecord>.from(_controller.records)
      ..sort((a, b) => a.date.compareTo(b.date));

    final List<AttendanceDayRecord> result = [];
    // Collect consecutive non-working days (weekend/holiday) to group them.
    List<AttendanceDayRecord> nonWorkingRun = [];

    void flushNonWorkingRun() {
      if (nonWorkingRun.isEmpty) return;
      final start = nonWorkingRun.first.date;
      final end = nonWorkingRun.last.date;
      // Determine the label based on whether these are holidays or weekends.
      final hasHoliday = nonWorkingRun.any(
        (r) => r.status == AttendanceDayStatus.holiday,
      );
      final label = hasHoliday ? 'Holiday' : 'Weekend';
      result.add(
        AttendanceDayRecord(
          day: end.day,
          weekday: '',
          date: end,
          status: AttendanceDayStatus.weekend,
          weekendLabel: "$label, ${_formatDate(start)} - ${_formatDate(end)}",
        ),
      );
      nonWorkingRun.clear();
    }

    for (final record in ascending) {
      final isNonWorking =
          record.status == AttendanceDayStatus.weekend ||
          record.status == AttendanceDayStatus.holiday;

      if (isNonWorking) {
        // Accumulate consecutive non-working days.
        nonWorkingRun.add(record);
      } else {
        // Flush any accumulated non-working days before this working day.
        flushNonWorkingRun();
        result.add(record);
      }
    }
    // Flush any trailing non-working days.
    flushNonWorkingRun();

    return result.reversed.toList();
  }

  String _formatDate(DateTime date) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  String _formatFullWeekdayDate(DateTime date) {
    const weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}";
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<HistoryAttendanceEvent> _eventsFor(normalized.AttendanceDay? day) {
    if (day == null) return [];

    final events = <HistoryAttendanceEvent>[];

    // Preserve EVERY check-in / check-out from the API (not just first/last).
    for (var i = 0; i < day.checkIns.length; i++) {
      events.add(
        HistoryAttendanceEvent(
          time: _combine(day.date, day.checkIns[i]),
          type: AttendanceHisotryEventType.checkIn,
          location: i < day.checkInLocations.length
              ? day.checkInLocations[i]
              : null,
        ),
      );
    }

    for (var i = 0; i < day.checkOuts.length; i++) {
      events.add(
        HistoryAttendanceEvent(
          time: _combine(day.date, day.checkOuts[i]),
          type: AttendanceHisotryEventType.checkOut,
          location: i < day.checkOutLocations.length
              ? day.checkOutLocations[i]
              : null,
        ),
      );
    }

    for (final b in day.breaks) {
      events.add(
        HistoryAttendanceEvent(
          time: _combine(day.date, b.breakOut),
          type: AttendanceHisotryEventType.breakStart,
          location: b.breakOutLocation,
        ),
      );
      events.add(
        HistoryAttendanceEvent(
          time: _combine(day.date, b.breakIn),
          type: AttendanceHisotryEventType.breakEnd,
          location: b.breakInLocation,
        ),
      );
    }

    events.sort((a, b) => a.time.compareTo(b.time));
    return events;
  }

  /// Combines a date-only `DateTime` with an "HH:mm[:ss]" time string.
  DateTime _combine(DateTime date, String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts.elementAt(0)) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final s = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, h, m, s);
  }

  void _onDayTap(AttendanceDayRecord record) {
    // 1. On Leave -> DO NOT open any bottom sheet
    if (record.status == AttendanceDayStatus.onLeave ||
        record.checkIn == "Leave" ||
        record.checkOut == "Leave") {
      return;
    }

    // 2. Holiday or Weekend -> Open HolidayBottomSheet
    if (record.status == AttendanceDayStatus.holiday ||
        record.status == AttendanceDayStatus.weekend) {
      HolidayBottomSheet.show(
        context,
        day: record.date,
        title: record.status == AttendanceDayStatus.holiday
            ? (record.weekendLabel ?? "Public Holiday")
            : "Weekend Holiday",
        apiClient: _controller.apiClient,
        userEmail: _controller.userEmail,
      );
      return;
    }

    final day = record.date;

    final normalizedDay = _controller.dayFor(day);
    final dayEvents = _eventsFor(normalizedDay);

    final summary = HistoryAttendanceEngine.compute(dayEvents);

    AttendanceDetailsSheet.show(
      context: context,
      day: day,
      events: dayEvents,
      summary: summary,
      apiClient: _controller.apiClient,
      userEmail: _controller.userEmail,
      onEditAttendance: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final summary = _controller.summary;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.embeddedInSheet) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    // Fixed-size back circle only — do not nest BackButtonBg
                    // (it contains a Spacer Row and breaks layout here).
                    ButtonAnimations.press(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 42,
                        width: 42,
                        decoration: const BoxDecoration(
                          color: kGreyContainerColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          AppText.h5('Attendance'),
                          if (widget.employeeName != null) ...[
                            const SizedBox(height: 2),
                            AppText.caption(
                              widget.employeeName!,
                              color: kGreyColor,
                              weight: FontWeight.w400,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.embeddedInSheet ? 16 : 0,
              ),
              child: AttendanceMonthHeader(
                month: _controller.selectedMonth,
                onPrevious: _controller.previousMonth,
                onNext: _controller.nextMonth,
                isNextEnabled: _controller.canGoNext,
                isPreviousEnabled: _controller.canGoPrevious,
                onTapDropdown: () {
                  MonthYearPickerSheet.show(
                    context,
                    initialDate: _controller.selectedMonth,
                    minDate: _controller.joiningDate,
                    onSelected: (date) {
                      _controller.setMonth(date);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _controller.refresh,
                color: kPrimaryColor,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.embeddedInSheet ? 16 : 0,
                  ),
                  child: _controller.isLoading || summary == null
                      ? _buildLoadingShimmer()
                      : _controller.records.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.dataset_outlined,
                                    size: 60,
                                    color: kGreyColor.withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 12),
                                  AppText.p2(
                                    "No Record",
                                    color: kGreyColor,
                                    weight: FontWeight.w600,
                                  ),
                                  const SizedBox(height: 6),
                                  AppText.p2(
                                    "You don’t have any records yet",
                                    color: kGreyColor.withOpacity(0.7),
                                    weight: FontWeight.w400,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: processedRecords.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Column(
                                children: [
                                  AttendanceSummaryCard(summary: summary),
                                  const SizedBox(height: 20),
                                ],
                              );
                            }

                            final record = processedRecords[index - 1];
                            if (record.status == AttendanceDayStatus.holiday) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: AttendanceHolidayCard(
                                  title:
                                      record.weekendLabel ?? "Public Holiday",
                                  date: _formatFullWeekdayDate(record.date),
                                  onTap: () => _onDayTap(record),
                                ),
                              );
                            }

                            if (record.status == AttendanceDayStatus.weekend) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 10,
                                  top: 10,
                                ),
                                child: AttendanceWeekendCard(
                                  label: record.weekendLabel ?? "Weekend",
                                ),
                              );
                            }

                            return AttendanceDayTile(
                              record: record,
                              onTap: () => _onDayTap(record),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (widget.embeddedInSheet) {
      return ColoredBox(color: kbackground2, child: content);
    }

    return Scaffold(
      backgroundColor: kbackground1,
      body: SafeArea(
        child: Padding(padding: AppSizes.DEFAULT2, child: content),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView(
      children: [
        /// Summary shimmer
        Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _shimmerBox(height: 20)),
                  const SizedBox(width: 20),
                  Expanded(child: _shimmerBox(height: 20)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _shimmerBox(height: 20)),
                  const SizedBox(width: 20),
                  Expanded(child: _shimmerBox(height: 20)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        /// List shimmer
        ...List.generate(6, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                _shimmerBox(
                  height: 60,
                  width: 60,
                  radius: BorderRadius.circular(10),
                ),
                const SizedBox(width: 16),
                Expanded(child: _shimmerBox(height: 16)),
                const SizedBox(width: 16),
                _shimmerBox(height: 16, width: 80),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _shimmerBox({
    double height = 16,
    double width = double.infinity,
    BorderRadius? radius,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius ?? BorderRadius.circular(6),
        ),
      ),
    );
  }
}
