import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:obecno/core/animations/app_animations.dart';
import 'package:obecno/core/animations/app_shimmer.dart';
import 'package:obecno/core/api/employee_api_endpoints.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/core/constants/all_colors.dart';
import 'package:obecno/core/constants/app_fonts.dart';
import 'package:obecno/core/constants/app_sizes.dart';
import 'package:obecno/core/constants/text_styles.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:obecno/core/state/change_notifier_provider.dart';
import 'package:obecno/features/employee_module/leaves/data/leaves_store.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/features/employee_module/leaves/data/services/leaves_service.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/employee_module/leaves/presentation/widgets/leave_format.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/features/manager_module/Manager_overview/providers/manager_overview_provider.dart';
import 'package:obecno/main.dart';
import 'package:obecno/widgets/back_button.dart';
import 'package:obecno/widgets/common_image_view_widget.dart';

const _kCalWeekend = Color(0xFFDDE1E6);
const _kCalWeekendBg = Color(0xFFF3F4F6);
const _kCalHoliday = Color(0xFF5B8DEF);
const _kCalHolidayFill = Color(0xFFE8F0FE);
const _kCalBirthday = Color(0xFFF48FB1);
const _kCalBirthdayFill = Color(0xFFFDE8F0);
const _kCalApprovedLeave = kPrimaryColor;
const _kCalPendingLeave = kYellowColor;
const _kCalLeaveFill = Color(0xFFE6F9F0);
const _kCalLeaveBorder = kPrimaryColor;
const _kCalPendingFill = Color(0xFFFFF8E1);
const _kCalLeaveText = Color(0xFF0A7A45);
const _kCalTodayBorder = Color(0xFF1A2332);
const _kCalBubbleBg = Color(0xFF2C2E33);
const _kCalCellRadius = 10.0;

/// Who opened the calendar — employees must not call manager leave APIs.
enum HolidaysCalendarMode { employee, manager }

class HolidaysCalendarScreen extends StatefulWidget {
  const HolidaysCalendarScreen({
    super.key,
    this.mode = HolidaysCalendarMode.employee,
  });

  final HolidaysCalendarMode mode;

  @override
  State<HolidaysCalendarScreen> createState() => _HolidaysCalendarScreenState();
}

class _HolidaysCalendarScreenState extends State<HolidaysCalendarScreen> {
  static final _monthTitleFormat = DateFormat('MMMM yyyy');

