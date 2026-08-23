import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/manager_module/Manager_overview/domain/overview_summary.dart';
import 'package:obecno/features/manager_module/Manager_overview/repositories/manager_overview_repository.dart';

class ManagerOverviewService {
  ManagerOverviewService(this._repository);

  final ManagerOverviewRepository _repository;

  Future<ApiResponse<OverviewSnapshot>> loadOverview({
    required DateTime date,
    ApiCancelToken? cancelToken,
  }) async {
    final dashboardResponse = await _repository.getDashboard(
      cancelToken: cancelToken,
    );

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
      return ApiResponse.success(
        OverviewSnapshot(
          date: selected,
          dashboard: dashboard,
          attendance: dashboard.teamAttendanceToday,
          summary: OverviewSummary.fromAttendance(
            attendance: dashboard.teamAttendanceToday,
            teamMemberCount: dashboard.teamMemberCount,
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

    final attendance = attendanceResponse.data!.attendance;
    return ApiResponse.success(
      OverviewSnapshot(
        date: selected,
        dashboard: dashboard,
        attendance: attendance,
        summary: OverviewSummary.fromAttendance(
          attendance: attendance,
          teamMemberCount: dashboard.teamMemberCount,
        ),
      ),
      message: attendanceResponse.message,
      statusCode: attendanceResponse.statusCode,
    );
  }

  String _yyyyMMdd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
