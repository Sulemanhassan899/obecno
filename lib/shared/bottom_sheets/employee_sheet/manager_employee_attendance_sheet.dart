import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/demo/demo_list.dart';
import 'package:obecno/demo/manager_attendence_model.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:obecno/features/employee_module/attendance/presentation/screens/attendence_screen.dart';
import 'package:obecno/features/employee_module/attendance/presentation/widgets/attendence_header.dart';
import 'package:obecno/features/employee_module/attendance/presentation/widgets/attendence_widgets.dart';
import 'package:obecno/features/manager_module/Manager_attendance/presentation/widgets/manager_attendance_widgets.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:flutter/material.dart';

class ManagerEmployeeAttendanceSheet {
  ManagerEmployeeAttendanceSheet._();

  static Future<void> show({
    required BuildContext context,
    String? employeeName,
    String? locationName,
    String? locationAddress,
  }) {
    final isLocation = locationName != null && locationName.trim().isNotEmpty;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.sizeOf(context).height * 0.94,
          decoration: const BoxDecoration(
            color: kbackground2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: isLocation
                ? _LocationAttendanceSheetBody(
                    locationName: locationName,
                    locationAddress: locationAddress ?? '',
                  )
                : EmployeeAttendanceScreen(
                    employeeName: employeeName,
                    embeddedInSheet: true,
                  ),
          ),
        );
      },
    );
  }
}

class _LocationAttendanceSheetBody extends StatefulWidget {
  const _LocationAttendanceSheetBody({
    required this.locationName,
    required this.locationAddress,
  });

  final String locationName;
  final String locationAddress;

  @override
  State<_LocationAttendanceSheetBody> createState() =>
      _LocationAttendanceSheetBodyState();
}

class _LocationAttendanceSheetBodyState
    extends State<_LocationAttendanceSheetBody> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();

  static const _summary = MonthSummary(
    workingDays: 18,
    totalDays: 22,
    absentOrLeaves: 4,
    lateCheckIns: 6,
    lateCheckOuts: 2,
  );

  bool get _canGoNext {
    final now = DateTime.now();
    return _month.year < now.year ||
        (_month.year == now.year && _month.month < now.month);
  }

  void _previousMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1);
    });
  }

  void _nextMonth() {
    if (!_canGoNext) return;
    setState(() {
      _month = DateTime(_month.year, _month.month + 1);
    });
  }

  void _openDetails(ManagerAttendanceModel employee) {
    ManagerAttendanceDetailsSheet.show(
      context: context,
      data: ManagerAttendanceDetailsData.fromEmployee(
        employee: employee,
        day: _selectedDay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final people = dummyManagerAttendance;

    return ColoredBox(
      color: kbackground2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
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
                      AppText.h5(
                        widget.locationName,
                        weight: FontWeight.w600,
                      ),
                      if (widget.locationAddress.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        AppText.caption(
                          widget.locationAddress,
                          color: kGreyColor,
                          weight: FontWeight.w400,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AttendanceMonthHeader(
              month: _month,
              onPrevious: _previousMonth,
              onNext: _nextMonth,
              isNextEnabled: _canGoNext,
              onTapDropdown: () {
                MonthYearPickerSheet.show(
                  context,
                  initialDate: _month,
                  onSelected: (date) {
                    setState(() {
                      _month = DateTime(date.year, date.month);
                      _selectedDay = date;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: people.length + 1,
              separatorBuilder: (context, index) {
                if (index == 0) return const SizedBox(height: 20);
                return const Divider(height: 24, color: kDividerColor);
              },
              itemBuilder: (context, index) {
                if (index == 0) {
                  return AttendanceSummaryCard(summary: _summary);
                }
                final item = people[index - 1];
                return ManagerAttendanceTile(
                  data: item,
                  onTap: () => _openDetails(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
