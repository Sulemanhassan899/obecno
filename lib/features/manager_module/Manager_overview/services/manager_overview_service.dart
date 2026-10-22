import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/services/manager_attendance_service.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/repositories/manager_employees_repository.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/features/manager_module/Manager_overview/domain/overview_summary.dart';
import 'package:obecno/features/manager_module/Manager_overview/repositories/manager_overview_repository.dart';

class ManagerOverviewService {
  ManagerOverviewService(
    this._repository, {
    ManagerEmployeesRepository? employeesRepository,
    ManagerAttendanceService? attendanceService,
  }) : _employeesRepository = employeesRepository,
       _attendanceService = attendanceService;

  final ManagerOverviewRepository _repository;
  final ManagerEmployeesRepository? _employeesRepository;
  final ManagerAttendanceService? _attendanceService;

  Future<ApiResponse<List<ManagerTeamLeaveItem>>> loadTeamLeaves({
    String? status,
    String? locationId,
    String? departmentId,
    String? leaveType,
    String? dateFrom,
    String? dateTo,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getTeamLeaves(
      status: status,
      locationId: locationId,
      departmentId: departmentId,
      leaveType: leaveType,
      dateFrom: dateFrom,
      dateTo: dateTo,
      cancelToken: cancelToken,
    );
  }

  /// Pending leave approval inbox for Alerts + Team Leaves.
  ///
  /// Contract (stable order, no status spray):
  /// 1. Bare `GET team-leaves` — many backends use this as the pending inbox.
  /// 2. `?status=pending` once — if bare was empty / non-pending.
  /// 3. Dashboard pending list already in memory.
  /// Status synonyms (requested / awaiting / …) are normalized in
  /// [ManagerTeamLeaveItem], not by extra network calls.
  Future<ApiResponse<List<ManagerTeamLeaveItem>>> loadPendingTeamLeaves({
    String? locationId,
    String? dateFrom,
    String? dateTo,
    List<ManagerTeamLeaveItem> dashboardPending = const [],
    ApiCancelToken? cancelToken,
  }) async {
    Future<List<ManagerTeamLeaveItem>> fetch(String? status) async {
      final res = await _repository.getTeamLeaves(
        status: status,
        locationId: locationId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        cancelToken: cancelToken,
      );
      return res.success && res.data != null ? res.data! : const [];
    }

    List<ManagerTeamLeaveItem> pendingFrom(
      List<ManagerTeamLeaveItem> raw, {
      required bool inboxQuery,
    }) {
      final explicit = raw.where((e) => e.isPendingLeave).toList(growable: false);
      if (explicit.isNotEmpty) return explicit;
      if (!inboxQuery) return const [];
      // Default inbox: keep undecided rows (blank / non-approved).
      return raw.where((e) => e.isPendingInInbox).toList(growable: false);
    }

    final inbox = pendingFrom(await fetch(null), inboxQuery: true);
    if (inbox.isNotEmpty) {
      return ApiResponse.success(inbox);
    }

    final pending = pendingFrom(await fetch('pending'), inboxQuery: true);
    if (pending.isNotEmpty) {
      return ApiResponse.success(pending);
    }

    final fromDash = dashboardPending
        .where((e) => e.isPendingInInbox)
        .toList(growable: false);
    return ApiResponse.success(fromDash);
  }

  Future<ApiResponse<String>> reviewTeamLeave({
    required int leaveId,
    required String action,
    String? reason,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.reviewTeamLeave(
      leaveId: leaveId,
      action: action,
      reason: reason,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<OverviewSnapshot>> loadOverview({
    required DateTime date,
    ApiCancelToken? cancelToken,
    void Function(OverviewSnapshot snapshot)? onPreliminary,
  }) async {
    final dashboardFuture = _repository.getDashboard(cancelToken: cancelToken);
    final membersFuture = _loadMembers(cancelToken);

    final dashboardResponse = await dashboardFuture;
    final members = await membersFuture;

    if (!dashboardResponse.success || dashboardResponse.data == null) {
      return ApiResponse.failure(
        dashboardResponse.message ?? 'Failed to load overview.',
        statusCode: dashboardResponse.statusCode,
      );
    }

    final dashboard = dashboardResponse.data!;
    final selected = DateTime(date.year, date.month, date.day);
    final today = dashboard.today ?? DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final dayKey = _yyyyMMdd(selected);
    final leavesFuture = _loadLeavesCoveringDay(
      selected,
      cancelToken: cancelToken,
    );

    if (selected == todayOnly) {
      final merged = TeamAttendanceMapper.mergeWithMembers(
        attendance: dashboard.teamAttendanceToday,
        members: members,
      );
      _publishPreliminary(
        onPreliminary,
        date: selected,
        dashboard: dashboard,
        attendance: merged,
        members: members,
      );
      if (cancelToken?.isCancelled == true) {
        return ApiResponse.failure('Cancelled');
      }
      final dayLeaves = await leavesFuture;
      final attendance = await _withOwner(
        merged,
        members: members,
        date: selected,
      );
      return ApiResponse.success(
        _snapshot(
          date: selected,
          dashboard: dashboard,
          attendance: attendance,
          members: members,
          dayLeaves: dayLeaves,
        ),
        message: dashboardResponse.message,
        statusCode: dashboardResponse.statusCode,
      );
    }

    final attendanceResponse = await _repository.getTeamAttendance(
      date: dayKey,
      cancelToken: cancelToken,
    );

    if (!attendanceResponse.success || attendanceResponse.data == null) {
      return ApiResponse.failure(
        attendanceResponse.message ?? 'Failed to load team attendance.',
        statusCode: attendanceResponse.statusCode,
      );
    }

    final merged = TeamAttendanceMapper.mergeWithMembers(
      attendance: attendanceResponse.data!.attendance,
      members: members,
    );
    _publishPreliminary(
      onPreliminary,
      date: selected,
      dashboard: dashboard,
      attendance: merged,
      members: members,
    );
    if (cancelToken?.isCancelled == true) {
      return ApiResponse.failure('Cancelled');
    }
    final dayLeaves = await leavesFuture;
    final attendance = await _withOwner(
      merged,
      members: members,
      date: selected,
    );
    return ApiResponse.success(
      _snapshot(
        date: selected,
        dashboard: dashboard,
        attendance: attendance,
        members: members,
        dayLeaves: dayLeaves,
      ),
      message: attendanceResponse.message,
      statusCode: attendanceResponse.statusCode,
    );
  }

  /// Approved team-leaves covering [day].
  ///
  /// Team-leaves defaults to the pending review inbox on many backends, so we
  /// always ask for `approved` when computing On Leave.
  Future<List<ManagerTeamLeaveItem>> _loadLeavesCoveringDay(
    DateTime day, {
    ApiCancelToken? cancelToken,
  }) async {
    final dayKey = _yyyyMMdd(day);
    final monthStart = DateTime(day.year, day.month, 1);
    final monthEnd = DateTime(day.year, day.month + 1, 0);

    List<ManagerTeamLeaveItem> filterCovering(
      List<ManagerTeamLeaveItem> raw, {
      required bool allowMissingDates,
      required bool assumeApprovedQuery,
    }) {
      return [
        for (final leave in raw)
          if (leave.countsAsOnLeaveOrBlank(
            assumeApprovedQuery: assumeApprovedQuery,
          ))
            if (leave.coversDay(day) ||
                (allowMissingDates &&
                    (leave.dateFrom == null ||
                        leave.dateFrom!.trim().isEmpty)))
              leave,
      ];
    }

    Future<List<ManagerTeamLeaveItem>> fetch({
      String? status,
      String? dateFrom,
      String? dateTo,
      String? date,
      bool allowMissingDates = false,
    }) async {
      final assumeApproved = status == 'approved';
      final res = await _repository.getTeamLeaves(
        status: status,
        dateFrom: dateFrom,
        dateTo: dateTo,
        date: date,
        cancelToken: cancelToken,
      );
      return filterCovering(
        res.data ?? const [],
        allowMissingDates: allowMissingDates,
        assumeApprovedQuery: assumeApproved,
      );
    }

    try {
      // Prefer approved + day scope (single `date` and from/to variants).
      for (final attempt in <Future<List<ManagerTeamLeaveItem>> Function()>[
        () => fetch(
              status: 'approved',
              dateFrom: dayKey,
              dateTo: dayKey,
              allowMissingDates: true,
            ),
        () => fetch(status: 'approved', date: dayKey, allowMissingDates: true),
        () => fetch(
              status: 'approved',
              dateFrom: _yyyyMMdd(monthStart),
              dateTo: _yyyyMMdd(monthEnd),
            ),
        // No status — keep only explicitly approved rows.
        () => fetch(
              dateFrom: dayKey,
              dateTo: dayKey,
              allowMissingDates: true,
            ),
        () => fetch(
              dateFrom: _yyyyMMdd(monthStart),
              dateTo: _yyyyMMdd(monthEnd),
            ),
        () => fetch(status: 'approved'),
        () => fetch(),
      ]) {
        final leaves = await attempt();
        if (leaves.isNotEmpty) return leaves;
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  void _publishPreliminary(
    void Function(OverviewSnapshot snapshot)? onPreliminary, {
    required DateTime date,
    required ManagerDashboardModel dashboard,
    required List<ManagerTeamAttendanceItem> attendance,
    required List<ManagerEmployeeModel> members,
  }) {
    onPreliminary?.call(
      _snapshot(
        date: date,
        dashboard: dashboard,
        attendance: attendance,
        members: members,
      ),
    );
  }

  OverviewSnapshot _snapshot({
    required DateTime date,
    required ManagerDashboardModel dashboard,
    required List<ManagerTeamAttendanceItem> attendance,
    required List<ManagerEmployeeModel> members,
    List<ManagerTeamLeaveItem> dayLeaves = const [],
  }) {
    final stamped = _stampLeavesForDate(
      attendance: attendance,
      dashboard: dashboard,
      date: date,
      members: members,
      dayLeaves: dayLeaves,
    );
    return OverviewSnapshot(
      date: date,
      dashboard: dashboard,
      attendance: stamped,
      summary: OverviewSummary.fromAttendance(
        attendance: stamped,
        teamMemberCount: _teamCount(
          dashboardCount: dashboard.teamMemberCount,
          members: members,
          attendanceCount: stamped.length,
        ),
      ),
    );
  }

  /// Marks / inserts leave rows so overview On Leave count matches reality.
  List<ManagerTeamAttendanceItem> _stampLeavesForDate({
    required List<ManagerTeamAttendanceItem> attendance,
    required ManagerDashboardModel dashboard,
    required DateTime date,
    required List<ManagerEmployeeModel> members,
    List<ManagerTeamLeaveItem> dayLeaves = const [],
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final leaveByUser = <int, ManagerTeamLeaveItem>{};
    final nameToUserId = <String, int>{};
    for (final item in attendance) {
      final id = item.userId;
      final name = item.employeeName?.trim().toLowerCase();
      if (id != null && name != null && name.isNotEmpty) {
        nameToUserId.putIfAbsent(name, () => id);
      }
    }
    for (final member in members) {
      final id = member.userId;
      final name = member.name.trim().toLowerCase();
      if (id != null && name.isNotEmpty) {
        nameToUserId.putIfAbsent(name, () => id);
      }
    }

    void consider(ManagerTeamLeaveItem leave, {required bool requireOverlap}) {
      if (!leave.countsAsOnLeaveOrBlank(assumeApprovedQuery: !requireOverlap)) {
        return;
      }
      if (requireOverlap && !leave.coversDay(day)) return;
      // Day-scoped payloads sometimes omit dates — still count them.
      if (!requireOverlap &&
          leave.dateFrom != null &&
          leave.dateFrom!.trim().isNotEmpty &&
          !leave.coversDay(day)) {
        return;
      }
      final userId = leave.userId ??
          nameToUserId[leave.employeeName?.trim().toLowerCase() ?? ''];
      if (userId == null) return;
      leaveByUser.putIfAbsent(userId, () => leave);
    }

    for (final leave in dayLeaves) {
      consider(leave, requireOverlap: false);
    }
    // Month leaves may include approved ranges; skip pending inbox.
    for (final leave in dashboard.teamMonthLeaves) {
      consider(leave, requireOverlap: true);
    }

    if (leaveByUser.isEmpty) return attendance;

    final result = <ManagerTeamAttendanceItem>[];
    final seen = <int>{};
    for (final item in attendance) {
      final userId = item.userId;
      if (userId != null && leaveByUser.containsKey(userId)) {
        seen.add(userId);
        result.add(
          item.isOnLeave
              ? item
              : item.copyWith(status: 'leave', statusLabel: 'On Leave'),
        );
      } else {
        result.add(item);
      }
    }

    // Employees on leave but missing from team-attendance still count / filter.
    for (final entry in leaveByUser.entries) {
      if (seen.contains(entry.key)) continue;
      final leave = entry.value;
      result.add(
        ManagerTeamAttendanceItem(
          userId: entry.key,
          employeeName: leave.employeeName ?? 'Employee',
          status: 'leave',
          statusLabel: leave.leaveType ?? 'On Leave',
        ),
      );
    }
    return result;
  }

  Future<List<ManagerTeamAttendanceItem>> _withOwner(
    List<ManagerTeamAttendanceItem> items, {
    required List<ManagerEmployeeModel> members,
    required DateTime date,
  }) async {
    final service = _attendanceService;
    if (service == null) return items;
    return service.withOwnerAttendance(
      items: items,
      members: members,
      date: date,
    );
  }

  /// Prefer the employees directory count — dashboard `team_member_count` can
  /// under-count (e.g. exclude the signed-in owner).
  int _teamCount({
    required int dashboardCount,
    required List<ManagerEmployeeModel> members,
    required int attendanceCount,
  }) {
    final activeMembers = members
        .where((m) => m.status != ManagerEmployeeStatus.deleted)
        .length;
    var total = dashboardCount;
    if (activeMembers > total) total = activeMembers;
    if (attendanceCount > total) total = attendanceCount;
    return total;
  }

  Future<List<ManagerEmployeeModel>> _loadMembers(
    ApiCancelToken? cancelToken,
  ) async {
    final repo = _employeesRepository;
    if (repo == null) return const [];
    try {
      final employees = await repo.getEmployees(
        pageSize: 200,
        cancelToken: cancelToken,
      );
      final team = await repo.getTeamMembers(
        pageSize: 200,
        cancelToken: cancelToken,
      );

      final byId = <String, ManagerEmployeeModel>{};
      void addAll(List<ManagerEmployeeModel> list) {
        for (final member in list) {
          final id = member.id.trim();
          if (id.isEmpty) continue;
          byId.putIfAbsent(id, () => member);
        }
      }

      if (employees.success && employees.data != null) {
        addAll(employees.data!.members);
      }
      if (team.success && team.data != null) {
        addAll(team.data!.members);
      }
      return byId.values.toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String _yyyyMMdd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
