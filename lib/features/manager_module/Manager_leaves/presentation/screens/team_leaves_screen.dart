import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/employee_api_endpoints.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_fonts.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/features/employee_module/leaves/data/services/leaves_service.dart';
import 'package:obecno/features/employee_module/leaves/presentation/screens/holidays_calendar_screen.dart';
import 'package:obecno/features/employee_module/leaves/presentation/screens/leave_types_screen.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_format.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_status_chip.dart';
import 'package:obecno/features/manager_module/Manager_attendance/presentation/widgets/filter_dropdown_chip.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_resources.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_locations/providers/manager_locations_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/features/alerts/providers/alerts_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/providers/manager_overview_provider.dart';
import 'package:obecno/main.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/leave_status_filter_sheet.dart';
import 'package:obecno/shared/bottom_sheets/leave_sheets/manager_leave_detail_sheet.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/locations_filter_sheet.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/features/manager_module/Manager_leaves/data/team_leaves_loader.dart';
import 'package:obecno/features/manager_module/Manager_leaves/presentation/team_leaves_colors.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';
import 'package:obecno/widgets/my_button.dart';

class _EmployeeLeaveBar {
  const _EmployeeLeaveBar({
    required this.name,
    required this.taken,
    required this.remaining,
    required this.total,
  });

  final String name;
  final int taken;
  final int remaining;
  final int total;

  double get progress => total <= 0 ? 0.0 : (taken / total).clamp(0.0, 1.0);
}

class TeamLeavesScreen extends StatefulWidget {
  const TeamLeavesScreen({super.key});

  @override
  State<TeamLeavesScreen> createState() => _TeamLeavesScreenState();
}

class _TeamLeavesScreenState extends State<TeamLeavesScreen> {
  static final _monthTitleFormat = DateFormat('MMMM yyyy');

  bool _loading = true;
  String? _error;
  List<ManagerTeamLeaveItem> _requests = const [];
  List<ManagerTeamLeaveItem> _calendarLeaves = const [];
  List<_EmployeeLeaveBar> _usageBars = const [];
  List<HolidayInfo> _monthHolidays = const [];
  List<_CalBirthday> _monthBirthdays = const [];
  final Map<int, List<HolidayInfo>> _holidaysByYear = {};
  final Map<int, Future<void>> _holidaysYearInFlight = {};
  final Map<int, List<ManagerTeamLeaveItem>> _leavesByYear = {};
  final Map<int, Future<void>> _leavesYearInFlight = {};
  final Map<String, _CalBirthday> _birthdaysByKey = {};
  LeaveRequestStatus? _typeFilter;
  String _locationId = LocationFilterOption.allId;
  String? _actingLeaveKey;
  late final TeamLeavesLoader _leavesLoader;

  static const _sectionGap = 12.0;

  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  late DateTime _calendarMonth;

  @override
  void initState() {
    super.initState();
    _leavesLoader = TeamLeavesLoader(bindings.managerOverviewService);
    final now = DateTime.now();
    _rangeStart = DateTime(now.year, 1, 1);
    _rangeEnd = DateTime(now.year, 12, 31);
    _calendarMonth = DateTime(now.year, now.month);
    _load();
  }

