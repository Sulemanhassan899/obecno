import 'package:flutter/foundation.dart';
import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/auth/data/models/permission_item_model.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:obecno/features/employee_module/more/data/models/device_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_resources.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/add_employee_payload.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_policy.dart';
import 'package:obecno/features/manager_module/Manager_employees/repositories/manager_employees_repository.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';

class ManagerEmployeesService {
  ManagerEmployeesService(
    this._repository, {
    String? Function()? currentUserIdProvider,
  }) : _currentUserIdProvider = currentUserIdProvider;

  final ManagerEmployeesRepository _repository;
  final String? Function()? _currentUserIdProvider;

  Future<ApiResponse<ManagerTeamMembersData>> loadTeamMembers({
    String? search,
    String? locationId,
    ApiCancelToken? cancelToken,
  }) async {
    var response = await _repository.getEmployees(
      search: search,
      locationId: locationId,
      cancelToken: cancelToken,
    );
    if (!response.success || response.data == null) {
      response = await _repository.getTeamMembers(
        search: search,
        locationId: locationId,
        cancelToken: cancelToken,
      );
    }

    if (!response.success || response.data == null) return response;

    final currentUserId = _currentUserIdProvider?.call();
    if (currentUserId == null || currentUserId.isEmpty) return response;

    final marked = response.data!.members
        .map(
          (member) => member.id == currentUserId
              ? member.copyWith(badge: ManagerEmployeeBadge.you)
              : member,
        )
        .toList(growable: false);

    return ApiResponse.success(
      ManagerTeamMembersData(total: response.data!.total, members: marked),
      message: response.message,
      statusCode: response.statusCode,
    );
  }

