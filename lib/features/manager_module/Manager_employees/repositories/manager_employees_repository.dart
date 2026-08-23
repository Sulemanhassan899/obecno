import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';

class ManagerEmployeesRepository extends BaseRepository {
  ManagerEmployeesRepository(super.apiClient);

  Future<ApiResponse<ManagerTeamMembersData>> getTeamMembers({
    String? search,
    String? locationId,
    String? departmentId,
    ApiCancelToken? cancelToken,
  }) {
    final query = <String, dynamic>{
      if (search != null && search.isNotEmpty) 'search': search,
      if (locationId != null && locationId.isNotEmpty && locationId != 'all')
        'location_id': locationId,
      if (departmentId != null && departmentId.isNotEmpty)
        'department_id': departmentId,
    };

    return getRequest<ManagerTeamMembersData>(
      ManagerEmployeeApiEndpoints.teamMembers,
      queryParameters: query.isEmpty ? null : query,
      cancelToken: cancelToken,
      parser: (json) {
        final data = _extractData(
          json,
          fallbackKeys: const ['members', 'employees', 'total'],
        );
        if (data['members'] == null &&
            data['employees'] == null &&
            json is Map &&
            json['data'] is List) {
          return ManagerTeamMembersData.fromJson({
            'members': json['data'],
            'total': (json['data'] as List).length,
          });
        }
        return ManagerTeamMembersData.fromJson(data);
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
              (map['message'] as String?) ?? 'Failed to load team members.',
        );
      }

      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      if (inner is List) return {'members': inner, 'total': inner.length};

      if (fallbackKeys.any(map.containsKey)) return map;
    }

    if (json is List) return {'members': json, 'total': json.length};

    throw const FormatException('Unexpected team members response shape.');
  }
}
