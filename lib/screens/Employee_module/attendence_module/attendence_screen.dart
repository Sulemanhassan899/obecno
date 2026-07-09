import 'package:Obecno/controller/attendece_controller.dart';
import 'package:Obecno/core/animations/app_animations.dart';
import 'package:Obecno/core/constants/all_colors.dart';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/core/constants/app_sizes.dart';
import 'package:Obecno/core/constants/text_styles.dart';
import 'package:Obecno/core/utils/demo_list.dart';
import 'package:Obecno/generated/assets.dart';
import 'package:Obecno/model/attendence_model.dart';
import 'package:Obecno/model/clock_attendence_event.dart';
import 'package:Obecno/screens/Employee_module/attendence_module/widgets/attendence_header.dart';
import 'package:Obecno/screens/Employee_module/attendence_module/widgets/attendence_widgets.dart';
import 'package:Obecno/screens/Employee_module/clock_module/widgets/clock_attendance_engine.dart';
import 'package:Obecno/screens/bottom_sheets/attendance_details_sheet.dart';
import 'package:Obecno/widgets/common_image_view_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MonthlyAttendanceScreen extends StatefulWidget {
  const MonthlyAttendanceScreen({super.key});

  @override
  State<MonthlyAttendanceScreen> createState() =>
      _MonthlyAttendanceScreenState();
}

class _MonthlyAttendanceScreenState extends State<MonthlyAttendanceScreen> {
  final MonthlyAttendanceController _controller = MonthlyAttendanceController(
    initialMonth: DateTime(2025, 10),
  );

  final List<AttendanceEvent> allEvents = [];

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

  void _onDayTap(AttendanceDayRecord record) {
    final day = record.date;

    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final dayEvents = allEvents.where((e) {
      return e.time.isAfter(
            startOfDay.subtract(const Duration(milliseconds: 1)),
          ) &&
          e.time.isBefore(endOfDay);
    }).toList();

    final summary = AttendanceEngine.compute(dayEvents);

    AttendanceDetailsSheet.show(
      context: context,
      day: day,
      events: dayEvents,
      summary: summary,
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
                        ? const Center(child: CircularProgressIndicator())
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
}
