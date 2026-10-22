import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/core/api/constants.dart';
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

  Future<ApiResponse<List<ManagerTeamLeaveItem>>> getTeamLeaves({
    String? status,
    String? locationId,
    String? departmentId,
    String? leaveType,
    String? dateFrom,
    String? dateTo,
    String? date,
    ApiCancelToken? cancelToken,
  }) async {
    final query = <String, dynamic>{
      if (status != null && status.isNotEmpty) 'status': status,
      if (locationId != null && locationId.isNotEmpty && locationId != 'all')
        'location_id': locationId,
      if (departmentId != null && departmentId.isNotEmpty)
        'department_id': departmentId,
      if (leaveType != null && leaveType.isNotEmpty) 'leave_type': leaveType,
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      // Some backends filter On Leave with a single `date` query.
      if (date != null && date.isNotEmpty) 'date': date,
    };

    final primary = await getRequest<List<ManagerTeamLeaveItem>>(
      ManagerEmployeeApiEndpoints.teamLeaves,
      queryParameters: query.isEmpty ? null : query,
      cancelToken: cancelToken,
      parser: _parseTeamLeaves,
    );
    if (primary.success && (primary.data?.isNotEmpty ?? false)) {
      return primary;
    }

    // Optional legacy path — off by default (see AppConstants.useLegacyLeavePaths).
    if (!AppConstants.useLegacyLeavePaths) {
      return primary;
    }

    final fallback = await getRequest<List<ManagerTeamLeaveItem>>(
      ManagerEmployeeApiEndpoints.leaves,
      queryParameters: query.isEmpty ? null : query,
      cancelToken: cancelToken,
      parser: _parseTeamLeaves,
    );
    if (fallback.success && (fallback.data?.isNotEmpty ?? false)) {
      return fallback;
    }
    return primary.success ? primary : fallback;
  }

  List<ManagerTeamLeaveItem> _parseTeamLeaves(dynamic json) {
    if (json is List) {
      return ManagerTeamLeaveItem.listFrom(json);
    }
    if (json is! Map) return const [];

    final map = Map<String, dynamic>.from(json);
    if (map['success'] == false) {
      throw ApiError(
        type: ApiErrorType.server,
        message:
            (map['message'] as String?) ?? 'Failed to load team leaves.',
      );
    }

    final data = map['data'];
    // Common shapes: { data: [ ... ] } or { data: { leaves: [...] } }
    if (data is List) {
      return ManagerTeamLeaveItem.listFrom(data);
    }
    if (data is Map) {
      final inner = Map<String, dynamic>.from(data);
      return ManagerTeamLeaveItem.listFrom(
        inner['leaves'] ??
            inner['team_leaves'] ??
            inner['approved_leaves'] ??
            inner['pending_team_leaves'] ??
            inner['team_month_leaves'] ??
            inner['requests'] ??
            inner['history'] ??
            inner['items'] ??
            inner['records'] ??
            inner['data'],
      );
    }

    return ManagerTeamLeaveItem.listFrom(
      map['leaves'] ??
          map['team_leaves'] ??
          map['approved_leaves'] ??
          map['pending_team_leaves'] ??
          map['team_month_leaves'] ??
          map['requests'] ??
          map['history'] ??
          map['items'] ??
          map['records'],
    );
  }

  Future<ApiResponse<String>> reviewTeamLeave({
    required int leaveId,
    required String action,
    String? reason,
    ApiCancelToken? cancelToken,
  }) async {
    String parse(dynamic json) {
      if (json is Map) {
        final map = Map<String, dynamic>.from(json);
        return (map['message'] ?? map['data'] ?? 'OK').toString();
      }
      return 'OK';
    }

    final body = {
      'leave_id': leaveId,
      'action': action,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };

    final primary = await postRequest<String>(
      ManagerEmployeeApiEndpoints.teamLeavesReview,
      data: body,
      cancelToken: cancelToken,
      parser: parse,
    );
    if (primary.success || !AppConstants.useLegacyLeavePaths) return primary;

    return postRequest<String>(
      ManagerEmployeeApiEndpoints.leaveReview(leaveId),
      data: {
        'action': action,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
      cancelToken: cancelToken,
      parser: parse,
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
