import 'package:obecno/core/animations/button_animations.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/demo/manager_attendence_model.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_model.dart';
import 'package:obecno/features/employee_module/attendance/presentation/widgets/attendence_header.dart';
import 'package:obecno/features/employee_module/attendance/presentation/widgets/attendence_widgets.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/employee_attendance_history_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/manager_attendance_filters.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/pending_attendance_overlay.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/presentation/widgets/manager_attendance_widgets.dart';
import 'package:obecno/features/manager_module/Manager_attendance/providers/manager_attendance_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_policy.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/location_attendance_stats.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/attendance_sheet/add_attendance_bottom_sheet.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/status_filter_sheet.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';
import 'package:flutter/material.dart';

class ManagerEmployeeAttendanceSheet {
  ManagerEmployeeAttendanceSheet._();

  static Future<void> show({
    required BuildContext context,
    String? employeeName,
    int? userId,
    String? role,
    String? photo,
    String? locationId,
    String? locationName,
    String? locationAddress,
    String? statusFilter,
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
                    locationId: locationId,
                    locationName: locationName,
                    locationAddress: locationAddress ?? '',
                    statusFilter: statusFilter,
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

  Future<void> _load({bool silent = false}) async {
    final userId = widget.userId;
    if (userId == null) {
      setState(() {
        _loading = false;
        _error = 'Missing employee.';
      });
      return;
    }

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

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
      final history = PendingAttendanceOverlay.applyToHistory(
        history: attendance.data!.history,
        pending: bindings.managerAttendanceProvider.pendingSaves,
        userId: userId,
        employeeName: widget.employeeName,
      );
      final month = ManagerEmployeeHistoryMapper.build(
        month: _month,
        history: history,
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
        _error = null;
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

  bool get _isManagerViewer =>
      bindings.authProvider.homeTarget == AuthHomeTarget.manager;

  Future<void> _openDetails(AttendanceDayRecord record) async {
    final isOnLeave = record.status == AttendanceDayStatus.onLeave;
    final isDash = _isDashDay(record);

    if ((isOnLeave || isDash) && !_isManagerViewer) return;

    final userId = widget.userId;
    final employee = ManagerAttendanceModel(
      name: widget.employeeName,
      role: widget.role,
      photo: widget.photo,
      userId: userId,
      checkIn: isOnLeave || isDash ? null : record.checkIn,
      checkOut: isOnLeave || isDash ? null : record.checkOut,
      status: isOnLeave ? 'leave' : '',
    );
    final provider = context.read<ManagerAttendanceProvider>();
    final saved = await ManagerAttendanceDetailsSheet.show(
      context: context,
      data: ManagerAttendanceDetailsData.fromEmployee(
        employee: employee,
        day: record.date,
      ),
      loadDetails: userId == null
          ? null
          : () =>
                provider.loadEmployeeDay(employee: employee, day: record.date),
    );
    if (!mounted) return;
    if (saved != null) {
      _applyOptimisticAttendance(record.date, saved);
    }
    await _load(silent: true);
  }

  bool _isDashDay(AttendanceDayRecord record) {
    if (record.status == AttendanceDayStatus.weekend ||
        record.status == AttendanceDayStatus.holiday) {
      return false;
    }
    return !_hasPunchTime(record.checkIn) && !_hasPunchTime(record.checkOut);
  }

  bool _hasPunchTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return false;
    final lower = value.toLowerCase();
    return lower != 'leave' &&
        lower != 'holiday' &&
        lower != '--' &&
        !lower.startsWith('--:--');
  }

  void _applyOptimisticAttendance(DateTime day, AddAttendanceSaveResult saved) {
    AttendanceDayRecord? previous;
    for (final record in _records) {
      if (_isSameDay(record.date, day)) {
        previous = record;
        break;
      }
    }
    final wasAbsent =
        previous != null &&
        (previous.status == AttendanceDayStatus.onLeave ||
            _isDashDay(previous));

    setState(() {
      _records = [
        for (final record in _records)
          if (_isSameDay(record.date, day))
            AttendanceDayRecord(
              day: record.day,
              weekday: record.weekday,
              date: record.date,
              checkIn: saved.checkIn == null
                  ? (_hasPunchTime(record.checkIn) ? record.checkIn : null)
                  : _formatTimeOfDay(saved.checkIn!),
              checkOut: saved.checkOut == null
                  ? (_hasPunchTime(record.checkOut) ? record.checkOut : null)
                  : _formatTimeOfDay(saved.checkOut!),
              status: AttendanceDayStatus.normal,
            )
          else
            record,
      ];
      final summary = _summary;
      if (summary != null && wasAbsent) {
        _summary = MonthSummary(
          workingDays: summary.workingDays + 1,
          totalDays: summary.totalDays,
          absentOrLeaves: (summary.absentOrLeaves - 1).clamp(0, summary.totalDays),
          lateCheckIns: summary.lateCheckIns,
          lateCheckOuts: summary.lateCheckOuts,
        );
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatTimeOfDay(TimeOfDay t) {
    final period = t.hour >= 12 ? 'PM' : 'AM';
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $period';
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
    this.locationId,
    this.statusFilter,
  });

  final String? locationId;
  final String locationName;
  final String locationAddress;
  final String? statusFilter;

  @override
  State<_LocationAttendanceSheetBody> createState() =>
      _LocationAttendanceSheetBodyState();
}

class _LocationAttendanceSheetBodyState
    extends State<_LocationAttendanceSheetBody> {
  late DateTime _month;
  late DateTime _selectedDay;

  String get _locationId => (widget.locationId ?? '').trim();

  String get _statusFilter =>
      StatusFilterOption.idFromLabel(widget.statusFilter);

  bool get _hasStatusFilter =>
      !ManagerAttendanceFilters.isAllStatus(_statusFilter);

  String get _statusTitle {
    if (!_hasStatusFilter) return widget.locationName;
    return ManagerAttendanceFilters.statusDisplayLabel(_statusFilter);
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return _month.year < now.year ||
        (_month.year == now.year && _month.month < now.month);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load() async {
    final attendance = context.read<ManagerAttendanceProvider>();
    final employees = context.read<ManagerEmployeesProvider>();
    final day = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );

    await Future.wait([
      attendance.selectedDate == day
          ? attendance.load()
          : attendance.setDate(day),
      if (_locationId.isNotEmpty)
        employees.load(locationId: _locationId)
      else
        employees.load(),
    ]);
  }

  List<ManagerTeamAttendanceItem> _locationItems({
    required ManagerAttendanceProvider attendance,
    required ManagerEmployeesProvider employees,
  }) {
    if (_locationId.isNotEmpty) {
      return LocationAttendanceStats.merge(
        location: ManagerLocationModel(
          id: _locationId,
          name: widget.locationName,
          address: widget.locationAddress,
        ),
        attendance: attendance.items,
        members: employees.members,
      );
    }

    if (employees.isLoading && employees.members.isEmpty) return const [];

    return ManagerAttendanceFilters.applyItems(
      source: attendance.items,
      selectedLocation: LocationFilterOption.allId,
      locationName: widget.locationName,
      members: employees.members,
    );
  }

  List<ManagerTeamAttendanceItem> _filteredItems(
    List<ManagerTeamAttendanceItem> source,
  ) {
    // Match location overview stats: Absent excludes On Leaves.
    if (StatusFilterOption.sameFamily(_statusFilter, 'absent')) {
      return source
          .where((item) => !item.hasCheckIn && !item.isOnLeave)
          .toList(growable: false);
    }
    if (StatusFilterOption.sameFamily(_statusFilter, 'leave')) {
      return source.where((item) => item.isOnLeave).toList(growable: false);
    }

    return ManagerAttendanceFilters.applyItems(
      source: source,
      selectedStatus: _statusFilter,
      selectedLocation: LocationFilterOption.allId,
    );
  }

  MonthSummary _summaryFor(List<ManagerTeamAttendanceItem> items) {
    final present = items.where((e) => e.hasCheckIn).length;
    final total = items.isEmpty ? 0 : items.length;
    final absentOrLeaves = items
        .where((e) => !e.hasCheckIn || e.isOnLeave)
        .length;
    final lateIns = items.where((e) => e.isLate).length;
    final lateOuts = items.where((e) => e.isEarlyCheckout).length;

    return MonthSummary(
      workingDays: present,
      totalDays: total,
      absentOrLeaves: absentOrLeaves,
      lateCheckIns: lateIns,
      lateCheckOuts: lateOuts,
    );
  }

  void _previousMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1);
      _selectedDay = DateTime(_month.year, _month.month, 1);
    });
    _load();
  }

  void _nextMonth() {
    if (!_canGoNext) return;
    setState(() {
      _month = DateTime(_month.year, _month.month + 1);
      _selectedDay = DateTime(_month.year, _month.month, 1);
    });
    _load();
  }

  void _openDetails(ManagerAttendanceModel employee) {
    final provider = context.read<ManagerAttendanceProvider>();
    final day = _selectedDay;
    ManagerAttendanceDetailsSheet.show(
      context: context,
      data: ManagerAttendanceDetailsData.fromEmployee(
        employee: employee,
        day: day,
      ),
      loadDetails: employee.userId == null
          ? null
          : () => provider.loadEmployeeDay(employee: employee, day: day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<ManagerAttendanceProvider>();
    final employees = context.watch<ManagerEmployeesProvider>();
    final locationItems = _locationItems(
      attendance: attendance,
      employees: employees,
    );
    final filtered = _filteredItems(locationItems);
    final tiles = TeamAttendanceMapper.toTiles(filtered);
    final summary = _summaryFor(locationItems);
    final isLoading =
        (attendance.isLoading || employees.isLoading) && locationItems.isEmpty;
    final hasError =
        (attendance.hasError || employees.hasError) && locationItems.isEmpty;

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
                        _hasStatusFilter ? _statusTitle : widget.locationName,
                        weight: FontWeight.w600,
                      ),
                      if (_hasStatusFilter) ...[
                        const SizedBox(height: 2),
                        AppText.caption(
                          widget.locationName,
                          color: kGreyColor,
                          weight: FontWeight.w400,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else if (widget.locationAddress.trim().isNotEmpty) ...[
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
                  initialDate: _selectedDay,
                  onSelected: (date) {
                    setState(() {
                      _month = DateTime(date.year, date.month);
                      _selectedDay = DateTime(date.year, date.month, date.day);
                    });
                    _load();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : hasError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppText.p1(
                            attendance.errorMessage ??
                                employees.errorMessage ??
                                'Failed to load attendance.',
                            color: kSubText,
                            align: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: tiles.isEmpty ? 2 : tiles.length + 1,
                    separatorBuilder: (context, index) {
                      if (index == 0) return const SizedBox(height: 20);
                      return const Divider(height: 24, color: kDividerColor);
                    },
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return AttendanceSummaryCard(summary: summary);
                      }
                      if (tiles.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: AppText.p1(
                            _hasStatusFilter
                                ? 'No ${_statusTitle.toLowerCase()} records.'
                                : 'No employees assigned to this location.',
                            color: kSubText,
                            align: TextAlign.center,
                          ),
                        );
                      }
                      final item = tiles[index - 1];
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
