import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';
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

  Future<ApiResponse<ManagerLocationModel>> getLocation({
    required String locationId,
    String? date,
    ApiCancelToken? cancelToken,
  }) {
    final query = <String, dynamic>{
      if (date != null && date.isNotEmpty) 'date': date,
    };
    return getRequest<ManagerLocationModel>(
      ManagerEmployeeApiEndpoints.location(locationId),
      queryParameters: query.isEmpty ? null : query,
      cancelToken: cancelToken,
      parser: _parseLocation,
    );
  }

  Future<ApiResponse<ManagerLocationModel>> createLocation({
    required Map<String, dynamic> payload,
    ApiCancelToken? cancelToken,
  }) {
    return postRequest<ManagerLocationModel>(
      ManagerEmployeeApiEndpoints.addLocation,
      data: payload,
      cancelToken: cancelToken,
      parser: _parseLocation,
    );
  }

  Future<ApiResponse<ManagerLocationModel>> updateLocation({
    required String locationId,
    required Map<String, dynamic> payload,
    ApiCancelToken? cancelToken,
  }) {
    return putRequest<ManagerLocationModel>(
      ManagerEmployeeApiEndpoints.location(locationId),
      data: payload,
      cancelToken: cancelToken,
      parser: _parseLocation,
    );
  }

  Future<ApiResponse<LocationSchedule>> getLocationSchedule({
    required String locationId,
    ApiCancelToken? cancelToken,
  }) {
    return getRequest<LocationSchedule>(
      ManagerEmployeeApiEndpoints.locationSchedule(locationId),
      cancelToken: cancelToken,
      parser: (json) {
        final parsed =
            LocationSchedule.tryParse(json) ??
            LocationSchedule.tryParse(
              _extractData(
                json,
                fallbackKeys: const [
                  'schedule',
                  'attendance',
                  'check_in',
                  'check_in_time',
                ],
              ),
            );
        if (parsed == null) {
          throw const FormatException('Location schedule was empty.');
        }
        return parsed;
      },
    );
  }

  Future<ApiResponse<LocationSchedule>> updateLocationSchedule({
    required String locationId,
    required LocationSchedule schedule,
    ApiCancelToken? cancelToken,
  }) async {
    final payload = schedule.writePayload();
    final paths = [
      ManagerEmployeeApiEndpoints.locationSchedule(locationId),
      ManagerEmployeeApiEndpoints.location(locationId),
    ];

    ApiResponse<LocationSchedule>? last;
    for (final path in paths) {
      last = await putRequest<LocationSchedule>(
        path,
        data: payload,
        cancelToken: cancelToken,
        parser: (json) => _parseSchedule(json, fallback: schedule),
      );
      if (_isHttpOk(last)) return last;

      last = await patchRequest<LocationSchedule>(
        path,
        data: payload,
        cancelToken: cancelToken,
        parser: (json) => _parseSchedule(json, fallback: schedule),
      );
      if (_isHttpOk(last)) return last;
    }

    return last ?? ApiResponse.failure('Failed to save schedule.');
  }

  LocationSchedule _parseSchedule(
    dynamic json, {
    required LocationSchedule fallback,
  }) {
    try {
      final parsed = LocationSchedule.tryParse(json);
      if (parsed != null) return parsed;
      final data = _extractData(
        json,
        fallbackKeys: const [
          'schedule',
          'attendance',
          'check_in',
          'check_in_time',
          'success',
        ],
      );
      return LocationSchedule.tryParse(data) ??
          LocationSchedule.fromJson(data, fallback: fallback);
    } catch (_) {
      return fallback;
    }
  }

  bool _isHttpOk(ApiResponse<dynamic> response) {
    if (!response.success) return false;
    final code = response.statusCode;
    if (code == null) return true;
    return code >= 200 && code < 300;
  }

  Future<ApiResponse<bool>> updateLocationStatus({
    required String locationId,
    required bool isActive,
    ApiCancelToken? cancelToken,
  }) {
    return patchRequest<bool>(
      ManagerEmployeeApiEndpoints.locationStatus(locationId),
      data: {'is_active': isActive},
      cancelToken: cancelToken,
      parser: (_) => true,
    );
  }

  Future<ApiResponse<bool>> deleteLocation({
    required String locationId,
    ApiCancelToken? cancelToken,
  }) {
    return deleteRequest<bool>(
      ManagerEmployeeApiEndpoints.location(locationId),
      cancelToken: cancelToken,
      parser: (_) => true,
    );
  }

  Future<ApiResponse<int>> addLocationMembers({
    required String locationId,
    required List<String> employeeIds,
    ApiCancelToken? cancelToken,
  }) {
    return postRequest<int>(
      ManagerEmployeeApiEndpoints.locationMembers(locationId),
      data: {'employee_ids': employeeIds},
      cancelToken: cancelToken,
      parser: (json) {
        try {
          final data = _extractData(
            json,
            fallbackKeys: const [
              'added',
              'employee_ids',
              'location_id',
              'success',
            ],
          );
          final added = data['added'];
          if (added is num) return added.toInt();
          if (added is String) {
            return int.tryParse(added) ?? employeeIds.length;
          }
        } catch (_) {}
        return employeeIds.length;
      },
    );
  }

  ManagerLocationModel _parseLocation(dynamic json) {
    final data = _extractData(
      json,
      fallbackKeys: const [
        'id',
        'name',
        'schedule',
        'location',
        'attendance',
      ],
    );
    final nested = data['location'];
    if (nested is Map && data['id'] == null) {
      return ManagerLocationModel.fromJson(Map<String, dynamic>.from(nested));
    }
    return ManagerLocationModel.fromJson(data);
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
