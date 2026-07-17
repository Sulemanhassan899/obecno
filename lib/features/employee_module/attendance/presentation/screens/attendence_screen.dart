import 'package:Obecno/features/employee_module/attendance/data/models/attendance_day.dart'
    as normalized;
import 'package:Obecno/features/employee_module/attendance/data/models/attendence_event.dart';
import 'package:Obecno/features/employee_module/attendance/domain/controllers/attendence_controller.dart';
import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';

import 'package:Obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:Obecno/features/employee_module/attendance/presentation/widgets/history_attendance_engine.dart';
import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/features/employee_module/attendance/presentation/widgets/attendence_header.dart';
import 'package:Obecno/features/employee_module/attendance/presentation/widgets/attendence_widgets.dart';
import 'package:Obecno/features/employee_module/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:Obecno/shared/bottom_sheets/attendance_details_sheet.dart';

import 'package:Obecno/shared/widgets/common_image_view_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class MonthlyAttendanceScreen extends StatefulWidget {
  const MonthlyAttendanceScreen({super.key});

  @override
  State<MonthlyAttendanceScreen> createState() =>
      _MonthlyAttendanceScreenState();
}

class _MonthlyAttendanceScreenState extends State<MonthlyAttendanceScreen> {
  // 🔥 CHANGED: no longer pinned to a fixed demo month — defaults to the
  // current month now that data is real. `initialMonth` is still accepted
  // if you want to open on a specific month.
  final MonthlyAttendanceController _controller = MonthlyAttendanceController();

  /// 🔥 NEW: processed list with WEEKEND injection
  List<AttendanceDayRecord> get processedRecords {
    final original = _controller.records;
    final List<AttendanceDayRecord> result = [];

    List<AttendanceDayRecord> currentWeek = [];

    for (final record in original) {
      if (record.status == AttendanceDayStatus.weekend) continue;

      currentWeek.add(record);
      result.add(record);

      if (currentWeek.length == 5) {
        final start = currentWeek.first.date;
        final end = currentWeek.last.date;

        result.add(
          AttendanceDayRecord(
            day: end.day,
            weekday: '',
            date: end,
            status: AttendanceDayStatus.weekend,
            weekendLabel:
                "Weekend, ${_formatDate(start)} - ${_formatDate(end)}",
          ),
        );

        currentWeek.clear();
      }
    }

    /// LAST PARTIAL WEEK
    if (currentWeek.isNotEmpty) {
      final start = currentWeek.first.date;
      final end = currentWeek.last.date;

      result.add(
        AttendanceDayRecord(
          day: end.day,
          weekday: '',
          date: end,
          status: AttendanceDayStatus.weekend,
          weekendLabel: "Weekend, ${_formatDate(start)} - ${_formatDate(end)}",
        ),
      );
    }

    return result;
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<HistoryAttendanceEvent> _eventsFor(normalized.AttendanceDay? day) {
    if (day == null) return [];

    final events = <HistoryAttendanceEvent>[]; 

    if (day.firstCheckIn != null) {
      events.add(
        HistoryAttendanceEvent(
          time: _combine(day.date, day.firstCheckIn!),
          type: AttendanceHisotryEventType.checkIn,
        ),
      );
    }

    for (final b in day.breaks) {
      events.add(
        HistoryAttendanceEvent(
          time: _combine(day.date, b.breakIn),
          type: AttendanceHisotryEventType.breakStart,
        ),
      );
      events.add(
        HistoryAttendanceEvent(
          time: _combine(day.date, b.breakOut),
          type: AttendanceHisotryEventType.breakEnd,
        ),
      );
    }

    if (day.lastCheckOut != null) {
      events.add(
        HistoryAttendanceEvent(
          time: _combine(day.date, day.lastCheckOut!),
          type: AttendanceHisotryEventType.checkOut,
        ),
      );
    }

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
    return Scaffold(
      backgroundColor: kbackground.withOpacity(0.2),
      body: SafeArea(
        child: Padding(
          padding: AppSizes.DEFAULT2,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final summary = _controller.summary;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AttendanceMonthHeader(
                    month: _controller.selectedMonth,
                    onPrevious: _controller.previousMonth,
                    onNext: _controller.nextMonth,
                    isNextEnabled: _controller.canGoNext, // 🔥 NEW
                    onTapDropdown: () {
                      MonthYearPickerSheet.show(
                        context,
                        initialDate: _controller.selectedMonth,
                        onSelected: (date) {
                          _controller.setMonth(date);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _controller.isLoading || summary == null
                        ? _buildLoadingShimmer()
                        : _controller.records.isEmpty
                        // 🔥 NEW: "No Record" empty state per spec
                        // (functional requirement #1). Summary card still
                        // renders above it so absents/late counts stay
                        // visible even on a record-free month.
                        ? Column(
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
                          )
                        : ListView(
                            children: [
                              AttendanceSummaryCard(summary: summary),
                              const SizedBox(height: 20),

                              /// 🔥 USE PROCESSED LIST (ONLY CHANGE)
                              ...processedRecords.map((record) {
                                if (record.status ==
                                    AttendanceDayStatus.weekend) {
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
                              }),
                              // 🔥 NEW: bottom-only loader while paginating
                              // to a month that isn't cached yet — never a
                              // full-screen loader for pagination.
                              if (_controller.isPaginating)
                                 Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: _shimmerBox(height: 20, width: 80),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
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