  String _yyyyMMdd(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final overview = context.read<ManagerOverviewProvider>();
    final dashboard = overview.dashboard;
    final pendingFromDash = dashboard?.pendingTeamLeaves ?? const [];
    final monthFromDash = dashboard?.teamMonthLeaves ?? const [];

    final locationId = _locationId == LocationFilterOption.allId
        ? null
        : _locationId;
    final dateFrom = _yyyyMMdd(_rangeStart);
    final dateTo = _yyyyMMdd(_rangeEnd);

    final employees = context.read<ManagerEmployeesProvider>();
    Future<List<ManagerTeamLeaveItem>> pull(String status) {
      return _leavesLoader.loadByStatus(
        status: status,
        locationId: locationId,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
    }

    final employeesFuture = employees.members.isEmpty
        ? employees.load()
        : Future<bool>.value(true);

    final batches = await Future.wait([
      _leavesLoader.loadPending(
        locationId: locationId,
        dashboardPending: pendingFromDash,
      ),
      pull('approved'),
      pull('rejected'),
      employeesFuture,
    ]);
    if (!mounted) return;

    final pendingRes = batches[0] as ApiResponse<List<ManagerTeamLeaveItem>>;
    final pending = (pendingRes.data ?? const <ManagerTeamLeaveItem>[])
        .where((e) => e.isPendingInInbox)
        .toList(growable: false);
    // Approved endpoint may omit status — keep non-pending / non-rejected.
    final approved = (batches[1] as List<ManagerTeamLeaveItem>)
        .where((e) => !e.isPendingLeave && !e.isRejectedLeave)
        .toList(growable: false);
    final rejected = (batches[2] as List<ManagerTeamLeaveItem>)
        .where((e) => e.isRejectedLeave)
        .toList(growable: false);

    final merged = <ManagerTeamLeaveItem>[
      ...pending,
      ...pendingFromDash.where((e) => e.isPendingInInbox),
      ...approved,
      ...rejected,
      ...monthFromDash,
    ];

    final byKey = <String, ManagerTeamLeaveItem>{};
    for (final item in merged) {
      // Prefer id-based key so pending + approved of same leave don't collide
      // into one row before review; status stays part of the identity.
      final key = item.id != null
          ? 'id:${item.id}|${item.status ?? item.statusLabel ?? ''}'
          : [
              item.userId?.toString() ?? '',
              item.dateFrom ?? '',
              item.dateTo ?? '',
              item.status ?? item.statusLabel ?? '',
            ].join('|');
      byKey.putIfAbsent(key, () => item);
    }
    final all = byKey.values.toList(growable: false)
      ..sort((a, b) {
        // Pending first, then newest date.
        final aPend = a.isPendingInInbox ? 0 : 1;
        final bPend = b.isPendingInInbox ? 0 : 1;
        if (aPend != bPend) return aPend.compareTo(bPend);
        final aDate =
            ManagerTeamLeaveItem.parseLeaveDate(a.dateFrom) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            ManagerTeamLeaveItem.parseLeaveDate(b.dateFrom) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    final filtered = _typeFilter == null
        ? all
        : all.where((e) => _matchesStatus(e, _typeFilter!)).toList();

    // Paint requests immediately — usage bars load in the background.
    if (!mounted) return;
    setState(() {
      _requests = filtered;
      _loading = false;
      if (all.isEmpty && pendingFromDash.isEmpty && monthFromDash.isEmpty) {
        _error = 'Failed to load.';
      }
    });

    final bars = await _buildUsageBars(members: employees.members);
    if (!mounted) return;
    setState(() => _usageBars = bars);
  }

  List<HolidayInfo> _holidaysForMonth(DateTime month) {
    final yearHolidays = _holidaysByYear[month.year];
    if (yearHolidays == null || yearHolidays.isEmpty) return const [];
    return yearHolidays
        .where((h) => h.date.year == month.year && h.date.month == month.month)
        .toList(growable: false);
  }

  void _mergeYearHolidays(int year, Iterable<HolidayInfo> incoming) {
    final byKey = <String, HolidayInfo>{
      for (final h in _holidaysByYear[year] ?? const <HolidayInfo>[])
        '${h.date.year}-${h.date.month}-${h.date.day}': h,
    };
    for (final holiday in incoming) {
      if (holiday.date.year != year) continue;
      final date = DateTime(
        holiday.date.year,
        holiday.date.month,
        holiday.date.day,
      );
      final key = '${date.year}-${date.month}-${date.day}';
      byKey.putIfAbsent(key, () => HolidayInfo(date: date, name: holiday.name));
    }
    final sorted = byKey.values.toList(growable: false)
      ..sort((a, b) => a.date.compareTo(b.date));
    _holidaysByYear[year] = sorted;
  }

  Future<void> _ensureYearHolidays(int year) async {
    if (_holidaysByYear.containsKey(year)) return;
    final inflight = _holidaysYearInFlight[year];
    if (inflight != null) {
      await inflight;
      return;
    }

    final future = () async {
      // Reuse LeavesStore when it already has this year (current / next).
      try {
        await bindings.leavesStore.ensureHolidaysLoaded();
        final fromStore = bindings.leavesStore.holidays
            .where((h) => h.date.year == year)
            .expand((h) {
              final days = h.days < 1 ? 1 : h.days;
              return List<HolidayInfo>.generate(days, (i) {
                final date = DateTime(
                  h.date.year,
                  h.date.month,
                  h.date.day + i,
                );
                return HolidayInfo(date: date, name: h.name);
              });
            });
        _mergeYearHolidays(year, fromStore);
      } catch (_) {}

      // Year payload from company-calendar.
      try {
        final yearRes = await LeavesService(
          bindings.apiClient,
        ).getCompanyHolidaysForYear(year);
        if (yearRes.success && yearRes.data != null) {
          final expanded = yearRes.data!.expand((h) {
            final days = h.days < 1 ? 1 : h.days;
            return List<HolidayInfo>.generate(days, (i) {
              final date = DateTime(h.date.year, h.date.month, h.date.day + i);
              return HolidayInfo(date: date, name: h.name);
            });
          });
          _mergeYearHolidays(year, expanded);
        }
      } catch (_) {}

      // Month-by-month fill: holidays + birthdays for previous / future months.
      const chunkSize = 6;
      for (var start = 1; start <= 12; start += chunkSize) {
        final end = math.min(start + chunkSize - 1, 12);
        final keys = [
          for (var m = start; m <= end; m++)
            '$year-${m.toString().padLeft(2, '0')}',
        ];
        await Future.wait(keys.map(_fetchCalendarExtrasForMonth));
        // Fallback holidays parse if extras path returned nothing useful.
        final responses = await Future.wait(
          keys.map(
            (month) =>
                bindings.attendanceService.getCompanyHolidays(month: month),
          ),
        );
        for (final response in responses) {
          if (!response.success || response.data == null) continue;
          _mergeYearHolidays(year, response.data!);
        }
      }

      _holidaysByYear.putIfAbsent(year, () => const <HolidayInfo>[]);
    }();

    _holidaysYearInFlight[year] = future;
    try {
      await future;
    } finally {
      if (identical(_holidaysYearInFlight[year], future)) {
        _holidaysYearInFlight.remove(year);
      }
    }
  }

  List<_CalBirthday> _birthdaysForMonth(DateTime month) {
    return _birthdaysByKey.values
        .where((b) => b.month == month.month)
        .map(
          (b) => _CalBirthday(
            month: b.month,
            day: b.dayForYear(month.year),
            name: b.name,
          ),
        )
        .toList(growable: false);
  }

  List<ManagerTeamLeaveItem> _leavesForCalendar() {
    final byKey = <String, ManagerTeamLeaveItem>{};
    for (final list in _leavesByYear.values) {
      for (final item in list) {
        final key = [
          item.id?.toString() ?? '',
          item.userId?.toString() ?? '',
          item.dateFrom ?? '',
          item.dateTo ?? '',
          item.status ?? item.statusLabel ?? '',
        ].join('|');
        byKey.putIfAbsent(key, () => item);
      }
    }
    return byKey.values.toList(growable: false);
  }

  void _mergeYearLeaves(int year, Iterable<ManagerTeamLeaveItem> incoming) {
    final byKey = <String, ManagerTeamLeaveItem>{
      for (final item in _leavesByYear[year] ?? const <ManagerTeamLeaveItem>[])
        [
          item.id?.toString() ?? '',
          item.userId?.toString() ?? '',
          item.dateFrom ?? '',
          item.dateTo ?? '',
          item.status ?? item.statusLabel ?? '',
        ].join('|'): item,
    };
    for (final item in incoming) {
      if (item.isRejectedLeave) continue;
      final key = [
        item.id?.toString() ?? '',
        item.userId?.toString() ?? '',
        item.dateFrom ?? '',
        item.dateTo ?? '',
        item.status ?? item.statusLabel ?? '',
      ].join('|');
      byKey.putIfAbsent(key, () => item);
    }
    _leavesByYear[year] = byKey.values.toList(growable: false);
  }

  void _mergeBirthdays(Iterable<_CalBirthday> incoming) {
    for (final birthday in incoming) {
      final key =
          '${birthday.month}-${birthday.day}-${birthday.name.toLowerCase()}';
      _birthdaysByKey.putIfAbsent(key, () => birthday);
    }
  }

  Future<void> _ensureLeavesForYear(int year) async {
    if (_leavesByYear.containsKey(year)) return;
    final inflight = _leavesYearInFlight[year];
    if (inflight != null) {
      await inflight;
      return;
    }

    final future = () async {
      final locationId = _locationId == LocationFilterOption.allId
          ? null
          : _locationId;
      final dateFrom = '$year-01-01';
      final dateTo = '$year-12-31';

      Future<List<ManagerTeamLeaveItem>> pull(String status) async {
        try {
          return await _leavesLoader.loadByStatus(
            status: status,
            locationId: locationId,
            dateFrom: dateFrom,
            dateTo: dateTo,
          );
        } catch (_) {
          return const [];
        }
      }

      final batches = await Future.wait([pull('pending'), pull('approved')]);
      _mergeYearLeaves(year, [...batches[0], ...batches[1]]);
      _leavesByYear.putIfAbsent(year, () => const <ManagerTeamLeaveItem>[]);
    }();

    _leavesYearInFlight[year] = future;
    try {
      await future;
    } finally {
      if (identical(_leavesYearInFlight[year], future)) {
        _leavesYearInFlight.remove(year);
      }
    }
  }

  Future<void> _ensureCalendarDataForMonth(DateTime month) async {
    final prev = DateTime(month.year, month.month - 1);
    final next = DateTime(month.year, month.month + 1);
    final years = <int>{prev.year, month.year, next.year};
    await Future.wait([
      ...years.map(_ensureYearHolidays),
      ...years.map(_ensureLeavesForYear),
      _loadBirthdaysAroundMonth(month),
    ]);
    if (!mounted) return;
    setState(() {
      _monthHolidays = _holidaysForMonth(month);
      _monthBirthdays = _birthdaysForMonth(month);
      _calendarLeaves = _leavesForCalendar();
    });
  }

  Future<void> _loadBirthdaysAroundMonth(DateTime month) async {
    final months = <String>[
      for (final m in [
        DateTime(month.year, month.month - 1),
        month,
        DateTime(month.year, month.month + 1),
      ])
        '${m.year.toString().padLeft(4, '0')}-'
            '${m.month.toString().padLeft(2, '0')}',
    ];

    await Future.wait(months.map(_fetchCalendarExtrasForMonth));
  }

  Future<void> _fetchCalendarExtrasForMonth(String monthKey) async {
    // Prefer manager team-calendar (portal parity), then employee company-calendar.
    for (final path in [
      ManagerEmployeeApiEndpoints.teamCalendar,
      EmployeeApiEndpoints.companyCalendar,
    ]) {
      try {
        final raw = await bindings.apiClient.get(
          path,
          queryParameters: {'month': monthKey},
        );
        if (raw.statusCode >= 400) continue;
        final parsed = _parseCompanyCalendarExtras(raw.data);
        if (parsed.holidays.isNotEmpty ||
            parsed.birthdays.isNotEmpty ||
            parsed.leaves.isNotEmpty) {
          final year =
              int.tryParse(monthKey.split('-').first) ?? DateTime.now().year;
          _mergeYearHolidays(year, parsed.holidays);
          _mergeBirthdays(parsed.birthdays);
          if (parsed.leaves.isNotEmpty) {
            _mergeYearLeaves(year, parsed.leaves);
          }
          return;
        }
      } catch (_) {}
    }
  }

  _CompanyCalExtras _parseCompanyCalendarExtras(dynamic json) {
    final holidays = <HolidayInfo>[];
    final birthdays = <_CalBirthday>[];
    final leaves = <ManagerTeamLeaveItem>[];
    final seenHoliday = <String>{};
    final seenBirthday = <String>{};

    DateTime? asDate(dynamic raw) {
      if (raw == null) return null;
      return ManagerTeamLeaveItem.parseLeaveDate(raw.toString()) ??
          DateTime.tryParse(raw.toString().trim());
    }

    String typeOf(Map<String, dynamic> map) =>
        (map['type'] ??
                map['event_type'] ??
                map['eventType'] ??
                map['category'] ??
                map['kind'] ??
                map['event'] ??
                map['status'] ??
                map['day_status'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();

    String nameOf(Map<String, dynamic> map) {
      final raw =
          map['name'] ??
          map['title'] ??
          map['label'] ??
          map['employee_name'] ??
          map['user_name'] ??
          map['full_name'] ??
          map['person_name'] ??
          map['holiday_name'] ??
          map['event_name'];
      if (raw is Map) {
        return (raw['name'] ?? raw['full_name'] ?? raw['title'] ?? '')
            .toString()
            .trim();
      }
      return (raw ?? '').toString().trim();
    }

    void consume(dynamic node) {
      if (node is List) {
        for (final item in node) {
          consume(item);
        }
        return;
      }
      if (node is! Map) return;
      final map = Map<String, dynamic>.from(node);
      final type = typeOf(map);

      for (final key in const [
        'events',
        'items',
        'days',
        'entries',
        'calendar',
        'weeks',
        'holidays',
        'public_holidays',
        'holiday_dates',
        'birthdays',
        'birthday_dates',
        'leaves',
        'team_leaves',
        'approved_leaves',
        'pending_leaves',
        'data',
      ]) {
        if (map[key] != null) consume(map[key]);
      }

      final date = asDate(
        map['date'] ??
            map['holiday_date'] ??
            map['birthday_date'] ??
            map['day'] ??
            map['start_date'] ??
            map['from_date'] ??
            map['date_from'],
      );

      final isBirthday =
          type.contains('birthday') ||
          map['is_birthday'] == true ||
          map['isBirthday'] == true;
      final isHoliday =
          type.contains('holiday') ||
          map['is_holiday'] == true ||
          map['isHoliday'] == true;
      final isLeave =
          type.contains('leave') ||
          map['leave_type'] != null ||
          map['leave_type_id'] != null ||
          map['date_from'] != null;

      if (isBirthday && date != null) {
        final name = nameOf(map);
        if (name.isEmpty) return;
        final key = '${date.month}-${date.day}-${name.toLowerCase()}';
        if (seenBirthday.add(key)) {
          birthdays.add(
            _CalBirthday(month: date.month, day: date.day, name: name),
          );
        }
        return;
      }

      if (isHoliday && date != null) {
        final name = nameOf(map);
        final key = '${date.year}-${date.month}-${date.day}';
        if (seenHoliday.add(key)) {
          holidays.add(
            HolidayInfo(
              date: DateTime(date.year, date.month, date.day),
              name: name.isEmpty ? 'Public Holiday' : name,
            ),
          );
        }
        return;
      }

      if (isLeave && !isBirthday) {
        // Only accept leave-looking rows that have a date range / employee.
        if (map['date_from'] != null ||
            map['from_date'] != null ||
            map['start_date'] != null ||
            type.contains('leave')) {
          try {
            leaves.add(ManagerTeamLeaveItem.fromJson(map));
          } catch (_) {}
        }
      }
    }

    consume(json);
    return _CompanyCalExtras(
      holidays: holidays,
      birthdays: birthdays,
      leaves: leaves,
    );
  }

  Future<void> _shiftCalendarMonth(int delta) async {
    final next = DateTime(_calendarMonth.year, _calendarMonth.month + delta);
    setState(() {
      _calendarMonth = next;
      _monthHolidays = _holidaysForMonth(next);
      _monthBirthdays = _birthdaysForMonth(next);
      _calendarLeaves = _leavesForCalendar();
    });
    await _ensureCalendarDataForMonth(next);
  }

  /// Overall leave balances per employee (taken / remaining / total).
  Future<List<_EmployeeLeaveBar>> _buildUsageBars({
    required List<ManagerEmployeeModel> members,
  }) async {
    final active = members
        .where((m) => m.status != ManagerEmployeeStatus.deleted)
        .toList(growable: false);
    if (active.isEmpty) return const [];

    final service = bindings.managerEmployeesService;
    // Cap parallel balance calls — enough for the usage card, keeps load snappy.
    final limited = active.take(8).toList(growable: false);
    final bars = await Future.wait(
      limited.map((member) async {
        final userId = member.userId;
        var entitled = 0;
        var used = 0;
        var remaining = 0;
        if (userId != null) {
          try {
            final res = await service.loadEmployeeLeaveBalances(userId: userId);
            if (res.success && res.data != null) {
              for (final balance in res.data!) {
                final totals = _balanceTotals(balance);
                entitled += totals.$1;
                used += totals.$2;
                remaining += totals.$3;
              }
            }
          } catch (_) {}
        }

        var total = entitled;
        if (total <= 0) total = used + remaining;
        if (total <= 0) total = math.max(used, 0);
        final taken = used.clamp(0, total > 0 ? total : used);
        final left = total > 0
            ? (total - taken).clamp(0, total)
            : remaining.clamp(0, 999);

        return _EmployeeLeaveBar(
          name: member.name.trim().isEmpty ? 'Employee' : member.name.trim(),
          taken: taken,
          remaining: left,
          total: total > 0 ? total : (taken + left),
        );
      }),
    );

    final filtered = bars
        .where((b) => b.total > 0 || b.taken > 0)
        .toList(growable: false);
    return filtered.isEmpty ? bars : filtered;
  }

  (int, int, int) _balanceTotals(ManagerEmployeeLeaveBalance balance) {
    final entitled = _asInt(balance.entitled);
    final used = _asInt(balance.used);
    var remaining = _asInt(balance.remaining);
    if (remaining <= 0 && entitled > 0) {
      remaining = (entitled - used).clamp(0, entitled);
    }
    final total = entitled > 0 ? entitled : used + remaining;
    return (total, used, remaining);
  }

  int _asInt(String? raw) {
    if (raw == null) return 0;
    final cleaned = raw.trim().replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return 0;
    return double.tryParse(cleaned)?.round() ?? int.tryParse(cleaned) ?? 0;
  }

  bool _matchesStatus(ManagerTeamLeaveItem item, LeaveRequestStatus status) {
    return switch (status) {
      LeaveRequestStatus.pending => item.isPendingInInbox,
      LeaveRequestStatus.approved => item.countsAsOnLeave,
      LeaveRequestStatus.rejected => item.isRejectedLeave,
    };
  }

  bool get _hasTypeFilter => _typeFilter != null;

  String get _typeChipLabel {
    if (_typeFilter == null) return 'All statuses';
    return switch (_typeFilter!) {
      LeaveRequestStatus.pending => 'Pending',
      LeaveRequestStatus.approved => 'Approved',
      LeaveRequestStatus.rejected => 'Rejected',
    };
  }

  int get _pendingRequestCount =>
      _requests.where((e) => e.isPendingInInbox).length;

  String get _requestsSectionTitle {
    if (_typeFilter == null) {
      final pending = _pendingRequestCount;
      if (pending > 0) return 'Leave requests · $pending pending';
      return 'Leave requests';
    }
    return switch (_typeFilter!) {
      LeaveRequestStatus.pending => 'Pending requests',
      LeaveRequestStatus.approved => 'Approved requests',
      LeaveRequestStatus.rejected => 'Rejected requests',
    };
  }

  bool get _hasLocationFilter => _locationId != LocationFilterOption.allId;

  String get _locationChipLabel {
    if (!_hasLocationFilter) return 'Locations';
    return context.read<ManagerLocationsProvider>().byId(_locationId)?.name ??
        'Locations';
  }

  Future<void> _openTypeFilter() async {
    final result = await LeaveStatusFilterSheet.show(
      context,
      selected: _typeFilter,
    );
    if (result == null || !mounted) return;
    setState(() => _typeFilter = result.status);
    await _load();
  }

  Future<void> _openLocationFilter() async {
    final locations = context.read<ManagerLocationsProvider>();
    await locations.load();
    if (!mounted) return;
    final selected = await LocationsFilterSheet.show(
      context,
      locations: locations.filterOptions,
      selectedId: _locationId,
    );
    if (selected == null || !mounted) return;
    setState(() => _locationId = selected);
    await _load();
  }

  void _clearTypeFilter() {
    setState(() => _typeFilter = null);
    _load();
  }

  void _clearLocationFilter() {
    setState(() => _locationId = LocationFilterOption.allId);
    _load();
  }

  String? _employeePhotoFor(ManagerTeamLeaveItem item) {
    final direct = item.employeePhoto?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final members = context.read<ManagerEmployeesProvider>().members;
    final userId = item.userId;
    if (userId != null) {
      for (final member in members) {
        if (member.userId == userId) {
          final photo = member.photo?.trim();
          if (photo != null && photo.isNotEmpty) return photo;
        }
      }
    }
    final name = (item.employeeName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final member in members) {
      if (member.name.trim().toLowerCase() == name) {
        final photo = member.photo?.trim();
        if (photo != null && photo.isNotEmpty) return photo;
      }
    }
    return null;
  }

  Future<void> _openLeave(ManagerTeamLeaveItem item) async {
    final changed = await ManagerLeaveDetailSheet.show(
      context: context,
      leave: ManagerLeaveView.fromTeamItem(item),
      employeeName: item.employeeName,
      employeePhoto: _employeePhotoFor(item),
    );
    if ((changed == true ||
            changed == 'approve' ||
            changed == 'reject') &&
        mounted) {
      if (changed == 'approve' || changed == 'reject') {
        unawaited(
          context.read<AlertsProvider>().archiveLeaveReview(
            item,
            changed as String,
          ),
        );
      } else {
        unawaited(context.read<AlertsProvider>().syncLeaveAlerts());
      }
      await _load();
      if (!mounted) return;
      unawaited(context.read<ManagerOverviewProvider>().refresh());
    }
  }

  Future<void> _reviewLeave(ManagerTeamLeaveItem item, String action) async {
    final id = item.id;
    if (id == null) {
      ToastHelper.error(context, message: 'Missing leave id');
      return;
    }
    setState(() => _actingLeaveKey = 'leave_$id');
    final result = await _leavesLoader.review(
      leaveId: id,
      action: action,
    );
    if (!mounted) return;
    setState(() => _actingLeaveKey = null);
    if (!result.success) {
      ToastHelper.error(
        context,
        message: result.message ?? 'Unable to $action leave',
      );
      return;
    }
    ToastHelper.success(
      context,
      message: action == 'approve' ? 'Leave approved' : 'Leave rejected',
    );
    unawaited(
      context.read<AlertsProvider>().archiveLeaveReview(item, action),
    );
    await _load();
    if (!mounted) return;
    unawaited(context.read<ManagerOverviewProvider>().refresh());
  }

  /// Same thresholds as Leave Types screen progress colors.
  static Color _colorForProgress(double progress) {
    if (progress <= 0) return kTransperentColor;
    if (progress <= 0.33) return kPrimaryColor;
    if (progress < 0.7) return kPurple;
    return kredColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kbackground1,
      body: Padding(
        padding: AppSizes.page(context),
        child: Column(
          children: [
            const BackButtonBg(
              title: 'Team Leaves',
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            const SizedBox(height: 10),
            _filtersRow(),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: ShimmerProgress())
                  : ShimmerRefreshIndicator(
                      instagramStyle: true,
                      triggerFraction: 0.40,
                      showOrb: false,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: _sectionGap),
                              child: AppText.p2(_error!, color: kGreyColor),
                            ),
                          _linksCard(),
                          const SizedBox(height: _sectionGap),
                          _requestsSection(),
                          const SizedBox(height: _sectionGap),
                          _usageCard(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtersRow() {
    return Row(
      children: [
        Expanded(
          child: _hasTypeFilter
              ? SelectedFilterChip(
                  label: _typeChipLabel,
                  onClear: _clearTypeFilter,
                  onTap: _openTypeFilter,
                )
              : FilterChipButton(label: _typeChipLabel, onTap: _openTypeFilter),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _hasLocationFilter
              ? SelectedFilterChip(
                  label: _locationChipLabel,
                  onClear: _clearLocationFilter,
                  onTap: _openLocationFilter,
                )
              : FilterChipButton(
                  label: _locationChipLabel,
                  onTap: _openLocationFilter,
                ),
        ),
      ],
    );
  }

  Widget _requestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.p1(
          _requestsSectionTitle,
          weight: FontWeight.w600,
          align: TextAlign.left,
        ),
        const SizedBox(height: _sectionGap),
        if (_requests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kBorderColor),
            ),
            child: AppText.p2(
              'No leave requests',
              color: kGreyColor,
              align: TextAlign.center,
            ),
          )
        else
          for (var i = 0; i < _requests.length; i++) ...[
            if (i > 0) const SizedBox(height: _sectionGap),
            _TeamLeaveRequestCard(
              item: _requests[i],
              busy: _actingLeaveKey == 'leave_${_requests[i].id}',
              onTap: () => _openLeave(_requests[i]),
              onApprove: _requests[i].isPendingInInbox
                  ? () => _reviewLeave(_requests[i], 'approve')
                  : null,
              onReject: _requests[i].isPendingInInbox
                  ? () => _reviewLeave(_requests[i], 'reject')
                  : null,
            ),
          ],
      ],
    );
  }

  Widget _usageCard() {
    final bars = _usageBars;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.p1(
            'Leave usage',
            weight: FontWeight.w600,
            align: TextAlign.left,
          ),
          const SizedBox(height: 14),
          if (bars.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: AppText.p2('No leave usage yet', color: kGreyColor),
              ),
            )
          else
            for (var i = 0; i < bars.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              _EmployeeLeaveUsageRow(
                bar: bars[i],
                colorForProgress: _colorForProgress,
              ),
            ],
          if (bars.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _legendItem(kPrimaryColor, 'Low usage'),
                _legendItem(kPurple, 'Moderate'),
                _legendItem(kredColor, 'High usage'),
                _legendItem(kLinearProgressbgGreyColor, 'Remaining'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        AppText.caption(label, color: kGreyColor150, weight: FontWeight.w400),
      ],
    );
  }

  String _shortName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final value = parts.first;
      return value.length <= 8 ? value : '${value.substring(0, 7)}…';
    }
    return '${parts.first} ${parts.last[0]}.';
  }

  Widget _linksCard() {
    Widget row({
      required String icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return ButtonAnimations.press(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CommonImageView(imagePath: icon, height: 20, width: 20),
              const SizedBox(width: 12),
              Expanded(
                child: AppText.p1(
                  label,
                  weight: FontWeight.w500,
                  align: TextAlign.left,
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: kGreyColor,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          row(
            icon: Assets.imagesLeaveIcon,
            label: 'Leave types',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LeaveTypesScreen()),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: kBorderColor),
          ),
          row(
            icon: Assets.imagesLeavesFilledIcon,
            label: 'Holidays calendar',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HolidaysCalendarScreen(
                    mode: HolidaysCalendarMode.manager,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmployeeLeaveUsageRow extends StatelessWidget {
  const _EmployeeLeaveUsageRow({
    required this.bar,
    required this.colorForProgress,
  });

  final _EmployeeLeaveBar bar;
  final Color Function(double progress) colorForProgress;

  @override
  Widget build(BuildContext context) {
    final progress = bar.progress;
    final fillColor = colorForProgress(progress);
    final ratioColor = bar.taken <= 0 ? kBlack : fillColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                bar.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.Poppins,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kBlack,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${bar.taken}/${bar.total}',
              style: TextStyle(
                fontFamily: AppFonts.Poppins,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ratioColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: kLinearProgressbgGreyColor.withValues(
                  alpha: 0.85,
                ),
                color: fillColor == kTransperentColor
                    ? kLinearProgressbgGreyColor
                    : fillColor,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CalBirthday {
  const _CalBirthday({
    required this.month,
    required this.day,
    required this.name,
  });

  final int month;
  final int day;
  final String name;

  int dayForYear(int year) {
    if (month == 2 && day == 29) {
      final isLeap =
          (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));
      return isLeap ? 29 : 28;
    }
    return day;
  }

  bool matchesDay(DateTime day) =>
      month == day.month && dayForYear(day.year) == day.day;
}

class _CompanyCalExtras {
  const _CompanyCalExtras({
    required this.holidays,
    required this.birthdays,
    required this.leaves,
  });

  final List<HolidayInfo> holidays;
  final List<_CalBirthday> birthdays;
  final List<ManagerTeamLeaveItem> leaves;
}

class _TeamCompanyCalendarGrid extends StatefulWidget {
  const _TeamCompanyCalendarGrid({
    super.key,
    required this.month,
    required this.holidays,
    required this.birthdays,
    required this.leaves,
    required this.shortName,
  });

  final DateTime month;
  final List<HolidayInfo> holidays;
  final List<_CalBirthday> birthdays;
  final List<ManagerTeamLeaveItem> leaves;
  final String Function(String name) shortName;

  @override
  State<_TeamCompanyCalendarGrid> createState() =>
      _TeamCompanyCalendarGridState();
}

class _TeamCompanyCalendarGridState extends State<_TeamCompanyCalendarGrid> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static final _bubbleDateFormat = DateFormat('d MMMM yyyy');
  static const _cellGap = 5.0;

  OverlayEntry? _bubbleEntry;

  @override
  void dispose() {
    _removeBubble();
    super.dispose();
  }

  Map<String, HolidayInfo> get _holidayByDay {
    final map = <String, HolidayInfo>{};
    for (final h in widget.holidays) {
      final key =
          '${h.date.year}-${h.date.month.toString().padLeft(2, '0')}-'
          '${h.date.day.toString().padLeft(2, '0')}';
      map[key] = h;
    }
    return map;
  }

  String _leaveStatusLabel(ManagerTeamLeaveItem leave) {
    if (leave.isPendingLeave) return 'Pending';
    if (leave.countsAsOnLeave) return 'Approved';
    final label = (leave.statusLabel ?? leave.status ?? '').trim();
    if (label.isEmpty) return 'Leave';
    if (label.length == 1) return label.toUpperCase();
    return '${label[0].toUpperCase()}${label.substring(1).toLowerCase()}';
  }

  List<_CalDayEvent> _eventsFor(DateTime day) {
    final events = <_CalDayEvent>[];
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final holiday = _holidayByDay[key];
    if (holiday != null) {
      final name = holiday.name.trim();
      events.add(
        _CalDayEvent(
          label: name.isEmpty ? 'Holiday' : name,
          kind: _CalEventKind.holiday,
        ),
      );
    }
    for (final birthday in widget.birthdays) {
      if (!birthday.matchesDay(day)) continue;
      final name = birthday.name.trim();
      events.add(
        _CalDayEvent(
          label: name.isEmpty
              ? 'Birthday'
              : 'Bday · ${widget.shortName(name)}',
          kind: _CalEventKind.birthday,
        ),
      );
    }

    for (final leave in widget.leaves) {
      if (!leave.coversDay(day) || leave.isRejectedLeave) continue;
      final name = (leave.employeeName ?? 'Employee').trim();
      final type = (leave.leaveType ?? '').trim();
      final who = widget.shortName(name);
      events.add(
        _CalDayEvent(
          label: type.isEmpty ? who : '$who · $type',
          kind: leave.isPendingLeave
              ? _CalEventKind.pendingLeave
              : _CalEventKind.approvedLeave,
        ),
      );
    }
    return events;
  }

  List<String> _bubbleLinesFor(DateTime day) {
    final lines = <String>[];
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final holiday = _holidayByDay[key];
    if (holiday != null) {
      lines.add('Holiday: ${holiday.name}');
    }
    for (final birthday in widget.birthdays) {
      if (!birthday.matchesDay(day)) continue;
      lines.add('Birthday: ${birthday.name}');
    }
    for (final leave in widget.leaves) {
      if (!leave.coversDay(day) || leave.isRejectedLeave) continue;
      final name = (leave.employeeName ?? 'Employee').trim();
      final type = (leave.leaveType ?? 'Leave').trim();
      final status = _leaveStatusLabel(leave);
      lines.add('Leave: $name — $type ($status)');
    }
    if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      if (lines.isEmpty) {
        lines.add(day.weekday == DateTime.saturday ? 'Saturday' : 'Sunday');
      }
    }
    return lines;
  }

  void _removeBubble() {
    _bubbleEntry?.remove();
    _bubbleEntry = null;
  }

  void _showBubble({
    required BuildContext context,
    required Offset globalPosition,
    required DateTime day,
  }) {
    _removeBubble();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final media = MediaQuery.of(context);
    final lines = _bubbleLinesFor(day);
    final displayLines = lines.isEmpty
        ? <String>[_bubbleDateFormat.format(day)]
        : lines;

    const bubbleMaxWidth = 280.0;
    final left = (globalPosition.dx - 24).clamp(
      12.0,
      media.size.width - bubbleMaxWidth - 12,
    );
    final top = (globalPosition.dy - 12).clamp(
      media.padding.top + 8,
      media.size.height - 160,
    );

    _bubbleEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _removeBubble,
                onPanDown: (_) => _removeBubble(),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: bubbleMaxWidth,
                    maxHeight: 220,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: kTeamCalBubbleBg,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: kBlack.withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < displayLines.length; i++) ...[
                            if (i > 0) const SizedBox(height: 6),
                            Text(
                              displayLines[i],
                              style: const TextStyle(
                                fontFamily: AppFonts.Poppins,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: kWhite,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_bubbleEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(widget.month.year, widget.month.month, 1);
    final daysInMonth = DateTime(
      widget.month.year,
      widget.month.month + 1,
      0,
    ).day;
    final leading = first.weekday - 1; // Monday-start
    final weekCount = ((leading + daysInMonth + 6) ~/ 7);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - (_cellGap * 6)) / 7;
        var maxEvents = 0;
        for (var d = 1; d <= daysInMonth; d++) {
          final count = _eventsFor(
            DateTime(widget.month.year, widget.month.month, d),
          ).length;
          if (count > maxEvents) maxEvents = count;
        }
        // Tall enough for day number + every birthday/leave/holiday chip.
        final cellHeight = math.max(
          cellWidth,
          24.0 + (math.max(maxEvents, 1) * 18.0),
        );

        return Column(
          children: [
            Row(
              children: [
                for (var i = 0; i < _weekdays.length; i++) ...[
                  if (i > 0) const SizedBox(width: _cellGap),
                  SizedBox(
                    width: cellWidth,
                    child: Text(
                      _weekdays[i],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppFonts.Poppins,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: kGreyColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: _cellGap),
            for (var row = 0; row < weekCount; row++) ...[
              if (row > 0) const SizedBox(height: _cellGap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var col = 0; col < 7; col++) ...[
                    if (col > 0) const SizedBox(width: _cellGap),
                    SizedBox(
                      width: cellWidth,
                      height: cellHeight,
                      child: _buildCell(
                        cellIndex: row * 7 + col,
                        leading: leading,
                        daysInMonth: daysInMonth,
                        todayOnly: todayOnly,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCell({
    required int cellIndex,
    required int leading,
    required int daysInMonth,
    required DateTime todayOnly,
  }) {
    final dayNum = cellIndex - leading + 1;
    final inMonth = dayNum >= 1 && dayNum <= daysInMonth;

    if (!inMonth) {
      return Container(
        decoration: BoxDecoration(
          color: kWhite.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(kTeamCalCellRadius),
          border: Border.all(color: kBorderColor.withValues(alpha: 0.45)),
        ),
      );
    }

    final day = DateTime(widget.month.year, widget.month.month, dayNum);
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final isToday = day == todayOnly;
    final events = _eventsFor(day);
    final hasLeave = events.any(
      (e) =>
          e.kind == _CalEventKind.approvedLeave ||
          e.kind == _CalEventKind.pendingLeave,
    );
    final hasPendingOnly =
        hasLeave &&
        events.every(
          (e) =>
              e.kind == _CalEventKind.holiday ||
              e.kind == _CalEventKind.birthday ||
              e.kind == _CalEventKind.pendingLeave,
        ) &&
        events.any((e) => e.kind == _CalEventKind.pendingLeave);
    final hasHoliday = events.any((e) => e.kind == _CalEventKind.holiday);
    final hasBirthday = events.any((e) => e.kind == _CalEventKind.birthday);

    late final Color fill;
    late final Color border;
    if (hasLeave) {
      fill = hasPendingOnly ? kTeamCalPendingFill : kTeamCalLeaveFill;
      border = hasPendingOnly ? kTeamCalPendingLeave : kTeamCalLeaveBorder;
    } else if (hasHoliday) {
      fill = kTeamCalHolidayFill;
      border = kTeamCalHoliday;
    } else if (hasBirthday) {
      fill = kTeamCalBirthdayFill;
      border = kTeamCalBirthday;
    } else if (isWeekend) {
      fill = kTeamCalWeekendBg;
      border = kTeamCalWeekend;
    } else {
      fill = kWhite;
      border = kBorderColor;
    }

    Color chipColor(_CalEventKind kind) => switch (kind) {
      _CalEventKind.holiday => kTeamCalHoliday,
      _CalEventKind.birthday => kTeamCalBirthday,
      _CalEventKind.pendingLeave => kTeamCalPendingLeave,
      _ => kTeamCalApprovedLeave,
    };

    Color chipText(_CalEventKind kind) => switch (kind) {
      _CalEventKind.holiday => kTeamCalHoliday,
      _CalEventKind.birthday => const Color(0xFFAD1457),
      _CalEventKind.pendingLeave => const Color(0xFF8A6A00),
      _ => kTeamCalLeaveText,
    };

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.none,
      child: InkWell(
        borderRadius: BorderRadius.circular(kTeamCalCellRadius),
        onTapDown: (details) {
          _showBubble(
            context: context,
            globalPosition: details.globalPosition,
            day: day,
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(kTeamCalCellRadius),
            border: Border.all(
              color: isToday ? kTeamCalTodayBorder : border,
              width: isToday ? 1.8 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  '$dayNum',
                  style: TextStyle(
                    fontFamily: AppFonts.Poppins,
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                    color: hasLeave ? kTeamCalLeaveText : kBlack200,
                  ),
                ),
                if (events.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  for (var i = 0; i < events.length; i++) ...[
                    if (i > 0) const SizedBox(height: 2),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: kWhite.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: chipColor(events[i].kind).withValues(
                            alpha: 0.55,
                          ),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: chipColor(events[i].kind),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              events[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppFonts.Poppins,
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: chipText(events[i].kind),
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _CalEventKind { holiday, birthday, approvedLeave, pendingLeave }

class _CalDayEvent {
  const _CalDayEvent({required this.label, required this.kind});

  final String label;
  final _CalEventKind kind;
}

class _TeamLeaveRequestCard extends StatelessWidget {
  const _TeamLeaveRequestCard({
    required this.item,
    required this.onTap,
    this.busy = false,
    this.onApprove,
    this.onReject,
  });

  final ManagerTeamLeaveItem item;
  final VoidCallback onTap;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  String? _photoFor(BuildContext context) {
    final employees = context.watch<ManagerEmployeesProvider>().members;
    final userId = item.userId;
    if (userId != null) {
      for (final member in employees) {
        if (member.userId == userId) {
          final photo = member.photo?.trim();
          if (photo != null && photo.isNotEmpty) return photo;
        }
      }
    }
    final name = (item.employeeName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final member in employees) {
      if (member.name.trim().toLowerCase() == name) {
        final photo = member.photo?.trim();
        if (photo != null && photo.isNotEmpty) return photo;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final view = ManagerLeaveView.fromTeamItem(item);
    final name = (item.employeeName ?? 'Employee').trim();
    final photo = _photoFor(context);
    final showActions = onApprove != null || onReject != null;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: CommonImageView(
                  imagePath: photo ?? Assets.imagesUserimage,
                  height: 36,
                  width: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.p1(
                      name.isEmpty ? 'Employee' : name,
                      weight: FontWeight.w600,
                      align: TextAlign.left,
                    ),
                    const SizedBox(height: 2),
                    AppText.p2(
                      view.typeName,
                      color: kGreyColor,
                      weight: FontWeight.w400,
                      align: TextAlign.left,
                    ),
                  ],
                ),
              ),
              LeaveStatusChip(status: view.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppText.p2(
                  LeaveFormat.rangeWithDays(
                    view.startDate,
                    view.endDate,
                    view.dayCount,
                  ),
                  color: kBlack200,
                  weight: FontWeight.w500,
                  align: TextAlign.left,
                ),
              ),
              if (!showActions)
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: kGreyColor,
                ),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: 14),
            if (busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: MyButton(
                      size: MyButtonSize.normal,
                      compact: false,
                      radius: 30,
                      height: 36,
                      buttonText: 'Approve',
                      backgroundColor: kPrimaryColor,
                      fontColor: kWhite,
                      onTap: () async => onApprove?.call(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MyButton(
                      size: MyButtonSize.normal,
                      compact: false,
                      radius: 30,
                      height: 36,
                      buttonText: 'Reject',
                      backgroundColor: kredColor,
                      fontColor: kWhite,
                      onTap: () async => onReject?.call(),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );

    return ButtonAnimations.press(onTap: onTap, child: card);
  }
}
