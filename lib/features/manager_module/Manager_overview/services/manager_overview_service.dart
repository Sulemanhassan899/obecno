import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/repositories/manager_employees_repository.dart';
import 'package:obecno/features/manager_module/Manager_overview/domain/overview_summary.dart';
import 'package:obecno/features/manager_module/Manager_overview/repositories/manager_overview_repository.dart';

class ManagerOverviewService {
  ManagerOverviewService(
    this._repository, {
    ManagerEmployeesRepository? employeesRepository,
  }) : _employeesRepository = employeesRepository;

  final ManagerOverviewRepository _repository;
  final ManagerEmployeesRepository? _employeesRepository;

  Future<ApiResponse<OverviewSnapshot>> loadOverview({
    required DateTime date,
    ApiCancelToken? cancelToken,
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
      final attendance = TeamAttendanceMapper.mergeWithMembers(
        attendance: dashboard.teamAttendanceToday,
        members: members,
      );
      return ApiResponse.success(
        OverviewSnapshot(
          date: selected,
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

    final attendance = TeamAttendanceMapper.mergeWithMembers(
      attendance: attendanceResponse.data!.attendance,
      members: members,
    );
    return ApiResponse.success(
      OverviewSnapshot(
        date: selected,
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
      ),
      message: attendanceResponse.message,
      statusCode: attendanceResponse.statusCode,
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
      var response = await repo.getEmployees(cancelToken: cancelToken);
      if (!response.success || response.data == null) {
        response = await repo.getTeamMembers(cancelToken: cancelToken);
      }
      if (!response.success || response.data == null) return const [];
      return response.data!.members;
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
