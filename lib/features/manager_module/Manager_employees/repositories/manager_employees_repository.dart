import 'package:flutter/foundation.dart';
import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/core/api/employee_api_endpoints.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/features/auth/data/models/permission_item_model.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:obecno/features/employee_module/more/data/models/device_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_resources.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/add_employee_payload.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';

class ManagerEmployeesRepository extends BaseRepository {
  ManagerEmployeesRepository(super.apiClient);

  final _savedAccountFields = <int, Map<String, String>>{};

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
        if (payload['location_id'] != null)
          'location_id': payload['location_id'],
        if (payload['default_location_id'] != null)
          'default_location_id': payload['default_location_id'],
        if (payload['location_ids'] != null)
          'location_ids': payload['location_ids'],
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
      return _finishEmployeeProfile(
        userId: userId,
        loaded: await _withEditFormAccountFields(
          userId: userId,
          employee: result.data!,
          message: result.message,
          statusCode: result.statusCode,
          cancelToken: cancelToken,
        ),
      );
    }

    final legacy = await getRequest<ManagerEmployeeModel>(
      ManagerEmployeeApiEndpoints.legacyEmployeeProfile,
      queryParameters: {'user_id': userId},
      cancelToken: cancelToken,
      parser: _parseEmployee,
    );
    if (!legacy.success || legacy.data == null) return legacy;
    return _finishEmployeeProfile(
      userId: userId,
      loaded: await _withEditFormAccountFields(
        userId: userId,
        employee: legacy.data!,
        message: legacy.message,
        statusCode: legacy.statusCode,
        cancelToken: cancelToken,
      ),
    );
  }

  ApiResponse<ManagerEmployeeModel> _finishEmployeeProfile({
    required int userId,
    required ApiResponse<ManagerEmployeeModel> loaded,
  }) {
    if (!loaded.success || loaded.data == null) return loaded;
    return ApiResponse.success(
      _withSavedAccountFields(userId, loaded.data!),
      message: loaded.message,
      statusCode: loaded.statusCode,
    );
  }

  void _rememberAccountFields(int userId, Map<String, dynamic> payload) {
    final overlay = Map<String, String>.from(
      _savedAccountFields[userId] ?? const {},
    );

    void take(String field, dynamic raw) {
      if (raw is Map || raw is List) return;
      final value = raw?.toString().trim();
      if (value == null || value.isEmpty) return;
      overlay[field] = value;
    }

    take('email', payload['email']);
    take('phone', payload['phone'] ?? payload['phone_number']);
    take(
      'employee_code',
      payload['employee_code'] ?? payload['staff_id'] ?? payload['company_id'],
    );
    take(
      'address',
      payload['address'] ??
          payload['home_address'] ??
          payload['present_address'] ??
          payload['permanent_address'],
    );
    final nested = payload['employee'] ?? payload['profile'];
    if (nested is Map) {
      take('address', nested['address'] ?? nested['home_address']);
      take('email', nested['email']);
      take('phone', nested['phone']);
      take('employee_code', nested['employee_code']);
    }
    if (overlay.isNotEmpty) _savedAccountFields[userId] = overlay;
  }

  ManagerEmployeeModel _withSavedAccountFields(
    int userId,
    ManagerEmployeeModel employee,
  ) {
    final overlay = _savedAccountFields[userId];
    if (overlay == null) return employee;

    String? prefer(String? fromApi, String? saved) {
      if (fromApi != null && fromApi.trim().isNotEmpty) return fromApi;
      return saved;
    }

    return employee.copyWith(
      email: prefer(employee.email, overlay['email']),
      phone: prefer(employee.phone, overlay['phone']),
      employeeCode: prefer(employee.employeeCode, overlay['employee_code']),
      address: prefer(employee.address, overlay['address']),
    );
  }

  Future<ApiResponse<ManagerEmployeeModel>> _withEditFormAccountFields({
    required int userId,
    required ManagerEmployeeModel employee,
    String? message,
    int? statusCode,
    ApiCancelToken? cancelToken,
  }) async {
    final missingAddress =
        employee.address == null || employee.address!.trim().isEmpty;
    if (!missingAddress) {
      return ApiResponse.success(
        employee,
        message: message,
        statusCode: statusCode,
      );
    }

    final form = await getRequest<ManagerEmployeeFormData>(
      ManagerEmployeeApiEndpoints.employeeEdit(userId),
      queryParameters: {'user_id': userId},
      cancelToken: cancelToken,
      parser: _parseEmployeeForm,
    );
    final fromForm = form.data?.employee;
    if (!_isHttpOk(form) || fromForm == null) {
      return ApiResponse.success(
        employee,
        message: message,
        statusCode: statusCode,
      );
    }
    return ApiResponse.success(
      employee.copyWith(
        address: fromForm.address ?? employee.address,
        employeeCode: employee.employeeCode ?? fromForm.employeeCode,
        email: employee.email ?? fromForm.email,
        phone: employee.phone ?? fromForm.phone,
      ),
      message: message,
      statusCode: statusCode,
    );
  }

  Future<ApiResponse<ManagerEmployeeModel>> updateEmployee({
    required int userId,
    required Map<String, dynamic> payload,
    ApiCancelToken? cancelToken,
  }) async {
    var write = await _writeEmployeeAccount(
      userId: userId,
      payload: payload,
      cancelToken: cancelToken,
    );
    if (!_isHttpOk(write)) {
      debugPrint(
        '[UpdateEmployee] failed code=${write.statusCode} '
        'message=${write.message} fields=${write.fieldErrors} payload=$payload',
      );
      return ApiResponse.failure(
        write.message ?? 'Failed to update employee.',
        statusCode: write.statusCode,
        fieldErrors: write.fieldErrors,
      );
    }
    _rememberAccountFields(userId, payload);
    final profile = await getEmployeeProfile(
      userId: userId,
      cancelToken: cancelToken,
    );
    final merged = _withSavedAccountFields(
      userId,
      _applyAccountPayload(
        profile.data ??
            ManagerEmployeeModel(id: '$userId', name: '', role: 'Employee'),
        payload,
      ),
    );
    return ApiResponse.success(
      merged,
      message: write.data,
      statusCode: write.statusCode,
    );
  }

  Future<ApiResponse<String>> _writeEmployeeAccount({
    required int userId,
    required Map<String, dynamic> payload,
    ApiCancelToken? cancelToken,
  }) async {
    final body = {'user_id': userId, ...payload};
    final query = {'user_id': userId};
    final resource = ManagerEmployeeApiEndpoints.employee(userId);

    Future<ApiResponse<String>> send(
      String method,
      String path, {
      Map<String, dynamic>? queryParameters,
    }) {
      return _send(
        method: method,
        path: path,
        payload: body,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        parser: _parseAccountWrite,
      );
    }

    var write = await send('PUT', resource);
    if (_isTerminalAccountWrite(write)) return write;

    write = await send('POST', resource);
    if (_isTerminalAccountWrite(write)) return write;

    write = await send('PATCH', resource);
    if (_isTerminalAccountWrite(write)) return write;

    write = await send(
      'POST',
      ManagerEmployeeApiEndpoints.employeeEdit(userId),
      queryParameters: query,
    );
    if (_isTerminalAccountWrite(write)) return write;

    return send(
      'POST',
      ManagerEmployeeApiEndpoints.legacyEmployeeUpdate,
      queryParameters: query,
    );
  }

  Future<ApiResponse<String>> updateEmployeeStatus({
    required int userId,
    required String status,
    ApiCancelToken? cancelToken,
  }) async {
    final normalized = status.trim().toLowerCase();
    final body = <String, dynamic>{
      'user_id': userId,
      'status': normalized,
      'account_status': normalized,
      'is_active': normalized == 'active',
    };
    final path = ManagerEmployeeApiEndpoints.employeeStatus(userId);

    var write = await _send(
      method: 'PATCH',
      path: path,
      payload: body,
      cancelToken: cancelToken,
    );
    if (_isHttpOk(write) || _isClientError(write)) return write;

    write = await _send(
      method: 'PUT',
      path: path,
      payload: body,
      cancelToken: cancelToken,
    );
    if (_isHttpOk(write) || _isClientError(write)) return write;

    write = await _send(
      method: 'POST',
      path: path,
      payload: body,
      cancelToken: cancelToken,
    );
    if (_isHttpOk(write) || _isClientError(write)) return write;

    return _mutate(
      path: ManagerEmployeeApiEndpoints.employee(userId),
      payload: body,
      cancelToken: cancelToken,
      methods: const ['PATCH', 'PUT', 'POST'],
      fallbackPath: ManagerEmployeeApiEndpoints.legacyEmployeeUpdate,
      fallbackQuery: {'user_id': userId},
    );
  }

  bool _isTerminalAccountWrite(ApiResponse<String> write) {
    return _isHttpOk(write) ||
        write.statusCode == 401 ||
        write.statusCode == 403;
  }

  ManagerEmployeeModel _applyAccountPayload(
    ManagerEmployeeModel employee,
    Map<String, dynamic> payload,
  ) {
    return employee.copyWith(
      email: payload.containsKey('email')
          ? payload['email']?.toString()
          : employee.email,
      phone: payload.containsKey('phone')
          ? payload['phone']?.toString()
          : (payload.containsKey('phone_number')
                ? payload['phone_number']?.toString()
                : employee.phone),
      employeeCode: payload.containsKey('employee_code')
          ? payload['employee_code']?.toString()
          : (payload.containsKey('staff_id')
                ? payload['staff_id']?.toString()
                : (payload.containsKey('company_id')
                      ? payload['company_id']?.toString()
                      : employee.employeeCode)),
      address: payload.containsKey('address')
          ? payload['address']?.toString()
          : (payload.containsKey('home_address')
                ? payload['home_address']?.toString()
                : employee.address),
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
      'locations': [
        for (final id in ids)
          {'id': id, 'is_default': id.trim() == defaultLocationId.trim()},
      ],
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
        fallbackPath: ManagerEmployeeApiEndpoints.legacyEmployeeUpdate,
        fallbackQuery: {'user_id': userId},
      );
    }
    return write;
  }

  Future<ApiResponse<LocationSchedule>> getEmployeeSchedule({
    required int userId,
    ApiCancelToken? cancelToken,
  }) {
    return getRequest<LocationSchedule>(
      ManagerEmployeeApiEndpoints.employee(userId),
      queryParameters: {'user_id': userId},
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
                  'working_days',
                ],
              ),
            );
        if (parsed == null) {
          throw const FormatException('Employee schedule was empty.');
        }
        return parsed;
      },
    );
  }

  Future<ApiResponse<String>> updateEmployeeSchedule({
    required int userId,
    required Map<String, dynamic> payload,
    ApiCancelToken? cancelToken,
  }) async {
    final body = {'user_id': userId, ...payload};
    var write = await _mutate(
      path: ManagerEmployeeApiEndpoints.employee(userId),
      payload: body,
      cancelToken: cancelToken,
      methods: const ['PUT', 'PATCH', 'POST'],
      fallbackPath: ManagerEmployeeApiEndpoints.legacyEmployeeUpdate,
      fallbackQuery: {'user_id': userId},
    );
    if (_isHttpOk(write)) return write;

    return _mutate(
      path: ManagerEmployeeApiEndpoints.employeePermissions(userId),
      payload: body,
      cancelToken: cancelToken,
      methods: const ['PATCH', 'PUT', 'POST'],
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
  }) async {
    final body = {'user_id': userId, ...payload};
    final path = ManagerEmployeeApiEndpoints.employeePermissions(userId);

    var write = await _send(
      method: 'PATCH',
      path: path,
      payload: body,
      cancelToken: cancelToken,
    );
    if (_isHttpOk(write) || _isClientError(write)) return write;

    final status = write.statusCode;
    if (status == 404 || status == 405 || status == 501) {
      write = await _send(
        method: 'PUT',
        path: path,
        payload: body,
        cancelToken: cancelToken,
      );
      if (_isHttpOk(write) || _isClientError(write)) return write;
    }

    return postRequest<String>(
      ManagerEmployeeApiEndpoints.legacyEmployeePermissionsUpdate,
      data: body,
      queryParameters: {'user_id': userId},
      cancelToken: cancelToken,
      parser: _parseWriteAck,
    );
  }

  Future<ApiResponse<ManagerEmployeeModel>> updateEmployeePhoto({
    required int userId,
    required List<int> photoBytes,
    String? fileName,
    ApiCancelToken? cancelToken,
  }) async {
    final fields = {'user_id': '$userId'};
    final name = (fileName == null || fileName.trim().isEmpty)
        ? 'photo.jpg'
        : fileName.trim();

    Future<ApiResponse<ManagerEmployeeModel>> send(String path) {
      return multipartPostRequest<ManagerEmployeeModel>(
        path,
        fields: fields,
        fileFieldName: 'photo',
        fileBytes: photoBytes,
        fileName: name,
        cancelToken: cancelToken,
        parser: (json) => _parsePhotoResponse(json, userId),
      );
    }

    var result = await send(ManagerEmployeeApiEndpoints.employeePhoto(userId));
    if (_isHttpOk(result)) {
      return _photoOrReload(
        userId: userId,
        result: result,
        cancelToken: cancelToken,
      );
    }
    if (_isClientError(result)) return result;

    result = await send(ManagerEmployeeApiEndpoints.legacyEmployeePhoto);
    if (_isHttpOk(result)) {
      return _photoOrReload(
        userId: userId,
        result: result,
        cancelToken: cancelToken,
      );
    }
    if (_isClientError(result)) return result;

    result = await send(ManagerEmployeeApiEndpoints.employee(userId));
    if (_isHttpOk(result)) {
      return _photoOrReload(
        userId: userId,
        result: result,
        cancelToken: cancelToken,
      );
    }
    if (_isClientError(result)) return result;

    result = await send(ManagerEmployeeApiEndpoints.legacyEmployeeUpdate);
    if (_isHttpOk(result)) {
      return _photoOrReload(
        userId: userId,
        result: result,
        cancelToken: cancelToken,
      );
    }
    return result;
  }

  Future<ApiResponse<ManagerEmployeeModel>> _photoOrReload({
    required int userId,
    required ApiResponse<ManagerEmployeeModel> result,
    ApiCancelToken? cancelToken,
  }) async {
    final photo = result.data?.photo?.trim() ?? '';
    if (photo.isNotEmpty) return result;
    final profile = await getEmployeeProfile(
      userId: userId,
      cancelToken: cancelToken,
    );
    if (profile.success && profile.data != null) return profile;
    return result;
  }

  ManagerEmployeeModel _parsePhotoResponse(dynamic json, int userId) {
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      if (map['success'] == false) {
        throw ApiError(
          type: ApiErrorType.server,
          message: (map['message'] as String?) ?? 'Failed to update photo.',
        );
      }
      try {
        final employee = _parseEmployee(map);
        if ((employee.photo ?? '').trim().isNotEmpty) return employee;
      } catch (error) {
        if (error is ApiError) rethrow;
      }
      final photo = _photoUrlFrom(map);
      if (photo != null) {
        return ManagerEmployeeModel(
          id: '$userId',
          name: '',
          role: 'Employee',
          photo: photo,
        );
      }
    }
    return ManagerEmployeeModel(id: '$userId', name: '', role: 'Employee');
  }

  String? _photoUrlFrom(Map<String, dynamic> map) {
    String? take(Map<String, dynamic> source) {
      final raw =
          source['photo_url'] ??
          source['profile_picture'] ??
          source['avatar_url'] ??
          source['image_url'] ??
          source['photo'] ??
          source['avatar'] ??
          source['image'] ??
          source['url'];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      return null;
    }

    final direct = take(map);
    if (direct != null) return direct;
    final data = map['data'];
    if (data is Map) {
      return take(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<ApiResponse<List<HolidayInfo>>> getEmployeeHolidays({
    required int userId,
    String? dateFrom,
    String? dateTo,
    ApiCancelToken? cancelToken,
  }) {
    return _getEmployeeResource<List<HolidayInfo>>(
      userId: userId,
      path: ManagerEmployeeApiEndpoints.employeeHolidays(userId),
      legacyPath: ManagerEmployeeApiEndpoints.legacyEmployeeHolidays,
      extraQuery: {
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
      },
      cancelToken: cancelToken,
      parser: _parseHolidays,
    );
  }

  Future<ApiResponse<ManagerEmployeeFormData>> getCreateEmployeeForm({
    ApiCancelToken? cancelToken,
  }) {
    return getRequest<ManagerEmployeeFormData>(
      ManagerEmployeeApiEndpoints.employeesCreate,
      cancelToken: cancelToken,
      parser: _parseEmployeeForm,
    );
  }

  Future<ApiResponse<ManagerEmployeeFormData>> getEditEmployeeForm({
    required int userId,
    ApiCancelToken? cancelToken,
  }) async {
    final result = await getRequest<ManagerEmployeeFormData>(
      ManagerEmployeeApiEndpoints.employeeEdit(userId),
      queryParameters: {'user_id': userId},
      cancelToken: cancelToken,
      parser: _parseEmployeeForm,
    );
    if (_isHttpOk(result) && result.statusCode != 404) return result;

    final profile = await getEmployeeProfile(
      userId: userId,
      cancelToken: cancelToken,
    );
    if (!profile.success || profile.data == null) {
      return ApiResponse.failure(
        profile.message ?? 'Failed to load employee form.',
        statusCode: profile.statusCode,
      );
    }
    return ApiResponse.success(
      ManagerEmployeeFormData(employee: profile.data),
      message: profile.message,
      statusCode: profile.statusCode,
    );
  }

  Future<ApiResponse<List<ManagerEmployeeSalaryRecord>>> getEmployeeSalary({
    required int userId,
    String? month,
    String? dateFrom,
    String? dateTo,
    ApiCancelToken? cancelToken,
  }) {
    return _getEmployeeResource<List<ManagerEmployeeSalaryRecord>>(
      userId: userId,
      path: ManagerEmployeeApiEndpoints.employeeSalary(userId),
      legacyPath: ManagerEmployeeApiEndpoints.legacyEmployeeSalary,
      extraQuery: {
        if (month != null && month.isNotEmpty) 'month': month,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
      },
      cancelToken: cancelToken,
      parser: ManagerEmployeeSalaryRecord.listFrom,
    );
  }

  Future<ApiResponse<List<ManagerEmployeeAppraisal>>> getEmployeeAppraisals({
    required int userId,
    ApiCancelToken? cancelToken,
  }) {
    return _getEmployeeResource<List<ManagerEmployeeAppraisal>>(
      userId: userId,
      path: ManagerEmployeeApiEndpoints.employeeAppraisals(userId),
      legacyPath: ManagerEmployeeApiEndpoints.legacyEmployeeAppraisals,
      cancelToken: cancelToken,
      parser: ManagerEmployeeAppraisal.listFrom,
    );
  }

  Future<ApiResponse<List<ManagerEmployeeLeaveRequest>>> getEmployeeLeaves({
    required int userId,
    String? status,
    String? dateFrom,
    String? dateTo,
    ApiCancelToken? cancelToken,
  }) {
    return _getEmployeeResource<List<ManagerEmployeeLeaveRequest>>(
      userId: userId,
      path: ManagerEmployeeApiEndpoints.employeeLeaves(userId),
      legacyPath: ManagerEmployeeApiEndpoints.legacyEmployeeLeaves,
      extraQuery: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
      },
      cancelToken: cancelToken,
      parser: ManagerEmployeeLeaveRequest.listFrom,
    );
  }

  Future<ApiResponse<List<ManagerEmployeeLeaveBalance>>>
  getEmployeeLeaveBalances({
    required int userId,
    String? year,
    ApiCancelToken? cancelToken,
  }) {
    return _getEmployeeResource<List<ManagerEmployeeLeaveBalance>>(
      userId: userId,
      path: ManagerEmployeeApiEndpoints.employeeLeaveBalances(userId),
      legacyPath: ManagerEmployeeApiEndpoints.legacyEmployeeLeaveBalances,
      extraQuery: {if (year != null && year.isNotEmpty) 'year': year},
      cancelToken: cancelToken,
      parser: ManagerEmployeeLeaveBalance.listFrom,
    );
  }

  Future<ApiResponse<List<ManagerEmployeeLeaveQuota>>> getEmployeeLeaveQuota({
    required int userId,
    String? year,
    ApiCancelToken? cancelToken,
  }) {
    return _getEmployeeResource<List<ManagerEmployeeLeaveQuota>>(
      userId: userId,
      path: ManagerEmployeeApiEndpoints.employeeLeaveQuota(userId),
      legacyPath: ManagerEmployeeApiEndpoints.legacyEmployeeLeaveQuota,
      extraQuery: {if (year != null && year.isNotEmpty) 'year': year},
      cancelToken: cancelToken,
      parser: ManagerEmployeeLeaveQuota.listFrom,
    );
  }

  Future<ApiResponse<AttendanceCalendarData>> getEmployeeCalendar({
    required int userId,
    required String month,
    ApiCancelToken? cancelToken,
  }) {
    return _getEmployeeResource<AttendanceCalendarData>(
      userId: userId,
      path: ManagerEmployeeApiEndpoints.employeeCalendar(userId),
      legacyPath: ManagerEmployeeApiEndpoints.legacyEmployeeCalendar,
      extraQuery: {'month': month},
      cancelToken: cancelToken,
      parser: _parseCalendar,
    );
  }

  ManagerEmployeeModel _parseEmployee(dynamic json) {
    if (json is! Map) {
      throw const FormatException('Unexpected employee response shape.');
    }
    final map = Map<String, dynamic>.from(json);
    if (map['success'] == false) {
      throw ApiError(
        type: ApiErrorType.server,
        message: (map['message'] as String?) ?? 'Failed to load employee.',
      );
    }
    return ManagerEmployeeModel.fromApiJson(map);
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
      final items = PermissionItemModel.listFromEnvelope(inner);
      final overridden = _employeeOverriddenKeys(map, inner);
      if (overridden.isEmpty) return items;
      return [
        for (final item in items)
          if (overridden.contains(item.key) && !item.hasEmployeeLevel)
            PermissionItemModel.fromJson({
              ...item.toJson(),
              'source_level': 'employee',
              'is_override': true,
              'employee_value':
                  (item.employeeValue ?? item.value)?.toString(),
            })
          else
            item,
      ];
    }
    return PermissionItemModel.listFromEnvelope(json);
  }

  Set<String> _employeeOverriddenKeys(dynamic outer, dynamic inner) {
    final keys = <String>{};
    void take(dynamic raw) {
      if (raw is! List) return;
      for (final item in raw) {
        final value = item?.toString().trim();
        if (value != null && value.isNotEmpty) keys.add(value);
      }
    }

    if (outer is Map) {
      take(outer['employee_overridden_keys']);
    }
    if (inner is Map) {
      take(inner['employee_overridden_keys']);
    }
    return keys;
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

  ManagerEmployeeFormData _parseEmployeeForm(dynamic json) {
    if (_looksLikeHtml(json)) {
      return const ManagerEmployeeFormData();
    }
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      if (map['success'] == false) {
        throw ApiError(
          type: ApiErrorType.server,
          message: (map['message'] as String?) ?? 'Failed to load form.',
        );
      }
      final inner = map['data'];
      if (inner is Map) {
        return ManagerEmployeeFormData.fromJson(
          Map<String, dynamic>.from(inner),
        );
      }
      return ManagerEmployeeFormData.fromJson(map);
    }
    return const ManagerEmployeeFormData();
  }

  AttendanceCalendarData _parseCalendar(dynamic json) {
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      if (map['success'] == false) {
        throw ApiError(
          type: ApiErrorType.server,
          message: (map['message'] as String?) ?? 'Failed to load calendar.',
        );
      }
      final inner = map['data'];
      if (inner is Map) {
        return AttendanceCalendarData.fromJson(
          Map<String, dynamic>.from(inner),
        );
      }
      return AttendanceCalendarData.fromJson(map);
    }
    return const AttendanceCalendarData();
  }

  Future<ApiResponse<T>> _getEmployeeResource<T>({
    required int userId,
    required String path,
    required String legacyPath,
    required T Function(dynamic json) parser,
    Map<String, dynamic>? extraQuery,
    ApiCancelToken? cancelToken,
  }) async {
    final query = <String, dynamic>{
      'user_id': userId,
      if (extraQuery != null) ...extraQuery,
    };
    final result = await getRequest<T>(
      path,
      queryParameters: query,
      cancelToken: cancelToken,
      parser: parser,
    );
    if (_isHttpOk(result) && result.statusCode != 404) return result;

    return getRequest<T>(
      legacyPath,
      queryParameters: query,
      cancelToken: cancelToken,
      parser: parser,
    );
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
        statusCode: 422,
        fieldErrors: mapApiFieldErrors(map),
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
          lower.contains('blocked') ||
          lower.contains('unblocked') ||
          lower.contains('deactivated') ||
          lower.contains('activated') ||
          lower.contains('disabled');
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

  String _parseAccountWrite(dynamic json) {
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      if (map['success'] == false) {
        throw ApiError(
          type: ApiErrorType.validation,
          message: (map['message'] as String?) ?? 'Failed to save changes.',
          statusCode: 422,
          fieldErrors: mapApiFieldErrors(map),
        );
      }
      final message = (map['message'] as String?)?.trim() ?? '';
      return message.isEmpty ? 'Changes saved.' : message;
    }
    return _parseWriteAck(json);
  }

  bool _isHttpOk(ApiResponse<dynamic> result) {
    if (!result.success) return false;
    final code = result.statusCode;
    if (code == null) return true;
    return code >= 200 && code < 300;
  }

  bool _isClientError(ApiResponse<dynamic> result) {
    final code = result.statusCode;
    return code == 400 ||
        code == 401 ||
        code == 403 ||
        code == 409 ||
        code == 422;
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
        if (_isClientError(last)) return last;
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
    String Function(dynamic json)? parser,
  }) {
    final parse = parser ?? _parseWriteAck;
    switch (method.toUpperCase()) {
      case 'PATCH':
        return patchRequest<String>(
          path,
          data: payload,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
          parser: parse,
        );
      case 'POST':
        return postRequest<String>(
          path,
          data: payload,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
          parser: parse,
        );
      default:
        return putRequest<String>(
          path,
          data: payload,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
          parser: parse,
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
