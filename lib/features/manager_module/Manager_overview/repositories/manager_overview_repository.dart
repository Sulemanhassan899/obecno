import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';

class ManagerOverviewRepository extends BaseRepository {
  ManagerOverviewRepository(super.apiClient);

  Future<ApiResponse<ManagerDashboardModel>> getDashboard({
    ApiCancelToken? cancelToken,
  }) {
    return getRequest<ManagerDashboardModel>(
      ManagerEmployeeApiEndpoints.dashboard,
      cancelToken: cancelToken,
      parser: (json) {
        final data = _extractData(
          json,
          fallbackKeys: const [
            'today',
            'company',
            'team_member_count',
            'team_attendance_today',
          ],
        );
        return ManagerDashboardModel.fromJson(data);
      },
    );
  }

  Future<ApiResponse<ManagerTeamAttendanceData>> getTeamAttendance({
    String? date,
    int? departmentId,
    String? filter,
    String? search,
    ApiCancelToken? cancelToken,
  }) {
    final query = <String, dynamic>{
      if (date != null && date.isNotEmpty) 'date': date,
      if (departmentId != null) 'department_id': departmentId,
      if (filter != null && filter.isNotEmpty) 'filter': filter,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    return getRequest<ManagerTeamAttendanceData>(
      ManagerEmployeeApiEndpoints.teamAttendance,
      queryParameters: query.isEmpty ? null : query,
      cancelToken: cancelToken,
      parser: (json) {
        final data = _extractData(
          json,
          fallbackKeys: const ['date', 'attendance', 'total'],
        );
        return ManagerTeamAttendanceData.fromJson(data);
      },
    );
  }

  Map<String, dynamic> _extractData(
    dynamic json, {
    required List<String> fallbackKeys,
  }) {
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);

      if (map['success'] == false) {
        throw ApiError(
          type: ApiErrorType.server,
          message:
              (map['message'] as String?) ??
              'Failed to load manager overview data.',
        );
      }

      final inner = map['data'];
      if (inner is Map) {
        return Map<String, dynamic>.from(inner);
      }

      if (fallbackKeys.any(map.containsKey)) {
        return map;
      }
    }

    throw const FormatException('Unexpected manager overview response shape.');
  }
}
