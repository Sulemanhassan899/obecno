import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/features/manager_module/Manager_overview/services/manager_overview_service.dart';

/// Loads team leave lists for [TeamLeavesScreen] outside the giant UI file.
class TeamLeavesLoader {
  TeamLeavesLoader(this._overview);

  final ManagerOverviewService _overview;

  Future<List<ManagerTeamLeaveItem>> loadByStatus({
    required String status,
    String? locationId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final res = await _overview.loadTeamLeaves(
      status: status,
      locationId: locationId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    if (res.success && res.data != null) return res.data!;
    return const [];
  }

  Future<ApiResponse<List<ManagerTeamLeaveItem>>> loadPending({
    String? locationId,
    List<ManagerTeamLeaveItem> dashboardPending = const [],
  }) {
    return _overview.loadPendingTeamLeaves(
      locationId: locationId,
      dashboardPending: dashboardPending,
    );
  }

  Future<ApiResponse<String>> review({
    required int leaveId,
    required String action,
    String? reason,
  }) {
    return _overview.reviewTeamLeave(
      leaveId: leaveId,
      action: action,
      reason: reason,
    );
  }
}
