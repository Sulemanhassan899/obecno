import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';

class ManagerLocationsRepository extends BaseRepository {
  ManagerLocationsRepository(super.apiClient);

  Future<ApiResponse<List<ManagerLocationModel>>> getLocations({
    String? date,
    ApiCancelToken? cancelToken,
  }) {
    final query = <String, dynamic>{
      if (date != null && date.isNotEmpty) 'date': date,
    };

    return getRequest<List<ManagerLocationModel>>(
      ManagerEmployeeApiEndpoints.locations,
      queryParameters: query.isEmpty ? null : query,
      cancelToken: cancelToken,
      parser: (json) {
        final data = _extractData(
          json,
          fallbackKeys: const ['locations', 'offices'],
        );
        final raw = data['locations'] ?? data['offices'] ?? data['data'];
        if (raw is List) return ManagerLocationModel.listFrom(raw);
        if (data.keys.any((k) => k == 'id' || k == 'name')) {
          return [ManagerLocationModel.fromJson(data)];
        }
        return const <ManagerLocationModel>[];
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
          message: (map['message'] as String?) ?? 'Failed to load locations.',
        );
      }

      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      if (inner is List) return {'locations': inner};

      if (fallbackKeys.any(map.containsKey) || map.containsKey('id')) {
        return map;
      }
    }

    if (json is List) return {'locations': json};

    throw const FormatException('Unexpected locations response shape.');
  }
}
