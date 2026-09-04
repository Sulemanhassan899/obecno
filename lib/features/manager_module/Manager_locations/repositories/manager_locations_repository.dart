import 'package:flutter/foundation.dart';
import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/core/api/employee_api_endpoints.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/features/auth/data/models/permission_item_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
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

  Future<List<TimezoneLookup>> getTimezones({
    ApiCancelToken? cancelToken,
  }) async {
    const paths = [
      EmployeeApiEndpoints.timezones,
      ManagerEmployeeApiEndpoints.locationsCreate,
    ];
    for (final path in paths) {
      final result = await getRequest<List<TimezoneLookup>>(
        path,
        cancelToken: cancelToken,
        parser: _parseTimezones,
      );
      if (result.success &&
          result.data != null &&
          result.data!.isNotEmpty) {
        return result.data!;
      }
    }
    return const [];
  }

  List<TimezoneLookup> _parseTimezones(dynamic json) {
    dynamic raw = json;
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      raw =
          map['data'] ??
          map['timezones'] ??
          map['timezone'] ??
          map['timezone_options'] ??
          map['items'] ??
          json;
      if (raw is Map) {
        raw =
            raw['timezones'] ??
            raw['timezone'] ??
            raw['timezone_options'] ??
            raw['items'] ??
            raw['data'] ??
            raw['list'];
      }
    }
    if (raw is! List) return const [];
    final items = <TimezoneLookup>[];
    for (final item in raw) {
      if (item is Map) {
        items.add(TimezoneLookup.fromJson(Map<String, dynamic>.from(item)));
        continue;
      }
      final label = item?.toString().trim() ?? '';
      if (label.isEmpty) continue;
      items.add(TimezoneLookup(id: item, label: label));
    }
    return items;
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
  }) async {
    final path = ManagerEmployeeApiEndpoints.addLocation;
    debugPrint('[AddLocation] POST $path payload=$payload');
    final result = await postRequest<ManagerLocationModel>(
      path,
      data: payload,
      cancelToken: cancelToken,
      parser: _parseLocation,
    );
    debugPrint(
      '[AddLocation] POST $path -> success=${result.success} '
      'status=${result.statusCode} message=${result.message} '
      'fieldErrors=${result.fieldErrors} id=${result.data?.id} '
      'name=${result.data?.name}',
    );
    return result;
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

  Future<ApiResponse<List<PermissionItemModel>>> getLocationPermissions({
    required String locationId,
    ApiCancelToken? cancelToken,
  }) async {
    final primary = await getRequest<List<PermissionItemModel>>(
      ManagerEmployeeApiEndpoints.getLocationPermissions(locationId).path,
      cancelToken: cancelToken,
      parser: _parsePermissions,
    );
    if (primary.success &&
        primary.data != null &&
        primary.statusCode != 404) {
      return primary;
    }

    return getRequest<List<PermissionItemModel>>(
      ManagerEmployeeApiEndpoints.getLocationPermission(locationId).path,
      queryParameters: {'location_id': locationId},
      cancelToken: cancelToken,
      parser: _parsePermissions,
    );
  }

  Future<ApiResponse<LocationSchedule>> updateLocationSchedule({
    required String locationId,
    required LocationSchedule schedule,
    bool initialize = false,
    ApiCancelToken? cancelToken,
  }) async {
    final payload = schedule.permissionsApiPayload(locationId: locationId);
    debugPrint(
      '[LocationSchedule] write locationId=$locationId initialize=$initialize '
      'changed=${schedule.toDebugMap()}',
    );

    final scheduleWrite = await putRequest<LocationSchedule>(
      ManagerEmployeeApiEndpoints.putLocationSchedule(locationId).path,
      data: {
        ...schedule.toJson(),
        'schedule': schedule.toJson(),
        ...schedule.writePayload(),
      },
      cancelToken: cancelToken,
      parser: (json) => _parseSchedule(json, fallback: schedule),
    );
    debugPrint(
      '[LocationSchedule] PUT schedule response=${_isHttpOk(scheduleWrite) ? 'success' : 'failed'} '
      'status=${scheduleWrite.statusCode} message=${scheduleWrite.message}',
    );

    var hasPermissions = false;
    if (!initialize) {
      final existing = await getLocationPermissions(
        locationId: locationId,
        cancelToken: cancelToken,
      );
      hasPermissions = existing.success &&
          PermissionItemModel.hasLocationLevelPermissions(
            existing.data ?? const [],
          );
    }

    final method = PermissionItemModel.locationWriteMethod(
      hasLocationPermissions: hasPermissions,
    );
    debugPrint(
      '[LocationSchedule] permissions method=$method hasLocationLevel=$hasPermissions',
    );
    final ApiResponse<LocationSchedule> written;
    if (method == 'PUT') {
      written = await _putLocationPermissions(
        locationId: locationId,
        payload: payload,
        fallback: schedule,
        cancelToken: cancelToken,
      );
    } else {
      written = await _patchLocationPermissions(
        locationId: locationId,
        payload: payload,
        fallback: schedule,
        cancelToken: cancelToken,
      );
    }
    debugPrint(
      '[LocationSchedule] permissions response=${written.success ? 'success' : 'failed'} '
      'status=${written.statusCode} message=${written.message}',
    );
    if (_isHttpOk(written)) return written;
    if (_isHttpOk(scheduleWrite)) {
      return ApiResponse.success(
        scheduleWrite.data ?? schedule,
        message: scheduleWrite.message,
        statusCode: scheduleWrite.statusCode,
      );
    }
    return written;
  }

  Future<ApiResponse<LocationSchedule>> _putLocationPermissions({
    required String locationId,
    required Map<String, dynamic> payload,
    required LocationSchedule fallback,
    ApiCancelToken? cancelToken,
  }) async {
    final primary = ManagerEmployeeApiEndpoints.putLocationPermissions(
      locationId,
    );
    final written = await _writeLocationPermissions(
      route: primary,
      payload: payload,
      fallback: fallback,
      cancelToken: cancelToken,
    );
    if (_isHttpOk(written)) return written;
    if (written.statusCode == 404) {
      final alias = await _writeLocationPermissions(
        route: ManagerEmployeeApiEndpoints.putLocationPermission(locationId),
        payload: payload,
        fallback: fallback,
        cancelToken: cancelToken,
      );
      if (_isHttpOk(alias)) return alias;
    }
    if (written.statusCode == 409 || written.statusCode == 405) {
      return _writeLocationPermissions(
        route: ManagerEmployeeApiEndpoints.patchLocationPermissions(
          locationId,
        ),
        payload: payload,
        fallback: fallback,
        cancelToken: cancelToken,
      );
    }
    return written;
  }

  Future<ApiResponse<LocationSchedule>> _patchLocationPermissions({
    required String locationId,
    required Map<String, dynamic> payload,
    required LocationSchedule fallback,
    ApiCancelToken? cancelToken,
  }) async {
    final primary = ManagerEmployeeApiEndpoints.patchLocationPermissions(
      locationId,
    );
    final written = await _writeLocationPermissions(
      route: primary,
      payload: payload,
      fallback: fallback,
      cancelToken: cancelToken,
    );
    if (_isHttpOk(written)) return written;
    if (written.statusCode == 404) {
      final alias = await _writeLocationPermissions(
        route: ManagerEmployeeApiEndpoints.patchLocationPermission(locationId),
        payload: payload,
        fallback: fallback,
        cancelToken: cancelToken,
      );
      if (_isHttpOk(alias)) return alias;
      return _writeLocationPermissions(
        route: ManagerEmployeeApiEndpoints.putLocationPermissions(locationId),
        payload: payload,
        fallback: fallback,
        cancelToken: cancelToken,
      );
    }
    return written;
  }

  Future<ApiResponse<LocationSchedule>> _writeLocationPermissions({
    required ManagerApiRoute route,
    required Map<String, dynamic> payload,
    required LocationSchedule fallback,
    ApiCancelToken? cancelToken,
  }) {
    LocationSchedule parse(dynamic json) =>
        _parseSchedule(json, fallback: fallback);

    switch (route.method) {
      case 'PUT':
        return putRequest<LocationSchedule>(
          route.path,
          data: payload,
          cancelToken: cancelToken,
          parser: parse,
        );
      case 'PATCH':
        return patchRequest<LocationSchedule>(
          route.path,
          data: payload,
          cancelToken: cancelToken,
          parser: parse,
        );
      default:
        return Future.value(
          ApiResponse.failure(
            'Location permissions must be written with PUT or PATCH, not ${route.method}.',
          ),
        );
    }
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
          'permission_items',
          'location_setting',
        ],
      );
      final fromPerms = PermissionItemModel.listFromEnvelope(json);
      if (fromPerms.isNotEmpty) {
        return LocationSchedule.fromPermissionItems(
          fromPerms,
          fallback: fallback,
        );
      }
      return LocationSchedule.tryParse(data) ??
          LocationSchedule.fromJson(data, fallback: fallback);
    } catch (_) {
      return fallback;
    }
  }

  List<PermissionItemModel> _parsePermissions(dynamic json) {
    return PermissionItemModel.listFromEnvelope(json);
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
    final ids = [
      for (final id in employeeIds)
        int.tryParse(id.trim()) ?? id.trim(),
    ];
    final locationIdValue = int.tryParse(locationId.trim()) ?? locationId.trim();
    debugPrint(
      '[AddMembers] POST members locationId=$locationIdValue ids=$ids',
    );
    return postRequest<int>(
      ManagerEmployeeApiEndpoints.locationMembers(locationId),
      data: {
        'employee_ids': ids,
        'user_ids': ids,
        'member_ids': ids,
        'members': ids,
        'location_id': locationIdValue,
      },
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

  Future<ApiResponse<List<ManagerEmployeeModel>>> getLocationMembers({
    required String locationId,
    ApiCancelToken? cancelToken,
  }) {
    return getRequest<List<ManagerEmployeeModel>>(
      ManagerEmployeeApiEndpoints.locationMembers(locationId),
      queryParameters: {'location_id': locationId},
      cancelToken: cancelToken,
      parser: (json) {
        final data = _extractData(
          json,
          fallbackKeys: const [
            'members',
            'employees',
            'users',
            'location_id',
            'success',
          ],
        );
        final raw =
            data['members'] ??
            data['employees'] ??
            data['users'] ??
            data['data'] ??
            data['locations'];
        if (raw is List) return ManagerEmployeeModel.listFrom(raw);
        return const <ManagerEmployeeModel>[];
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