  Future<ApiResponse<List<ManagerDepartmentOption>>> getDepartments({
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getDepartments(cancelToken: cancelToken);
  }

  Future<ApiResponse<List<ManagerDepartmentOption>>> getCountries({
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getCountries(cancelToken: cancelToken);
  }

  Future<ApiResponse<List<ManagerDepartmentOption>>> getCities({
    String? countryId,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getCities(
      countryId: countryId,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<ManagerEmployeeModel>> addEmployee(
    AddEmployeePayload payload, {
    ApiCancelToken? cancelToken,
  }) {
    return _repository.addEmployee(
      payload: payload.toJson(),
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<int>> addEmployees(
    List<AddEmployeePayload> payloads, {
    ApiCancelToken? cancelToken,
  }) async {
    var created = 0;
    for (final payload in payloads) {
      debugPrint('[AddEmployee] sending ${payload.toJson()}');
      final result = await addEmployee(payload, cancelToken: cancelToken);
      debugPrint(
        '[AddEmployee] service result success=${result.success} '
        'code=${result.statusCode} message=${result.message}',
      );
      if (!result.success ||
          (result.statusCode != null && result.statusCode! >= 400)) {
        return ApiResponse.failure(
          result.message ?? 'Failed to add employee.',
          statusCode: result.statusCode,
          fieldErrors: result.fieldErrors,
        );
      }
      created++;
    }
    return ApiResponse.success(created, message: 'Invites sent.');
  }

  Future<ApiResponse<ManagerEmployeeModel>> loadEmployeeProfile({
    required int userId,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getEmployeeProfile(
      userId: userId,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<ManagerEmployeeModel>> updateEmployee({
    required int userId,
    required Map<String, dynamic> payload,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.updateEmployee(
      userId: userId,
      payload: payload,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<String>> updateEmployeeStatus({
    required int userId,
    required String status,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.updateEmployeeStatus(
      userId: userId,
      status: status,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<String>> updateEmployeeLocations({
    required int userId,
    required String defaultLocationId,
    required List<String> locationIds,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.updateEmployeeLocations(
      userId: userId,
      defaultLocationId: defaultLocationId,
      locationIds: locationIds,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<List<DeviceModel>>> loadEmployeeDevices({
    required int userId,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getEmployeeDevices(
      userId: userId,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<String>> reviewEmployeeDevice({
    required int userId,
    required String deviceId,
    required String action,
    ApiCancelToken? cancelToken,
  }) async {
    final result = await _repository.reviewEmployeeDevice(
      userId: userId,
      deviceId: deviceId,
      action: action,
      cancelToken: cancelToken,
    );
    if (!result.success) return result;

    var persisted = await _deviceMatchesAction(
      userId: userId,
      deviceId: deviceId,
      action: action,
      cancelToken: cancelToken,
    );
    if (persisted) return result;

    if (action == 'unblock') {
      final retry = await _repository.reviewEmployeeDevice(
        userId: userId,
        deviceId: deviceId,
        action: 'approve',
        cancelToken: cancelToken,
      );
      if (!retry.success) return retry;
      persisted = await _deviceMatchesAction(
        userId: userId,
        deviceId: deviceId,
        action: 'approve',
        cancelToken: cancelToken,
      );
      if (persisted) return retry;
    }

    return ApiResponse.failure(
      'Device status did not persist. Please try again.',
      statusCode: result.statusCode,
    );
  }

  Future<bool> _deviceMatchesAction({
    required int userId,
    required String deviceId,
    required String action,
    ApiCancelToken? cancelToken,
  }) async {
    final devices = await _repository.getEmployeeDevices(
      userId: userId,
      cancelToken: cancelToken,
    );
    if (!devices.success || devices.data == null) return true;

    final device = _findDevice(devices.data!, deviceId);
    if (device == null) return true;

    return switch (action) {
      'approve' || 'unblock' => device.isApproved,
      'reject' => device.isRejected,
      // Some APIs drop blocked devices from GET; others keep them as
      // not-approved. Either way the card must stay on the list.
      'block' => device.isBlocked || !device.isApproved,
      _ => true,
    };
  }

  DeviceModel? _findDevice(List<DeviceModel> devices, String deviceId) {
    for (final device in devices) {
      if (device.id == deviceId || device.deviceId == deviceId) return device;
    }
    return null;
  }

  Future<ApiResponse<List<PermissionItemModel>>> loadEmployeePermissions({
    required int userId,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getEmployeePermissions(
      userId: userId,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<ManagerEmployeePolicy>> loadEmployeePolicy({
    required int userId,
    ApiCancelToken? cancelToken,
  }) async {
    final profile = await _repository.getEmployeeProfile(
      userId: userId,
      cancelToken: cancelToken,
    );
    final permissions = await _repository.getEmployeePermissions(
      userId: userId,
      cancelToken: cancelToken,
    );

    final fromSchedule = profile.data?.schedule != null
        ? ManagerEmployeePolicy.fromSchedule(profile.data!.schedule!)
        : null;
    final fromPerms = permissions.success
        ? ManagerEmployeePolicy.fromItems(permissions.data ?? const [])
        : null;

    if (fromSchedule == null && fromPerms == null) {
      return ApiResponse.failure(
        permissions.message ?? profile.message ?? 'Failed to load timing.',
        statusCode: permissions.statusCode ?? profile.statusCode,
      );
    }

    return ApiResponse.success(
      ManagerEmployeePolicy(
        checkInTime: fromPerms?.checkInTime ?? fromSchedule?.checkInTime,
        checkOutTime: fromPerms?.checkOutTime ?? fromSchedule?.checkOutTime,
        gracePeriod: fromPerms?.gracePeriod ?? fromSchedule?.gracePeriod,
        breakTime: fromPerms?.breakTime ?? fromSchedule?.breakTime,
        breakLocationTracking:
            fromPerms?.breakLocationTracking ??
            fromSchedule?.breakLocationTracking ??
            true,
        workingDays: fromPerms?.workingDays ?? fromSchedule?.workingDays,
        locationName:
            fromPerms?.locationName ??
            profile.data?.locationName ??
            fromSchedule?.locationName,
      ),
      statusCode: profile.statusCode ?? permissions.statusCode,
    );
  }

  Future<ApiResponse<LocationSchedule>> loadEmployeeSchedule({
    required int userId,
    ApiCancelToken? cancelToken,
  }) async {
    final profileFuture = _repository.getEmployeeProfile(
      userId: userId,
      cancelToken: cancelToken,
    );
    final permissionsFuture = _repository.getEmployeePermissions(
      userId: userId,
      cancelToken: cancelToken,
    );
    final profile = await profileFuture;
    final permissions = await permissionsFuture;

    Map<String, dynamic>? scheduleJson;
    if (profile.data?.schedule != null) {
      scheduleJson = profile.data!.schedule;
    }

    final merged = LocationSchedule.fromEmployeeSources(
      schedule: scheduleJson,
      permissionItems: permissions.data,
    );
    final hasSource =
        (profile.data?.schedule != null) ||
        (permissions.success && (permissions.data?.isNotEmpty ?? false));
    if (!hasSource) {
      return ApiResponse.failure(
        permissions.message ??
            profile.message ??
            'Failed to load schedule.',
        statusCode: permissions.statusCode ?? profile.statusCode,
      );
    }
    return ApiResponse.success(
      merged,
      statusCode: profile.statusCode ?? permissions.statusCode,
    );
  }

  Future<ApiResponse<String>> updateEmployeeSchedule({
    required int userId,
    required Map<String, dynamic> payload,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.updateEmployeeSchedule(
      userId: userId,
      payload: payload,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<String>> updateEmployeePermissions({
    required int userId,
    required Map<String, dynamic> payload,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.updateEmployeePermissions(
      userId: userId,
      payload: payload,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<ManagerEmployeeModel>> updateEmployeePhoto({
    required int userId,
    required List<int> photoBytes,
    String? fileName,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.updateEmployeePhoto(
      userId: userId,
      photoBytes: photoBytes,
      fileName: fileName,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<List<HolidayInfo>>> loadEmployeeHolidays({
    required int userId,
    String? dateFrom,
    String? dateTo,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getEmployeeHolidays(
      userId: userId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<ManagerEmployeeFormData>> loadCreateEmployeeForm({
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getCreateEmployeeForm(cancelToken: cancelToken);
  }

  Future<ApiResponse<ManagerEmployeeFormData>> loadEditEmployeeForm({
    required int userId,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getEditEmployeeForm(
      userId: userId,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<List<ManagerEmployeeSalaryRecord>>> loadEmployeeSalary({
    required int userId,
    String? month,
    String? dateFrom,
    String? dateTo,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getEmployeeSalary(
      userId: userId,
      month: month,
      dateFrom: dateFrom,
      dateTo: dateTo,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<List<ManagerEmployeeAppraisal>>> loadEmployeeAppraisals({
    required int userId,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getEmployeeAppraisals(
      userId: userId,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<List<ManagerEmployeeLeaveRequest>>> loadEmployeeLeaves({
    required int userId,
    String? status,
    String? dateFrom,
    String? dateTo,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getEmployeeLeaves(
      userId: userId,
      status: status,
      dateFrom: dateFrom,
      dateTo: dateTo,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<List<ManagerEmployeeLeaveBalance>>>
  loadEmployeeLeaveBalances({
    required int userId,
    String? year,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getEmployeeLeaveBalances(
      userId: userId,
      year: year,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<List<ManagerEmployeeLeaveQuota>>> loadEmployeeLeaveQuota({
    required int userId,
    String? year,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getEmployeeLeaveQuota(
      userId: userId,
      year: year,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<AttendanceCalendarData>> loadEmployeeCalendar({
    required int userId,
    required String month,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getEmployeeCalendar(
      userId: userId,
      month: month,
      cancelToken: cancelToken,
    );
  }
}