  final LeavesStore _store = bindings.leavesStore;
  late DateTime _calendarMonth;
  bool _calendarLoading = true;
  List<HolidayInfo> _monthHolidays = const [];
  List<_CalBirthday> _monthBirthdays = const [];
  List<ManagerTeamLeaveItem> _calendarLeaves = const [];
  final Map<int, List<HolidayInfo>> _holidaysByYear = {};
  final Map<int, Future<void>> _holidaysYearInFlight = {};
  final Set<int> _holidaysYearLoaded = {};
  final Map<String, _CalBirthday> _birthdaysByKey = {};
  final Map<int, List<ManagerTeamLeaveItem>> _leavesByYear = {};
  final Map<int, Future<void>> _leavesYearInFlight = {};
  final Set<int> _leavesYearLoaded = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month);
    _store.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Future.wait([
          _store.ensureLoaded(),
          _store.ensureHolidaysLoaded(),
        ]);
      } catch (_) {}
      if (!mounted) return;
      _seedDashboardLeaves();
      _seedHolidaysFromStore();
      await _ensureCalendarDataForMonth(_calendarMonth);
    });
  }

  /// Company calendar shows the whole team for managers (explicit mode or
  /// manager/owner/admin role), even when opened from the employee Leaves tab.
  bool get _isManager {
    if (widget.mode == HolidaysCalendarMode.manager) return true;
    if (!mounted) return false;
    try {
      return context.read<AuthProvider>().homeTarget == AuthHomeTarget.manager;
    } catch (_) {
      return false;
    }
  }

  void _seedDashboardLeaves() {
    if (_isManager) {
      try {
        final dash = context.read<ManagerOverviewProvider>().dashboard;
        if (dash != null) {
          final year = _calendarMonth.year;
          _mergeYearLeaves(year, [
            ...dash.pendingTeamLeaves.where((e) => !e.isRejectedLeave),
            ...dash.teamMonthLeaves.where((e) => !e.isRejectedLeave),
          ]);
        }
      } catch (_) {}
    }
    // Always include the signed-in user's own leave requests too.
    _seedEmployeeLeavesFromStore();
  }

  /// Employee calendar: own leave requests only (no manager team-leaves API).
  void _seedEmployeeLeavesFromStore() {
    final year = _calendarMonth.year;
    final selfName = () {
      try {
        final name = context.read<AuthProvider>().user?.name.trim() ?? '';
        return name.isEmpty ? 'You' : name;
      } catch (_) {
        return 'You';
      }
    }();
    final mapped = <ManagerTeamLeaveItem>[];
    for (final r in _store.requests) {
      if (r.status == LeaveRequestStatus.rejected) continue;
      final from = r.startDate;
      final to = r.endDate;
      if (from.year != year && to.year != year) {
        if (to.year < year || from.year > year) continue;
      }
      String ymd(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      mapped.add(
        ManagerTeamLeaveItem(
          id: int.tryParse(r.id),
          dateFrom: ymd(from),
          dateTo: ymd(to),
          status: r.status.name,
          statusLabel: r.status.name,
          leaveType: r.typeName,
          employeeName: selfName,
          sourceId: r.id,
        ),
      );
    }
    _mergeYearLeaves(year, mapped);
  }

  @override
  void dispose() {
    _store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    // Store finished loading holidays — merge and refresh the visible month.
    _seedHolidaysFromStore();
    setState(() {
      _monthHolidays = _holidaysForMonth(_calendarMonth);
      _monthBirthdays = _birthdaysForMonth(_calendarMonth);
      _calendarLeaves = _leavesForCalendar();
    });
  }

  void _seedHolidaysFromStore() {
    for (final h in _store.holidays) {
      final year = h.date.year;
      final days = h.days < 1 ? 1 : h.days;
      final list = <HolidayInfo>[
        for (var i = 0; i < days; i++)
          HolidayInfo(
            date: DateTime(h.date.year, h.date.month, h.date.day + i),
            name: h.name,
          ),
      ];
      _mergeYearHolidays(year, list);
    }
  }

  List<HolidayInfo> _holidaysForMonth(DateTime month) {
    final yearHolidays = _holidaysByYear[month.year];
    if (yearHolidays == null || yearHolidays.isEmpty) return const [];
    return yearHolidays
        .where((h) => h.date.year == month.year && h.date.month == month.month)
        .toList(growable: false);
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
      byKey.putIfAbsent(
        '${date.year}-${date.month}-${date.day}',
        () => HolidayInfo(date: date, name: holiday.name),
      );
    }
    final sorted = byKey.values.toList(growable: false)
      ..sort((a, b) => a.date.compareTo(b.date));
    _holidaysByYear[year] = sorted;
  }

  void _mergeBirthdays(Iterable<_CalBirthday> incoming) {
    for (final birthday in incoming) {
      final key =
          '${birthday.month}-${birthday.day}-${birthday.name.toLowerCase()}';
      _birthdaysByKey.putIfAbsent(key, () => birthday);
    }
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

  Future<void> _ensureYearHolidays(int year) async {
    if (_holidaysYearLoaded.contains(year)) return;
    final inflight = _holidaysYearInFlight[year];
    if (inflight != null) {
      await inflight;
      return;
    }

    final future = () async {
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

      _holidaysByYear.putIfAbsent(year, () => const <HolidayInfo>[]);
      _holidaysYearLoaded.add(year);
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

  Future<void> _ensureLeavesForYear(int year) async {
    if (_leavesYearLoaded.contains(year)) return;
    final inflight = _leavesYearInFlight[year];
    if (inflight != null) {
      await inflight;
      return;
    }

    final future = () async {
      if (!_isManager) {
        _seedEmployeeLeavesFromStore();
        _leavesByYear.putIfAbsent(year, () => const <ManagerTeamLeaveItem>[]);
        _leavesYearLoaded.add(year);
        return;
      }

      final dateFrom = '$year-01-01';
      final dateTo = '$year-12-31';

      Future<List<ManagerTeamLeaveItem>> pull(String status) async {
        try {
          final res = await bindings.managerOverviewService.loadTeamLeaves(
            status: status,
            dateFrom: dateFrom,
            dateTo: dateTo,
          );
          return res.success && res.data != null ? res.data! : const [];
        } catch (_) {
          return const [];
        }
      }

      final batches = await Future.wait([pull('pending'), pull('approved')]);
      _mergeYearLeaves(year, [...batches[0], ...batches[1]]);
      // Team leave APIs can omit the manager's own requests — merge them too.
      _seedEmployeeLeavesFromStore();
      _leavesByYear.putIfAbsent(year, () => const <ManagerTeamLeaveItem>[]);
      _leavesYearLoaded.add(year);
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

  Future<void> _ensureCalendarDataForMonth(DateTime month) async {
    if (mounted) setState(() => _calendarLoading = true);
    _seedDashboardLeaves();
    // Paint whatever we already have (dashboard / store) immediately.
    if (mounted) {
      setState(() {
        _monthHolidays = _holidaysForMonth(month);
        _monthBirthdays = _birthdaysForMonth(month);
        _calendarLeaves = _leavesForCalendar();
      });
    }

    final prev = DateTime(month.year, month.month - 1);
    final next = DateTime(month.year, month.month + 1);
    final years = <int>{prev.year, month.year, next.year};

    // Fast path: current month ±1 only (not a full-year crawl).
    Future<void> monthHolidays() async {
      try {
        final key =
            '${month.year.toString().padLeft(4, '0')}-'
            '${month.month.toString().padLeft(2, '0')}';
        final res = await bindings.attendanceService.getCompanyHolidays(
          month: key,
        );
        if (res.success && res.data != null) {
          _mergeYearHolidays(month.year, res.data!);
        }
      } catch (_) {}
    }

    await Future.wait([
      ...years.map(_ensureYearHolidays),
      _ensureLeavesForYear(month.year),
      _loadBirthdaysAroundMonth(month),
      monthHolidays(),
    ]);

    if (!mounted) return;
    setState(() {
      _monthHolidays = _holidaysForMonth(month);
      _monthBirthdays = _birthdaysForMonth(month);
      _calendarLeaves = _leavesForCalendar();
      _calendarLoading = false;
    });
  }

  Future<void> _fetchCalendarExtrasForMonth(String monthKey) async {
    // Merge every source — team calendar often has leaves/birthdays while
    // company calendar has public holidays; don't stop after the first hit.
    final paths = _isManager
        ? <String>[
            ManagerEmployeeApiEndpoints.teamCalendar,
            EmployeeApiEndpoints.companyCalendar,
          ]
        : <String>[EmployeeApiEndpoints.companyCalendar];
    final year =
        int.tryParse(monthKey.split('-').first) ?? DateTime.now().year;
    for (final path in paths) {
      try {
        final raw = await bindings.apiClient.get(
          path,
          queryParameters: {'month': monthKey},
        );
        if (raw.statusCode >= 400) continue;
        final parsed = _parseCompanyCalendarExtras(raw.data);
        if (parsed.holidays.isNotEmpty) {
          _mergeYearHolidays(year, parsed.holidays);
        }
        if (parsed.birthdays.isNotEmpty) {
          _mergeBirthdays(parsed.birthdays);
        }
        if (parsed.leaves.isNotEmpty) {
          _mergeYearLeaves(year, parsed.leaves);
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
          map['event_name'] ??
          map['employee'] ??
          map['user'];
      if (raw is Map) {
        return (raw['name'] ?? raw['full_name'] ?? raw['title'] ?? '')
            .toString()
            .trim();
      }
      // Never stringify a nested list into the chip label (e.g. "[{title:...").
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            final nested = nameOf(Map<String, dynamic>.from(item));
            if (nested.isNotEmpty) return nested;
          } else {
            final text = item?.toString().trim() ?? '';
            if (text.isNotEmpty &&
                !text.startsWith('[') &&
                !text.startsWith('{')) {
              return text;
            }
          }
        }
        return '';
      }
      final text = (raw ?? '').toString().trim();
      if (text.startsWith('[') || text.startsWith('{')) return '';
      return text;
    }

    bool keyLooksLikeBirthday(String key) {
      final k = key.toLowerCase();
      return k.contains('birthday') || k.contains('bday') || k == 'dob';
    }

    void addBirthday(DateTime date, String name) {
      final trimmed = name.trim();
      if (trimmed.startsWith('[') || trimmed.startsWith('{')) return;
      final display = trimmed.isEmpty ||
              trimmed.toLowerCase() == 'birthday' ||
              trimmed.toLowerCase() == 'bday'
          ? 'Birthday'
          : trimmed;
      final key = '${date.month}-${date.day}-${display.toLowerCase()}';
      if (!seenBirthday.add(key)) return;
      birthdays.add(
        _CalBirthday(month: date.month, day: date.day, name: display),
      );
    }

    void consume(dynamic node, {bool preferBirthday = false}) {
      if (node is List) {
        for (final item in node) {
          consume(item, preferBirthday: preferBirthday);
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
        'publicHolidays',
        'holiday_dates',
        'holidayDates',
        'birthdays',
        'birthday_dates',
        'birthdayDates',
        'leaves',
        'team_leaves',
        'approved_leaves',
        'pending_leaves',
        'data',
      ]) {
        if (map[key] == null) continue;
        consume(
          map[key],
          preferBirthday: preferBirthday || keyLooksLikeBirthday(key),
        );
      }

      // Date-keyed birthday maps: { "1990-10-15": "Ada", "10-15": {...} }
      if (preferBirthday) {
        map.forEach((k, v) {
          if (keyLooksLikeBirthday(k) ||
              const {
                'events',
                'items',
                'days',
                'entries',
                'data',
                'calendar',
              }.contains(k)) {
            return;
          }
          final keyDate = asDate(k);
          if (keyDate == null) return;
          if (v is Map) {
            final nested = Map<String, dynamic>.from(v);
            nested.putIfAbsent('date', () => k);
            consume(nested, preferBirthday: true);
          } else if (v is List) {
            for (final item in v) {
              if (item is Map) {
                final nested = Map<String, dynamic>.from(item);
                nested.putIfAbsent('date', () => k);
                consume(nested, preferBirthday: true);
              } else {
                addBirthday(keyDate, item?.toString() ?? '');
              }
            }
          } else {
            addBirthday(keyDate, v?.toString() ?? '');
          }
        });
      }

      final date = asDate(
        map['date'] ??
            map['holiday_date'] ??
            map['birthday_date'] ??
            map['birthdayDate'] ??
            map['date_of_birth'] ??
            map['dateOfBirth'] ??
            map['dob'] ??
            map['birth_date'] ??
            map['birthDate'] ??
            map['day'] ??
            map['start_date'] ??
            map['from_date'] ??
            map['date_from'],
      );
      DateTime? resolved = date;
      if (resolved == null) {
        final month = int.tryParse(
          '${map['month'] ?? map['birth_month'] ?? map['birthMonth'] ?? ''}',
        );
        final day = int.tryParse(
          '${map['day'] ?? map['birth_day'] ?? map['birthDay'] ?? ''}',
        );
        if (month != null &&
            day != null &&
            month >= 1 &&
            month <= 12 &&
            day >= 1 &&
            day <= 31) {
          resolved = DateTime(DateTime.now().year, month, day);
        }
      }

      final name = nameOf(map);
      final nameBlob = name.toLowerCase();
      final isBirthday =
          preferBirthday ||
          type.contains('birthday') ||
          type.contains('bday') ||
          map['is_birthday'] == true ||
          map['is_birthday'] == 1 ||
          map['is_birthday'] == '1' ||
          map['isBirthday'] == true ||
          map['isBirthday'] == 1 ||
          map['isBirthday'] == '1' ||
          nameBlob.contains('birthday') ||
          nameBlob.contains('bday');
      final isHoliday =
          type.contains('holiday') ||
          map['is_holiday'] == true ||
          map['isHoliday'] == true;
      final isLeave =
          type.contains('leave') ||
          map['leave_type'] != null ||
          map['leave_type_id'] != null ||
          map['date_from'] != null;

      if (isBirthday && resolved != null) {
        addBirthday(resolved, name);
        return;
      }

      if (isHoliday && resolved != null) {
        final key = '${resolved.year}-${resolved.month}-${resolved.day}';
        if (seenHoliday.add(key)) {
          holidays.add(
            HolidayInfo(
              date: DateTime(resolved.year, resolved.month, resolved.day),
              name: name.isEmpty ? 'Public Holiday' : name,
            ),
          );
        }
        return;
      }

      if (isLeave && !isBirthday) {
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

  Widget _companyCalendarCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
              CommonImageView(imagePath: Assets.imagesCalendarDay, height: 16),
              const SizedBox(width: 8),
              Expanded(
                child: AppText.p1(
                  'Company calendar',
                  weight: FontWeight.w600,
                  align: TextAlign.left,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ButtonAnimations.press(
                onTap: () => _shiftCalendarMonth(-1),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    CupertinoIcons.chevron_left,
                    size: 18,
                    color: kBlack200,
                  ),
                ),
              ),
              Expanded(
                child: AppText.p1(
                  _monthTitleFormat.format(_calendarMonth),
                  weight: FontWeight.w700,
                  align: TextAlign.center,
                ),
              ),
              ButtonAnimations.press(
                onTap: () => _shiftCalendarMonth(1),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: kBlack200,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _legendItem(_kCalWeekend, 'Sat / Sun'),
              _legendItem(_kCalHoliday, 'Public holiday'),
              _legendItem(_kCalBirthday, 'Birthday'),
              _legendItem(_kCalApprovedLeave, 'Approved leave'),
              _legendItem(_kCalPendingLeave, 'Pending leave'),
            ],
          ),
          const SizedBox(height: 12),
          if (_calendarLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: ShimmerProgress()),
            )
          else
            _CompanyCalendarGrid(
              key: ValueKey(
                '${_calendarMonth.year}-${_calendarMonth.month}-'
                '${_monthHolidays.length}-${_monthBirthdays.length}-'
                '${_calendarLeaves.length}',
              ),
              month: _calendarMonth,
              holidays: _monthHolidays,
              birthdays: _monthBirthdays,
              leaves: _calendarLeaves,
              shortName: _shortName,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final allowedYears = {currentYear, currentYear + 1};
    final holidays = _store.holidays
        .where((h) => allowedYears.contains(h.date.year))
        .toList();
    final grouped = <int, List<LeaveHoliday>>{};
    for (final holiday in holidays) {
      grouped.putIfAbsent(holiday.date.year, () => []).add(holiday);
    }
    final years = grouped.keys.toList()..sort();
    final isInitialLoad = !_store.holidaysLoaded && holidays.isEmpty;

    return Scaffold(
      backgroundColor: kbackground1,
      body: Padding(
        padding: AppSizes.page(context),
        child: Column(
          children: [
            const BackButtonBg(
              title: 'Holidays Calendar',
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ShimmerRefreshIndicator(
                instagramStyle: true,
                triggerFraction: 0.40,
                showOrb: false,
                onRefresh: () async {
                  await _store.refreshHolidays();
                  await _ensureCalendarDataForMonth(_calendarMonth);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _companyCalendarCard(),
                    const SizedBox(height: 20),
                    AppText.p1(
                      'Public holidays',
                      weight: FontWeight.w600,
                      align: TextAlign.left,
                    ),
                    const SizedBox(height: 12),
                    if (isInitialLoad)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: ShimmerProgress()),
                      )
                    else if (holidays.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: AppText.p2(
                            'No holidays found',
                            color: kGreyColor,
                          ),
                        ),
                      )
                    else
                      for (final year in years) ...[
                        if (year != years.first) ...[
                          const SizedBox(height: 20),
                          AppText.h5(
                            '$year',
                            weight: FontWeight.w600,
                            align: TextAlign.left,
                          ),
                          const SizedBox(height: 12),
                        ],
                        for (final holiday in grouped[year]!) ...[
                          _HolidayCard(holiday: holiday),
                          const SizedBox(height: 10),
                        ],
                      ],
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
}

class _HolidayCard extends StatelessWidget {
  const _HolidayCard({required this.holiday});

  final LeaveHoliday holiday;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.p2(
            LeaveFormat.weekdayFull(holiday.date),
            color: kGreyColor,
            weight: FontWeight.w400,
            align: TextAlign.left,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AppText.p2(
                  holiday.name,
                  weight: FontWeight.w500,
                  align: TextAlign.left,
                ),
              ),
              const SizedBox(width: 12),
              AppText.p2(
                LeaveFormat.daysLabel(holiday.days),
                color: kGreyColor,
                weight: FontWeight.w400,
              ),
            ],
          ),
        ],
      ),
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

enum _CalEventKind { holiday, birthday, approvedLeave, pendingLeave }

class _CalDayEvent {
  const _CalDayEvent({required this.label, required this.kind});

  final String label;
  final _CalEventKind kind;
}

class _CompanyCalendarGrid extends StatefulWidget {
  const _CompanyCalendarGrid({
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
  State<_CompanyCalendarGrid> createState() => _CompanyCalendarGridState();
}

class _CompanyCalendarGridState extends State<_CompanyCalendarGrid> {
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
          label: name.isEmpty ? 'Birthday' : widget.shortName(name),
          kind: _CalEventKind.birthday,
        ),
      );
    }
    for (final leave in widget.leaves) {
      if (!leave.coversDay(day) || leave.isRejectedLeave) continue;
      final name = (leave.employeeName ?? 'Employee').trim();
      events.add(
        _CalDayEvent(
          label: widget.shortName(name),
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
                      color: _kCalBubbleBg,
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
    final leading = first.weekday - 1;
    final weekCount = ((leading + daysInMonth + 6) ~/ 7);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - (_cellGap * 6)) / 7;

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
              Builder(
                builder: (_) {
                  // Grow this week’s cells to fit every stacked event pill.
                  var rowMax = 1;
                  for (var col = 0; col < 7; col++) {
                    final dayNum = row * 7 + col - leading + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) continue;
                    final count = _eventsFor(
                      DateTime(widget.month.year, widget.month.month, dayNum),
                    ).length;
                    if (count > rowMax) rowMax = count;
                  }
                  final cellHeight = math.max(
                    cellWidth * 0.92,
                    20.0 + (rowMax * 15.0),
                  );
                  return Row(
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
                  );
                },
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
          borderRadius: BorderRadius.circular(_kCalCellRadius),
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
      fill = hasPendingOnly ? _kCalPendingFill : _kCalLeaveFill;
      border = hasPendingOnly ? _kCalPendingLeave : _kCalLeaveBorder;
    } else if (hasHoliday) {
      fill = _kCalHolidayFill;
      border = _kCalHoliday;
    } else if (hasBirthday) {
      fill = _kCalBirthdayFill;
      border = _kCalBirthday;
    } else if (isWeekend) {
      fill = _kCalWeekendBg;
      border = _kCalWeekend;
    } else {
      fill = kWhite;
      border = kBorderColor;
    }

    Color chipText(_CalEventKind kind) => switch (kind) {
      _CalEventKind.holiday => _kCalHoliday,
      _CalEventKind.birthday => const Color(0xFFAD1457),
      _CalEventKind.pendingLeave => const Color(0xFF8A6A00),
      _ => _kCalLeaveText,
    };

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.none,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kCalCellRadius),
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
            borderRadius: BorderRadius.circular(_kCalCellRadius),
            border: Border.all(
              color: isToday ? _kCalTodayBorder : border,
              width: isToday ? 1.8 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dayNum',
                  style: TextStyle(
                    fontFamily: AppFonts.Poppins,
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                    color: hasLeave ? _kCalLeaveText : kBlack200,
                  ),
                ),
                if (events.isNotEmpty) const SizedBox(height: 2),
                // Stack every holiday / birthday / leave in this cell.
                for (var i = 0; i < events.length; i++) ...[
                  if (i > 0) const SizedBox(height: 2),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: kWhite.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      events[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.Poppins,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: chipText(events[i].kind),
                        height: 1.05,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
