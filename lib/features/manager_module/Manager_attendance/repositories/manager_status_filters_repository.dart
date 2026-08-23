import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_status_filter_model.dart';

class ManagerStatusFiltersRepository extends BaseRepository {
  ManagerStatusFiltersRepository(super.apiClient);

  Future<ApiResponse<List<ManagerStatusFilter>>> getFilters({
    ApiCancelToken? cancelToken,
  }) {
    return getRequest<List<ManagerStatusFilter>>(
      ManagerEmployeeApiEndpoints.teamAttendanceFilters,
      cancelToken: cancelToken,
      parser: (json) {
        final data = _extractData(
          json,
          fallbackKeys: const ['filters', 'statuses'],
        );
        final raw = data['filters'] ?? data['statuses'];
        return ManagerStatusFilter.listFrom(raw);
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
              (map['message'] as String?) ?? 'Failed to load status filters.',
        );
      }

      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      if (inner is List) return {'filters': inner};

      if (fallbackKeys.any(map.containsKey)) return map;
    }

    if (json is List) return {'filters': json};

    throw const FormatException('Unexpected status filters response shape.');
  }
}
