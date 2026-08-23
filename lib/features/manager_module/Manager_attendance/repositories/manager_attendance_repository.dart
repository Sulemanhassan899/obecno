import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';

class ManagerAttendanceRepository extends BaseRepository {
  ManagerAttendanceRepository(super.apiClient);

  Future<ApiResponse<ManagerTeamAttendanceData>> getTeamAttendance({
    String? date,
    String? filter,
    String? search,
    String? locationId,
    ApiCancelToken? cancelToken,
  }) {
    final query = <String, dynamic>{
      if (date != null && date.isNotEmpty) 'date': date,
      if (filter != null && filter.isNotEmpty && filter != 'all')
        'filter': filter,
      if (search != null && search.isNotEmpty) 'search': search,
      if (locationId != null && locationId.isNotEmpty && locationId != 'all')
        'location_id': locationId,
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
        if (data['attendance'] == null && json is Map && json['data'] is List) {
          return ManagerTeamAttendanceData.fromJson({
            'attendance': json['data'],
            'total': (json['data'] as List).length,
          });
        }
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
              (map['message'] as String?) ?? 'Failed to load team attendance.',
        );
      }

      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      if (inner is List) {
        return {'attendance': inner, 'total': inner.length};
      }

      if (fallbackKeys.any(map.containsKey)) return map;
    }

    if (json is List) return {'attendance': json, 'total': json.length};

    throw const FormatException('Unexpected team attendance response shape.');
  }
}
