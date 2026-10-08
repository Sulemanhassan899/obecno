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
        ),
        message: dashboardResponse.message,
        statusCode: dashboardResponse.statusCode,
      );
    }

    final attendanceResponse = await _repository.getTeamAttendance(
      date: _yyyyMMdd(selected),
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
      ),
      message: attendanceResponse.message,
      statusCode: attendanceResponse.statusCode,
    );
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
  }) {
    return OverviewSnapshot(
      date: date,
      dashboard: dashboard,
      attendance: attendance,
      summary: OverviewSummary.fromAttendance(
        attendance: attendance,
        teamMemberCount: _teamCount(
          dashboardCount: dashboard.teamMemberCount,
          members: members,
          attendanceCount: attendance.length,
        ),
      ),
    );
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
