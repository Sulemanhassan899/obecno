import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/demo/demo_list.dart';
import 'package:obecno/demo/manager_attendence_model.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:obecno/features/employee_module/attendance/presentation/widgets/attendence_header.dart';
import 'package:obecno/features/employee_module/attendance/presentation/widgets/attendence_widgets.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/employee_attendance_history_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/presentation/widgets/manager_attendance_widgets.dart';
import 'package:obecno/features/manager_module/Manager_attendance/providers/manager_attendance_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_policy.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/monthly_picker.dart';
import 'package:flutter/material.dart';

class ManagerEmployeeAttendanceSheet {
  ManagerEmployeeAttendanceSheet._();

  static Future<void> show({
    required BuildContext context,
    String? employeeName,
    int? userId,
    String? role,
    String? photo,
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
                : _EmployeeHistorySheetBody(
                    employeeName: employeeName ?? 'Employee',
                    userId: userId,
                    role: role,
                    photo: photo,
                  ),
          ),
        );
      },
    );
  }
}

class _EmployeeHistorySheetBody extends StatefulWidget {
  const _EmployeeHistorySheetBody({
    required this.employeeName,
    this.userId,
    this.role,
    this.photo,
  });

  final String employeeName;
  final int? userId;
  final String? role;
  final String? photo;

  @override
  State<_EmployeeHistorySheetBody> createState() =>
      _EmployeeHistorySheetBodyState();
}

class _EmployeeHistorySheetBodyState extends State<_EmployeeHistorySheetBody> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  String? _error;
  MonthSummary? _summary;
  List<AttendanceDayRecord> _records = const [];

  bool get _canGoNext {
    final now = DateTime.now();
    return _month.year < now.year ||
        (_month.year == now.year && _month.month < now.month);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = widget.userId;
    if (userId == null) {
      setState(() {
        _loading = false;
        _error = 'Missing employee.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final from = DateTime(_month.year, _month.month, 1);
      final to = DateTime(_month.year, _month.month + 1, 0);
      final attendanceFuture = bindings.managerAttendanceService
          .loadEmployeeAttendanceRange(userId: userId, from: from, to: to);
      final holidaysFuture = bindings.managerEmployeesService
          .loadEmployeeHolidays(
            userId: userId,
            dateFrom: _yyyyMMdd(from),
            dateTo: _yyyyMMdd(to),
          );
      final permissionsFuture = bindings.managerEmployeesService
          .loadEmployeePermissions(userId: userId);

      final attendance = await attendanceFuture;
      final holidays = await holidaysFuture;
      final permissions = await permissionsFuture;
      if (!mounted) return;

      if (!attendance.success || attendance.data == null) {
        setState(() {
          _loading = false;
          _error = attendance.message ?? 'Failed to load attendance.';
        });
        return;
      }

      final policy = ManagerEmployeePolicy.fromItems(
        permissions.data ?? const [],
      );
      final workingDays = WorkingDaysParser.parse(policy.workingDays);
      final month = ManagerEmployeeHistoryMapper.build(
        month: _month,
        history: attendance.data!.history,
        workingWeekdays: workingDays.isEmpty
            ? const {1, 2, 3, 4, 5}
            : workingDays,
        holidays: holidays.data ?? const [],
        scheduledCheckIn: policy.checkIn,
        graceMinutes: policy.graceMinutes,
        scheduledCheckOut: policy.checkOut,
      );

      setState(() {
        _summary = month.summary;
        _records = month.records;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load attendance.';
      });
    }
  }

  void _previousMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _load();
  }

  void _nextMonth() {
    if (!_canGoNext) return;
    setState(() => _month = DateTime(_month.year, _month.month + 1));
    _load();
  }

  void _openDetails(AttendanceDayRecord record) {
    if (record.status == AttendanceDayStatus.onLeave) return;
    final userId = widget.userId;
    final employee = ManagerAttendanceModel(
      name: widget.employeeName,
      role: widget.role,
      photo: widget.photo,
      userId: userId,
      checkIn: record.checkIn,
      checkOut: record.checkOut,
      status: record.status == AttendanceDayStatus.onLeave ? 'leave' : '',
    );
    final provider = context.read<ManagerAttendanceProvider>();
    ManagerAttendanceDetailsSheet.show(
      context: context,
      data: ManagerAttendanceDetailsData.fromEmployee(
        employee: employee,
        day: record.date,
      ),
      loadDetails: userId == null
          ? null
          : () => provider.loadEmployeeDay(employee: employee, day: record.date),
    );
  }

  String _yyyyMMdd(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatFullWeekdayDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kbackground2,
      child: Column(
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
                      AppText.h5('Attendance', weight: FontWeight.w600),
                      const SizedBox(height: 2),
                      AppText.caption(
                        widget.employeeName,
                        color: kGreyColor,
                        weight: FontWeight.w400,
                      ),
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
                    setState(() => _month = DateTime(date.year, date.month));
                    _load();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AppText.p2(_error!, color: kGreyColor),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _records.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Column(
                            children: [
                              AttendanceSummaryCard(
                                summary:
                                    _summary ??
                                    const MonthSummary(
                                      workingDays: 0,
                                      totalDays: 0,
                                      absentOrLeaves: 0,
                                      lateCheckIns: 0,
                                      lateCheckOuts: 0,
                                    ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          );
                        }
                        final record = _records[index - 1];
                        if (record.status == AttendanceDayStatus.holiday) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: AttendanceHolidayCard(
                              title: record.weekendLabel ?? 'Public Holiday',
                              date: _formatFullWeekdayDate(record.date),
                              onTap: () => _openDetails(record),
                            ),
                          );
                        }
                        if (record.status == AttendanceDayStatus.weekend) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10, top: 10),
                            child: AttendanceWeekendCard(
                              label: record.weekendLabel ?? 'Weekend',
                            ),
                          );
                        }
                        return AttendanceDayTile(
                          record: record,
                          onTap: () => _openDetails(record),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
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
