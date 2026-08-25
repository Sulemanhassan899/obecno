import 'package:flutter/foundation.dart';
import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/core/api/employee_api_endpoints.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/features/auth/data/models/permission_item_model.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:obecno/features/employee_module/more/data/models/device_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/add_employee_payload.dart';

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

  Future<ApiResponse<ManagerTeamMembersData>> getEmployees({
    String? search,
    String? locationId,
    ApiCancelToken? cancelToken,
  }) {
    final query = <String, dynamic>{
      if (search != null && search.isNotEmpty) 'q': search,
      if (search != null && search.isNotEmpty) 'search': search,
      if (locationId != null && locationId.isNotEmpty && locationId != 'all')
        'location_id': locationId,
    };

    return getRequest<ManagerTeamMembersData>(
      ManagerEmployeeApiEndpoints.employees,
      queryParameters: query.isEmpty ? null : query,
      cancelToken: cancelToken,
      parser: (json) {
        final data = _extractData(
          json,
          fallbackKeys: const ['members', 'employees', 'total', 'counts'],
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

  Future<ApiResponse<ManagerEmployeeModel>> addEmployee({
    required Map<String, dynamic> payload,
    ApiCancelToken? cancelToken,
  }) async {
    debugPrint('[AddEmployee] POST ${ManagerEmployeeApiEndpoints.addEmployee}');
    debugPrint('[AddEmployee] payload=$payload');
    final created = await postRequest<ManagerEmployeeModel>(
      ManagerEmployeeApiEndpoints.addEmployee,
      data: payload,
      cancelToken: cancelToken,
      parser: (json) => _parseCreatedEmployee(json, payload),
    );
    debugPrint(
      '[AddEmployee] create result success=${created.success} '
      'code=${created.statusCode} message=${created.message} '
      'fields=${created.fieldErrors}',
    );
    if (_isHttpOk(created) || !_shouldFallbackToInvite(created)) {
      return created;
    }

    debugPrint(
      '[AddEmployee] falling back to POST ${ManagerEmployeeApiEndpoints.inviteEmployees}',
    );
    final invited = await postRequest<ManagerEmployeeModel>(
      ManagerEmployeeApiEndpoints.inviteEmployees,
      data: {
        'email': payload['email'],
        if (payload['name'] != null) 'name': payload['name'],
        if (payload['job_title'] != null) 'job_title': payload['job_title'],
        if (payload['department_id'] != null)
          'department_id': payload['department_id'],
        if (payload['location_id'] != null) 'location_id': payload['location_id'],
        if (payload['default_location_id'] != null)
          'default_location_id': payload['default_location_id'],
        if (payload['location_ids'] != null) 'location_ids': payload['location_ids'],
        'invites': [
          {
            'email': payload['email'],
            if (payload['location_id'] != null)
              'location_id': payload['location_id'],
          },
        ],
      },
      cancelToken: cancelToken,
      parser: (json) => _parseCreatedEmployee(json, payload),
    );
    debugPrint(
      '[AddEmployee] invite result success=${invited.success} '
      'code=${invited.statusCode} message=${invited.message} '
      'fields=${invited.fieldErrors}',
    );
    return _isHttpOk(invited) ? invited : created;
  }

  Future<ApiResponse<List<ManagerDepartmentOption>>> getDepartments({
    ApiCancelToken? cancelToken,
  }) {
    return getRequest<List<ManagerDepartmentOption>>(
      ManagerEmployeeApiEndpoints.departments,
      cancelToken: cancelToken,
      parser: (json) => _parseLookupList(json, emptyMessage: 'departments'),
    );
  }

  Future<ApiResponse<List<ManagerDepartmentOption>>> getCountries({
    ApiCancelToken? cancelToken,
  }) {
    return getRequest<List<ManagerDepartmentOption>>(
      EmployeeApiEndpoints.countries,
      cancelToken: cancelToken,
      parser: (json) => _parseLookupList(json, emptyMessage: 'countries'),
    );
  }

  Future<ApiResponse<List<ManagerDepartmentOption>>> getCities({
    String? countryId,
    ApiCancelToken? cancelToken,
  }) {
    final query = <String, dynamic>{
      if (countryId != null && countryId.trim().isNotEmpty)
        'country_id': countryId.trim(),
    };
    return getRequest<List<ManagerDepartmentOption>>(
      EmployeeApiEndpoints.cities,
      queryParameters: query.isEmpty ? null : query,
      cancelToken: cancelToken,
      parser: (json) => _parseLookupList(json, emptyMessage: 'cities'),
    );
  }

  ManagerEmployeeModel _parseCreatedEmployee(
    dynamic json,
    Map<String, dynamic> payload,
  ) {
    debugPrint('[AddEmployee] response body=$json');
    if (_looksLikeHtml(json)) {
      throw const ApiError(
        type: ApiErrorType.server,
        message: 'Failed to send invite. Please try again.',
      );
    }
    try {
      return _parseEmployee(json);
    } catch (error) {
      debugPrint('[AddEmployee] employee parse failed: $error');
      if (error is ApiError) rethrow;
      if (json is Map && json['success'] != false) {
        return ManagerEmployeeModel(
          id: '',
          name: (payload['name'] as String?)?.trim() ?? '',
          role: (payload['job_title'] as String?)?.trim().isNotEmpty == true
              ? payload['job_title'] as String
              : 'Employee',
          email: payload['email']?.toString(),
          status: ManagerEmployeeStatus.pending,
        );
      }
      throw ApiError(
        type: ApiErrorType.parsing,
        message: 'Failed to read server response. Please try again.',
      );
    }
  }

  bool _shouldFallbackToInvite(ApiResponse<dynamic> result) {
    final code = result.statusCode;
    return code == 404 || code == 405;
  }

  List<ManagerDepartmentOption> _parseLookupList(
    dynamic json, {
    required String emptyMessage,
  }) {
    dynamic raw = json;
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      if (map['success'] == false) {
        throw ApiError(
          type: ApiErrorType.server,
          message:
              (map['message'] as String?) ?? 'Failed to load $emptyMessage.',
        );
      }
      raw =
          map['data'] ??
          map['departments'] ??
          map['countries'] ??
          map['cities'] ??
          map['items'] ??
          json;
      if (raw is Map) {
        raw =
            raw['departments'] ??
            raw['countries'] ??
            raw['cities'] ??
            raw['items'] ??
            raw['data'] ??
            raw['list'];
      }
    }
    if (raw is! List) return const [];
    final items = <ManagerDepartmentOption>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id =
          (map['id'] ??
                  map['department_id'] ??
                  map['country_id'] ??
                  map['city_id'] ??
                  map['user_id'] ??
                  '')
              .toString()
              .trim();
      final name =
          (map['name'] ??
                  map['title'] ??
                  map['department_title'] ??
                  map['label'] ??
                  '')
              .toString()
              .trim();
      if (id.isEmpty || id.toLowerCase() == 'all') continue;
      items.add(
        ManagerDepartmentOption(
          id: id,
          name: name.isEmpty ? '$emptyMessage $id' : name,
        ),
      );
    }
    return items;
  }

  bool _looksLikeHtml(dynamic json) {
    if (json is! String) return false;
    final value = json.trimLeft().toLowerCase();
    return value.startsWith('<!doctype') || value.startsWith('<html');
  }

  Future<ApiResponse<ManagerEmployeeModel>> getEmployeeProfile({
    required int userId,
    ApiCancelToken? cancelToken,
  }) async {
    final result = await getRequest<ManagerEmployeeModel>(
      ManagerEmployeeApiEndpoints.employee(userId),
      cancelToken: cancelToken,
      parser: _parseEmployee,
    );
    if (result.success && result.data != null && result.statusCode != 404) {
      return result;
    }

    return getRequest<ManagerEmployeeModel>(
      ManagerEmployeeApiEndpoints.legacyEmployeeProfile,
      queryParameters: {'user_id': userId},
      cancelToken: cancelToken,
      parser: _parseEmployee,
    );
  }

  Future<ApiResponse<ManagerEmployeeModel>> updateEmployee({
    required int userId,
    required Map<String, dynamic> payload,
    ApiCancelToken? cancelToken,
  }) async {
    final body = {'user_id': userId, ...payload};
    final write = await _mutate(
      path: ManagerEmployeeApiEndpoints.employee(userId),
      payload: body,
      cancelToken: cancelToken,
      methods: const ['PATCH', 'PUT', 'POST'],
      fallbackPath: ManagerEmployeeApiEndpoints.legacyEmployeeProfile,
      fallbackQuery: {'user_id': userId},
    );
    if (!_isHttpOk(write)) {
      return ApiResponse.failure(
        write.message ?? 'Failed to update employee.',
        statusCode: write.statusCode,
      );
    }
    final profile = await getEmployeeProfile(
      userId: userId,
      cancelToken: cancelToken,
    );
    if (profile.success && profile.data != null) return profile;
    return ApiResponse.success(
      ManagerEmployeeModel(id: '$userId', name: '', role: 'Employee'),
      message: write.data,
      statusCode: write.statusCode,
    );
  }

  Future<ApiResponse<String>> updateEmployeeLocations({
    required int userId,
    required String defaultLocationId,
    required List<String> locationIds,
    ApiCancelToken? cancelToken,
  }) async {
    final ids = locationIds.isEmpty ? [defaultLocationId] : locationIds;
    final body = <String, dynamic>{
      'user_id': userId,
      'default_location_id': defaultLocationId,
      'location_id': defaultLocationId,
      'location_ids': ids,
    };
    var write = await _mutate(
      path: ManagerEmployeeApiEndpoints.employeeLocations(userId),
      payload: body,
      cancelToken: cancelToken,
      methods: const ['PUT', 'PATCH', 'POST'],
    );
    if (!_isHttpOk(write)) {
      write = await _mutate(
        path: ManagerEmployeeApiEndpoints.employee(userId),
        payload: body,
        cancelToken: cancelToken,
        methods: const ['PATCH', 'PUT', 'POST'],
        fallbackPath: ManagerEmployeeApiEndpoints.legacyEmployeeProfile,
        fallbackQuery: {'user_id': userId},
      );
    }
    return write;
  }

  Future<ApiResponse<String>> updateEmployeeSchedule({
    required int userId,
    required Map<String, dynamic> payload,
    ApiCancelToken? cancelToken,
  }) async {
    final body = {'user_id': userId, ...payload};
    var write = await _mutate(
      path: ManagerEmployeeApiEndpoints.employeeSchedule(userId),
      payload: body,
      cancelToken: cancelToken,
      methods: const ['PUT', 'PATCH', 'POST'],
    );
    if (_isHttpOk(write)) return write;

    return _mutate(
      path: ManagerEmployeeApiEndpoints.employeePermissions(userId),
      payload: body,
      cancelToken: cancelToken,
      methods: const ['PUT', 'PATCH', 'POST'],
      fallbackPath: ManagerEmployeeApiEndpoints.legacyEmployeePermissions,
      fallbackQuery: {'user_id': userId},
    );
  }

  Future<ApiResponse<List<DeviceModel>>> getEmployeeDevices({
    required int userId,
    ApiCancelToken? cancelToken,
  }) async {
    final result = await getRequest<List<DeviceModel>>(
      ManagerEmployeeApiEndpoints.employeeDevices(userId),
      cancelToken: cancelToken,
      parser: _parseDevices,
    );
    if (_isHttpOk(result) && result.statusCode != 404) return result;

    return getRequest<List<DeviceModel>>(
      ManagerEmployeeApiEndpoints.legacyEmployeeDevices,
      queryParameters: {'user_id': userId},
      cancelToken: cancelToken,
      parser: _parseDevices,
    );
  }

  Future<ApiResponse<String>> reviewEmployeeDevice({
    required int userId,
    required String deviceId,
    required String action,
    ApiCancelToken? cancelToken,
  }) async {
    final resolvedAction = action == 'unblock' ? 'approve' : action;
    final body = <String, dynamic>{
      'action': action,
      'status': resolvedAction,
      'user_id': userId,
      'device_id': deviceId,
      if (resolvedAction == 'approve') 'is_approved': true,
      if (resolvedAction == 'approve') 'approval_status': 'approved',
      if (resolvedAction == 'reject') 'is_approved': false,
      if (resolvedAction == 'reject') 'approval_status': 'rejected',
      if (resolvedAction == 'block') 'approval_status': 'blocked',
    };

    var result = await postRequest<String>(
      ManagerEmployeeApiEndpoints.employeeDeviceReview(userId, deviceId),
      data: {'action': action, 'user_id': userId},
      cancelToken: cancelToken,
      parser: _parseWriteAck,
    );
    if (_isHttpOk(result)) return result;

    if (action == 'unblock') {
      result = await postRequest<String>(
        ManagerEmployeeApiEndpoints.employeeDeviceReview(userId, deviceId),
        data: {'action': 'approve', 'user_id': userId},
        cancelToken: cancelToken,
        parser: _parseWriteAck,
      );
      if (_isHttpOk(result)) return result;
    }

    result = await _mutate(
      path: ManagerEmployeeApiEndpoints.employeeDevice(userId, deviceId),
      payload: body,
      cancelToken: cancelToken,
      methods: const ['PATCH', 'PUT', 'POST'],
    );
    if (_isHttpOk(result)) return result;

    result = await postRequest<String>(
      ManagerEmployeeApiEndpoints.employeeDeviceAction(
        userId,
        deviceId,
        action,
      ),
      data: body,
      cancelToken: cancelToken,
      parser: _parseWriteAck,
    );
    if (_isHttpOk(result)) return result;

    return postRequest<String>(
      ManagerEmployeeApiEndpoints.legacyEmployeeDevices,
      data: body,
      cancelToken: cancelToken,
      parser: _parseWriteAck,
    );
  }

  Future<ApiResponse<List<PermissionItemModel>>> getEmployeePermissions({
    required int userId,
    ApiCancelToken? cancelToken,
  }) async {
    final result = await getRequest<List<PermissionItemModel>>(
      ManagerEmployeeApiEndpoints.employeePermissions(userId),
      cancelToken: cancelToken,
      parser: _parsePermissions,
    );
    if (result.success && result.data != null && result.statusCode != 404) {
      return result;
    }

    return getRequest<List<PermissionItemModel>>(
      ManagerEmployeeApiEndpoints.legacyEmployeePermissions,
      queryParameters: {'user_id': userId},
      cancelToken: cancelToken,
      parser: _parsePermissions,
    );
  }

  Future<ApiResponse<String>> updateEmployeePermissions({
    required int userId,
    required Map<String, dynamic> payload,
    ApiCancelToken? cancelToken,
  }) {
    return updateEmployeeSchedule(
      userId: userId,
      payload: payload,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<List<HolidayInfo>>> getEmployeeHolidays({
    required int userId,
    String? dateFrom,
    String? dateTo,
    ApiCancelToken? cancelToken,
  }) async {
    final query = <String, dynamic>{
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      'user_id': userId,
    };
    final result = await getRequest<List<HolidayInfo>>(
      ManagerEmployeeApiEndpoints.employeeHolidays(userId),
      queryParameters: query,
      cancelToken: cancelToken,
      parser: _parseHolidays,
    );
    if (result.success && result.data != null) return result;

    return getRequest<List<HolidayInfo>>(
      ManagerEmployeeApiEndpoints.legacyEmployeeHolidays,
      queryParameters: query,
      cancelToken: cancelToken,
      parser: _parseHolidays,
    );
  }

  ManagerEmployeeModel _parseEmployee(dynamic json) {
    final data = _extractData(
      json,
      fallbackKeys: const [
        'id',
        'name',
        'photo',
        'photo_url',
        'profile_picture',
        'employee',
        'email',
      ],
    );
    final employeeRaw = data['employee'] ?? data['profile'] ?? data['user'];
    if (employeeRaw is Map) {
      return ManagerEmployeeModel.fromJson({
        ...data,
        ...Map<String, dynamic>.from(employeeRaw),
      });
    }
    return ManagerEmployeeModel.fromJson(data);
  }

  List<DeviceModel> _parseDevices(dynamic json) {
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      if (map['success'] == false) {
        throw ApiError(
          type: ApiErrorType.server,
          message: (map['message'] as String?) ?? 'Failed to load devices.',
        );
      }
    }
    return DeviceModel.listFromEnvelope(json);
  }

  List<PermissionItemModel> _parsePermissions(dynamic json) {
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      final inner = map['data'] ?? map;
      return PermissionItemModel.listFromEnvelope(inner);
    }
    return PermissionItemModel.listFromEnvelope(json);
  }

  List<HolidayInfo> _parseHolidays(dynamic json) {
    dynamic raw = json;
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      raw = map['data'] ?? map['holidays'] ?? map['items'] ?? json;
    }
    if (raw is! List) return const [];
    final holidays = <HolidayInfo>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final dateRaw = map['date'] ?? map['holiday_date'] ?? map['day'];
      final parsed = DateTime.tryParse(dateRaw?.toString() ?? '');
      if (parsed == null) continue;
      holidays.add(
        HolidayInfo(
          date: DateTime(parsed.year, parsed.month, parsed.day),
          name:
              (map['name'] ?? map['title'] ?? map['label'] ?? 'Public Holiday')
                  .toString(),
        ),
      );
    }
    return holidays;
  }

  String _parseWriteAck(dynamic json) {
    if (json == null) return 'Changes saved.';
    if (json is String) {
      final text = json.trim();
      if (text.isEmpty) return 'Changes saved.';
      if (text.startsWith('<')) {
        throw const ApiError(
          type: ApiErrorType.server,
          message: 'Failed to save changes.',
        );
      }
      return text;
    }
    if (json is! Map) {
      throw const ApiError(
        type: ApiErrorType.parsing,
        message: 'Failed to save changes.',
      );
    }

    final map = Map<String, dynamic>.from(json);
    if (map['success'] == false) {
      throw ApiError(
        type: ApiErrorType.validation,
        message: (map['message'] as String?) ?? 'Failed to save changes.',
      );
    }

    final message = (map['message'] as String?)?.trim() ?? '';
    final data = map['data'];
    final looksLikeReadDump =
        data is List ||
        (data is Map &&
            (data.containsKey('permission_items') ||
                data.containsKey('devices') ||
                data.containsKey('members') ||
                data.containsKey('employees')));
    if (looksLikeReadDump) {
      final lower = message.toLowerCase();
      final mutated =
          lower.contains('updated') ||
          lower.contains('saved') ||
          lower.contains('changed') ||
          lower.contains('approved') ||
          lower.contains('rejected') ||
          lower.contains('blocked');
      if (!mutated) {
        throw const ApiError(
          type: ApiErrorType.server,
          message: 'Failed to save changes.',
        );
      }
    }

    if (message.isNotEmpty) return message;
    return 'Changes saved.';
  }

  bool _isHttpOk(ApiResponse<dynamic> result) {
    if (!result.success) return false;
    final code = result.statusCode;
    if (code == null) return true;
    return code >= 200 && code < 300;
  }

  Future<ApiResponse<String>> _mutate({
    required String path,
    required Map<String, dynamic> payload,
    List<String> methods = const ['PUT', 'PATCH', 'POST'],
    String? fallbackPath,
    Map<String, dynamic>? fallbackQuery,
    ApiCancelToken? cancelToken,
  }) async {
    final targets = <({String path, Map<String, dynamic>? query})>[
      (path: path, query: null),
      if (fallbackPath != null) (path: fallbackPath, query: fallbackQuery),
    ];

    ApiResponse<String>? last;
    for (final target in targets) {
      for (final method in methods) {
        last = await _send(
          method: method,
          path: target.path,
          payload: payload,
          queryParameters: target.query,
          cancelToken: cancelToken,
        );
        if (_isHttpOk(last)) return last;
      }
    }
    return last ?? ApiResponse.failure('Failed to save changes.');
  }

  Future<ApiResponse<String>> _send({
    required String method,
    required String path,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? queryParameters,
    ApiCancelToken? cancelToken,
  }) {
    switch (method.toUpperCase()) {
      case 'PATCH':
        return patchRequest<String>(
          path,
          data: payload,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
          parser: _parseWriteAck,
        );
      case 'POST':
        return postRequest<String>(
          path,
          data: payload,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
          parser: _parseWriteAck,
        );
      default:
        return putRequest<String>(
          path,
          data: payload,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
          parser: _parseWriteAck,
        );
    }
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
