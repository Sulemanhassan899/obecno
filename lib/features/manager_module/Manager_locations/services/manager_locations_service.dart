import 'package:flutter/foundation.dart';
import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/features/auth/data/models/auth_company_model.dart';
import 'package:obecno/features/auth/data/models/auth_location_model.dart';
import 'package:obecno/features/auth/data/models/permission_item_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/services/manager_attendance_service.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/add_location_log.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/location_attendance_stats.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/location_policy_log.dart';
import 'package:obecno/features/manager_module/Manager_locations/repositories/manager_locations_repository.dart';

class ManagerLocationsService {
  ManagerLocationsService(
    this._repository, {
    List<AuthLocationModel> Function()? authLocationsProvider,
    AuthCompanyModel? Function()? companyProvider,
    ManagerAttendanceService? attendanceService,
    Future<LocationSchedule?> Function()? companyScheduleProvider,
  }) : _authLocationsProvider = authLocationsProvider,
       _companyProvider = companyProvider,
       _attendanceService = attendanceService,
       _companyScheduleProvider = companyScheduleProvider;

  final ManagerLocationsRepository _repository;
  final List<AuthLocationModel> Function()? _authLocationsProvider;
  final AuthCompanyModel? Function()? _companyProvider;
  final ManagerAttendanceService? _attendanceService;
  final Future<LocationSchedule?> Function()? _companyScheduleProvider;
  final Map<String, Set<String>> _assignedMemberIds = {};
  final Map<String, LocationSchedule> _lastWrittenSchedules = {};

  void rememberAssignedMembers(String locationId, Iterable<String> ids) {
    final key = locationId.trim();
    if (key.isEmpty) return;
    _assignedMemberIds.putIfAbsent(key, () => {}).addAll(
      ids.map((id) => id.trim()).where((id) => id.isNotEmpty),
    );
  }

  Set<String> assignedMemberIds(String locationId) {
    return Set<String>.from(_assignedMemberIds[locationId.trim()] ?? const {});
  }

  /// Fast locations list for counts / directory. Attendance present/total is
  /// filled later via [enrichWithAttendanceStats] so Overview is not blocked
  /// on the heavy team-attendance hydrate (per-employee punch lookups).
  Future<ApiResponse<List<ManagerLocationModel>>> loadLocations({
    DateTime? date,
    ApiCancelToken? cancelToken,
  }) async {
    final response = await _repository.getLocations(
      date: date == null ? null : _yyyyMMdd(date),
      cancelToken: cancelToken,
    );

    List<ManagerLocationModel> locations = const [];
    String? message = response.message;
    int? statusCode = response.statusCode;

    if (response.success &&
        response.data != null &&
        response.data!.isNotEmpty) {
      locations = response.data!;
    } else {
      final fallback = _authLocationsProvider?.call() ?? const [];
      if (fallback.isEmpty) return response;
      locations = fallback
          .map(ManagerLocationModel.fromAuth)
          .toList(growable: false);
    }

    return ApiResponse.success(
      locations,
      message: message,
      statusCode: statusCode,
    );
  }

  /// Stamps present / total / late onto [locations]. Safe to run after the
  /// list is already shown — failures leave the input list unchanged.
  Future<List<ManagerLocationModel>> enrichWithAttendanceStats({
    required List<ManagerLocationModel> locations,
    DateTime? date,
  }) async {
    final attendanceService = _attendanceService;
    if (attendanceService == null || locations.isEmpty) return locations;

    try {
      final response = await attendanceService.loadTeamAttendance(
        date: date ?? DateTime.now(),
      );
      if (!response.success || response.data == null) return locations;
      return LocationAttendanceStats.stamp(
        locations: locations,
        attendance: response.data!.attendance,
        members: response.data!.members,
      );
    } catch (_) {
      return locations;
    }
  }

  String _yyyyMMdd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<ApiResponse<ManagerLocationModel>> loadLocation({
    required String locationId,
    DateTime? date,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getLocation(
      locationId: locationId,
      date: date == null ? null : _yyyyMMdd(date),
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<ManagerLocationModel>> createLocation({
    required String name,
    String? address,
    double? latitude,
    double? longitude,
    int radiusMeters = ManagerLocationModel.defaultRadiusMeters,
    String? city,
    String? country,
    Object? cityId,
    Object? countryId,
    String? timezone,
    Object? timezoneId,
    ApiCancelToken? cancelToken,
  }) async {
    final seed = _locationSeed();
    final company = _companyProvider?.call();
    final resolvedCity = city ?? seed?.city ?? company?.cityName;
    final resolvedCountry = country ?? seed?.country ?? company?.countryName;
    final resolvedTimezone = ManagerLocationModel.timezoneFor(
      timezone: timezone ?? seed?.timezone ?? company?.timezone,
      city: resolvedCity,
      country: resolvedCountry,
    );
    final resolvedTimezoneId = await _resolveTimezoneId(
      explicit: timezoneId,
      seed: seed,
      company: company,
      iana: resolvedTimezone,
      city: resolvedCity,
      country: resolvedCountry,
      cancelToken: cancelToken,
    );
    final payload = ManagerLocationModel.createPayload(
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      city: resolvedCity,
      country: resolvedCountry,
      cityId: cityId ?? seed?.cityId ?? company?.cityId,
      countryId: countryId ?? seed?.countryId ?? company?.countryId,
      timezone: resolvedTimezone,
      timezoneId: resolvedTimezoneId,
    );
    AddLocationLog.dump(
      sheet: 'New Location',
      phase: 'user sending',
      api: 'POST ${ManagerEmployeeApiEndpoints.addLocation}',
      apiNeeds: AddLocationLog.createApiNeeds,
      userSending: payload,
      extra: {
        'typedName': name,
        'seed': '${seed?.id}/${seed?.name}',
        'company': company?.name,
        'resolvedCity': resolvedCity,
        'resolvedCountry': resolvedCountry,
        'resolvedTimezone': resolvedTimezone,
        'timezoneId': resolvedTimezoneId,
      },
    );
    final result = await _repository.createLocation(
      payload: payload,
      cancelToken: cancelToken,
    );
    AddLocationLog.dump(
      sheet: 'New Location',
      phase: 'response',
      api: 'POST ${ManagerEmployeeApiEndpoints.addLocation}',
      success: result.success,
      statusCode: result.statusCode,
      message: result.message,
      fieldErrors: result.fieldErrors,
      extra: {'id': result.data?.id, 'name': result.data?.name},
    );
    if (result.success && result.data != null) {
      LocationSchedule? company;
      try {
        company = await _companyScheduleProvider?.call();
      } catch (_) {}
      await _repository.updateLocationSchedule(
        locationId: result.data!.id,
        schedule: result.data!.schedule ?? company ?? LocationSchedule.defaults,
        initialize: true,
        cancelToken: cancelToken,
      );
      _lastWrittenSchedules[result.data!.id] =
          result.data!.schedule ?? company ?? LocationSchedule.defaults;
    }
    return result;
  }

  List<TimezoneLookup>? _timezones;

  Future<Object?> _resolveTimezoneId({
    Object? explicit,
    AuthLocationModel? seed,
    AuthCompanyModel? company,
    required String iana,
    String? city,
    String? country,
    ApiCancelToken? cancelToken,
  }) async {
    final fromKnown = ManagerLocationModel.timezoneIdFrom(explicit) ??
        ManagerLocationModel.timezoneIdFrom(seed?.timezoneId) ??
        ManagerLocationModel.timezoneIdFrom(seed?.timezone) ??
        ManagerLocationModel.timezoneIdFrom(company?.timezoneId) ??
        ManagerLocationModel.timezoneIdFrom(company?.timezone);
    if (fromKnown != null) {
      AddLocationLog.dump(
        sheet: 'New Location',
        phase: 'timezone',
        extra: {'timezoneId': fromKnown, 'source': 'seed/company'},
      );
      return fromKnown;
    }

    final existing = await _repository.getLocations(cancelToken: cancelToken);
    if (existing.success && existing.data != null) {
      for (final location in existing.data!) {
        final id = ManagerLocationModel.timezoneIdFrom(location.timezoneId) ??
            ManagerLocationModel.timezoneIdFrom(location.timezone);
        if (id != null) {
          AddLocationLog.dump(
            sheet: 'New Location',
            phase: 'timezone',
            extra: {
              'timezoneId': id,
              'source': 'existing location ${location.id}',
            },
          );
          return id;
        }
      }
      if (existing.data!.isNotEmpty) {
        final detail = await _repository.getLocation(
          locationId: existing.data!.first.id,
          cancelToken: cancelToken,
        );
        final id = ManagerLocationModel.timezoneIdFrom(detail.data?.timezoneId) ??
            ManagerLocationModel.timezoneIdFrom(detail.data?.timezone);
        if (id != null) {
          AddLocationLog.dump(
            sheet: 'New Location',
            phase: 'timezone',
            extra: {
              'timezoneId': id,
              'source': 'location detail ${existing.data!.first.id}',
            },
          );
          return id;
        }
      }
    }

    _timezones ??= await _repository.getTimezones(cancelToken: cancelToken);
    final matched = TimezoneLookup.matchId(
      _timezones!,
      iana: iana,
      city: city,
      country: country,
    );
    AddLocationLog.dump(
      sheet: 'New Location',
      phase: 'timezone',
      extra: {
        'timezoneId': matched,
        'source': 'lookup',
        'iana': iana,
        'options': _timezones!.length,
      },
    );
    return matched;
  }

  AuthLocationModel? _locationSeed() {
    final locations = _authLocationsProvider?.call() ?? const [];
    if (locations.isEmpty) return null;
    for (final location in locations) {
      if (location.isDefault) return location;
    }
    for (final location in locations) {
      final hasCity =
          (location.city?.trim().isNotEmpty ?? false) || location.cityId != null;
      if (hasCity) return location;
    }
    return locations.first;
  }

  Future<ApiResponse<ManagerLocationModel>> updateLocation({
    required ManagerLocationModel location,
    ApiCancelToken? cancelToken,
  }) async {
    final payload = {
      'name': location.name,
      'address': location.address,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'radius_meters':
          location.radiusMeters ?? ManagerLocationModel.defaultRadiusMeters,
      'allow_checkin_anywhere': location.allowCheckinAnywhere,
    };
    final api =
        'GET ${ManagerEmployeeApiEndpoints.getLocation(location.id).path} then '
        'PATCH|PUT ${ManagerEmployeeApiEndpoints.location(location.id)}';
    AddLocationLog.dump(
      sheet: 'Set up Location',
      phase: 'user sending',
      api: api,
      apiNeeds: AddLocationLog.updatePinApiNeeds,
      userSending: payload,
    );
    final result = await _repository.updateLocation(
      locationId: location.id,
      payload: payload,
      cancelToken: cancelToken,
    );
    AddLocationLog.dump(
      sheet: 'Set up Location',
      phase: 'response',
      api: api,
      success: result.success,
      statusCode: result.statusCode,
      message: result.message,
      fieldErrors: result.fieldErrors,
      extra: {'id': result.data?.id, 'address': result.data?.address},
    );
    return result;
  }

  Future<ApiResponse<LocationSchedule>> loadLocationSchedule({
    required String locationId,
    ApiCancelToken? cancelToken,
  }) async {
    LocationSchedule? company;
    try {
      company = await _companyScheduleProvider?.call();
    } catch (_) {}
    final fallback = company ?? LocationSchedule.defaults;

    LocationSchedule? fromDetail;
    LocationSchedule? fromSchedule;
    List<PermissionItemModel> fromPerms = const [];
    String? message;
    int? statusCode;

    final results = await Future.wait([
      _repository.getLocation(locationId: locationId, cancelToken: cancelToken),
      _repository.getLocationSchedule(
        locationId: locationId,
        cancelToken: cancelToken,
      ),
      _repository.getLocationPermissions(
        locationId: locationId,
        cancelToken: cancelToken,
      ),
    ]);
    final detail = results[0] as ApiResponse<ManagerLocationModel>;
    final dedicated = results[1] as ApiResponse<LocationSchedule>;
    final permissions = results[2] as ApiResponse<List<PermissionItemModel>>;

    message = detail.message;
    statusCode = detail.statusCode;
    if (detail.success && detail.data != null) {
      fromDetail = detail.data!.schedule;
    }

    if (dedicated.success && dedicated.data != null) {
      fromSchedule = dedicated.data;
      statusCode = dedicated.statusCode ?? statusCode;
    } else if (fromDetail == null) {
      message = dedicated.message ?? message;
    }

    if (permissions.success && permissions.data != null) {
      fromPerms = permissions.data!;
    }

    final scheduleBase = fromSchedule ?? fromDetail ?? fallback;
    final hasLocationPerms =
        PermissionItemModel.hasLocationLevelPermissions(fromPerms);
    var resolved = hasLocationPerms
        ? LocationSchedule.fromPermissionItems(
            fromPerms,
            locationOnly: true,
            fallback: scheduleBase,
          )
        : scheduleBase;

    // Working days are often stored via the location form (`working_days[]=mon`)
    // and echoed on GET as `value` + source_level=location without location_value.
    // A strict locationOnly read then falls back to company Mon–Fri incorrectly.
    final hasLocationWorkingDays =
        PermissionItemModel.hasLocationLevelPermissions(
          fromPerms,
          section: 'working_days',
          keys: LocationSchedule.workingDaysPermissionKeys,
        );
    if (hasLocationWorkingDays) {
      final daysResolved = LocationSchedule.fromPermissionItems(
        fromPerms,
        locationOnly: false,
        fallback: resolved,
      );
      resolved = resolved.copyWith(
        workingDays: daysResolved.workingDays,
        weekStartDay: daysResolved.weekStartDay,
        hoursPerDay: daysResolved.hoursPerDay,
        hoursPerWeek: daysResolved.hoursPerWeek,
        workingWeekEnabled: daysResolved.workingWeekEnabled,
      );
    }

    final hasLocationBreak = PermissionItemModel.hasLocationLevelPermissions(
      fromPerms,
      section: 'break_timing',
      keys: LocationSchedule.breakTimingPermissionKeys,
    );
    if (hasLocationBreak) {
      final breakResolved = LocationSchedule.fromPermissionItems(
        fromPerms,
        locationOnly: false,
        fallback: resolved,
      );
      resolved = resolved.copyWith(
        maxBreakMinutes: breakResolved.maxBreakMinutes,
        breakLocationTracking: breakResolved.breakLocationTracking,
      );
    }

    final hasLocationAttendance =
        PermissionItemModel.hasLocationLevelPermissions(
          fromPerms,
          section: 'attendance',
          keys: LocationSchedule.attendancePermissionKeys,
        );
    if (hasLocationAttendance) {
      final attendanceResolved = LocationSchedule.fromPermissionItems(
        fromPerms,
        locationOnly: false,
        fallback: resolved,
      );
      resolved = resolved.copyWith(
        checkIn: attendanceResolved.checkIn,
        checkOut: attendanceResolved.checkOut,
        graceMinutes: attendanceResolved.graceMinutes,
      );
    }

    // Drop stale optimistic cache — never substitute it for a real GET.
    _lastWrittenSchedules.remove(locationId);

    if (!detail.success &&
        fromSchedule == null &&
        fromPerms.isEmpty &&
        company == null) {
      LocationPolicyLog.dump(
        sheet: 'location_schedule',
        phase: 'fetched',
        locationId: locationId,
        success: false,
        statusCode: statusCode,
        message: message ?? 'Failed to load location timings.',
      );
      return ApiResponse.failure(
        message ?? 'Failed to load location timings.',
        statusCode: statusCode,
      );
    }

    LocationPolicyLog.dump(
      sheet: 'location_schedule',
      phase: 'fetched',
      locationId: locationId,
      schedule: resolved,
      success: true,
      statusCode: statusCode,
      extra: {
        'permissionItems': fromPerms.length,
        'hasLocationPermissions': hasLocationPerms,
        'usedLastWrite': false,
        'fromDetail': fromDetail != null,
        'fromScheduleEndpoint': fromSchedule != null,
      },
    );

    return ApiResponse.success(
      resolved,
      message: message,
      statusCode: statusCode,
    );
  }

  Future<ApiResponse<LocationSchedule>> updateLocationSchedule({
    required String locationId,
    required LocationSchedule schedule,
    ApiCancelToken? cancelToken,
  }) async {
    LocationPolicyLog.dump(
      sheet: 'location_schedule',
      phase: 'changed',
      locationId: locationId,
      schedule: schedule,
      api:
          'GET ${ManagerEmployeeApiEndpoints.getLocation(locationId).path} + '
          'GET ${ManagerEmployeeApiEndpoints.getLocationPermissions(locationId).path} '
          'then PATCH|PUT location and permissions',
      apiNeeds: AddLocationLog.scheduleApiNeeds,
      userSending: schedule.toJson(),
    );
    final written = await _repository.updateLocationSchedule(
      locationId: locationId,
      schedule: schedule,
      cancelToken: cancelToken,
    );
    LocationPolicyLog.dump(
      sheet: 'location_schedule',
      phase: 'response',
      locationId: locationId,
      schedule: written.data ?? schedule,
      success: written.success,
      statusCode: written.statusCode,
      message: written.message,
      api:
          'PATCH|PUT ${ManagerEmployeeApiEndpoints.location(locationId)} + '
          'PATCH|PUT ${ManagerEmployeeApiEndpoints.locationPermissions(locationId)}',
    );
    if (!written.success) return written;

    // Do not cache the outbound payload as truth — re-read from the server.
    _lastWrittenSchedules.remove(locationId);
    final latest = await loadLocationSchedule(
      locationId: locationId,
      cancelToken: cancelToken,
    );
    if (latest.success &&
        latest.data != null &&
        latest.data!.samePolicyAs(schedule)) {
      return latest;
    }

    // Working days often 200 on write but GET still returns company values.
    final readBack = latest.data;
    final daysMatch = readBack != null &&
        readBack.workingDays.length == schedule.workingDays.length &&
        schedule.workingDays.every(readBack.workingDays.contains);
    if (!daysMatch) {
      debugPrint(
        '[LocationSchedule] working_days did not persist for '
        'location=$locationId wanted=${schedule.workingDays} '
        'got=${readBack?.workingDays}',
      );
      return ApiResponse.failure(
        'Working days did not persist on the server. Please try again.',
        statusCode: written.statusCode,
      );
    }

    final breakMatch = readBack != null &&
        readBack.maxBreakMinutes == schedule.maxBreakMinutes &&
        readBack.breakLocationTracking == schedule.breakLocationTracking;
    if (!breakMatch) {
      debugPrint(
        '[LocationSchedule] break_timing did not persist for '
        'location=$locationId wanted=${schedule.maxBreakMinutes}/'
        '${schedule.breakLocationTracking} '
        'got=${readBack.maxBreakMinutes}/${readBack.breakLocationTracking}',
      );
      return ApiResponse.failure(
        'Break timing did not persist on the server. Please try again.',
        statusCode: written.statusCode,
      );
    }

    final graceMatch =
        readBack != null && readBack.graceMinutes == schedule.graceMinutes;
    if (!graceMatch) {
      debugPrint(
        '[LocationSchedule] grace_period did not persist for '
        'location=$locationId wanted=${schedule.graceMinutes} '
        'got=${readBack.graceMinutes}',
      );
      return ApiResponse.failure(
        'Grace period did not persist on the server. Please try again.',
        statusCode: written.statusCode,
      );
    }

    return ApiResponse.success(
      readBack ?? written.data ?? schedule,
      message: written.message,
      statusCode: written.statusCode,
    );
  }

  Future<ApiResponse<bool>> deactivateLocation({
    required String locationId,
    ApiCancelToken? cancelToken,
  }) async {
    AddLocationLog.dump(
      sheet: 'Deactivate Location',
      phase: 'user sending',
      api: 'PATCH/PUT/POST status · inactive · location',
      apiNeeds: 'is_active',
      userSending: {'location_id': locationId, 'is_active': false},
    );
    final result = await _repository.updateLocationStatus(
      locationId: locationId,
      isActive: false,
      cancelToken: cancelToken,
    );
    debugPrint(
      '[LocationStatus] service.deactivate '
      'id=$locationId success=${result.isHttpOk} '
      'status=${result.statusCode} message=${result.message}',
    );
    AddLocationLog.dump(
      sheet: 'Deactivate Location',
      phase: 'response',
      api: 'updateLocationStatus',
      success: result.isHttpOk,
      statusCode: result.statusCode,
      message: result.message,
    );
    return result.isHttpOk
        ? result
        : ApiResponse.failure(
            result.message ?? 'Failed to deactivate location.',
            statusCode: result.statusCode,
            fieldErrors: result.fieldErrors,
          );
  }

  Future<ApiResponse<bool>> activateLocation({
    required String locationId,
    ApiCancelToken? cancelToken,
  }) async {
    AddLocationLog.dump(
      sheet: 'Activate Location',
      phase: 'user sending',
      api: 'PATCH/PUT/POST status · active · location',
      apiNeeds: 'is_active',
      userSending: {'location_id': locationId, 'is_active': true},
    );
    final result = await _repository.updateLocationStatus(
      locationId: locationId,
      isActive: true,
      cancelToken: cancelToken,
    );
    debugPrint(
      '[LocationStatus] service.activate '
      'id=$locationId success=${result.isHttpOk} '
      'status=${result.statusCode} message=${result.message}',
    );
    AddLocationLog.dump(
      sheet: 'Activate Location',
      phase: 'response',
      api: 'updateLocationStatus',
      success: result.isHttpOk,
      statusCode: result.statusCode,
      message: result.message,
    );
    return result.isHttpOk
        ? result
        : ApiResponse.failure(
            result.message ?? 'Failed to activate location.',
            statusCode: result.statusCode,
            fieldErrors: result.fieldErrors,
          );
  }

  void clearAssignedMembers(String locationId) {
    _assignedMemberIds.remove(locationId.trim());
  }

  Future<ApiResponse<bool>> deleteLocation({
    required String locationId,
    ApiCancelToken? cancelToken,
  }) async {
    final api = 'DELETE ${ManagerEmployeeApiEndpoints.location(locationId)}';
    AddLocationLog.dump(
      sheet: 'Delete Location',
      phase: 'user sending',
      api: api,
      apiNeeds: 'location_id (path)',
      userSending: {'location_id': locationId},
    );
    final result = await _repository.deleteLocation(
      locationId: locationId,
      cancelToken: cancelToken,
    );
    AddLocationLog.dump(
      sheet: 'Delete Location',
      phase: 'response',
      api: api,
      success: result.success,
      statusCode: result.statusCode,
      message: result.message,
    );
    return result;
  }

  Future<ApiResponse<int>> addLocationMembers({
    required String locationId,
    required List<String> employeeIds,
    ApiCancelToken? cancelToken,
  }) async {
    rememberAssignedMembers(locationId, employeeIds);
    final api =
        'POST ${ManagerEmployeeApiEndpoints.locationMembers(locationId)}';
    LocationPolicyLog.dump(
      sheet: 'Add Member',
      phase: 'changed',
      locationId: locationId,
      api: api,
      apiNeeds: AddLocationLog.membersApiNeeds,
      userSending: {'location_id': locationId, 'employee_ids': employeeIds},
      extra: {'employeeIds': employeeIds.join(',')},
    );
    final result = await _repository.addLocationMembers(
      locationId: locationId,
      employeeIds: employeeIds,
      cancelToken: cancelToken,
    );
    LocationPolicyLog.dump(
      sheet: 'Add Member',
      phase: 'response',
      locationId: locationId,
      success: result.success,
      statusCode: result.statusCode,
      message: result.message,
      api:
          'POST ${ManagerEmployeeApiEndpoints.locationMembers(locationId)}',
      extra: {
        'added': result.data,
        'employeeIds': employeeIds.join(','),
      },
    );
    return result;
  }

  Future<ApiResponse<List<ManagerEmployeeModel>>> loadLocationMembers({
    required String locationId,
    ApiCancelToken? cancelToken,
  }) async {
    final result = await _repository.getLocationMembers(
      locationId: locationId,
      cancelToken: cancelToken,
    );
    if (result.isHttpOk && result.data != null) {
      rememberAssignedMembers(
        locationId,
        result.data!.map((member) => member.id),
      );
    }
    LocationPolicyLog.dump(
      sheet: 'location_members',
      phase: 'fetched',
      locationId: locationId,
      success: result.isHttpOk,
      statusCode: result.statusCode,
      message: result.message,
      extra: {
        'employees': (result.data ?? const [])
            .map((member) => member.id)
            .join(','),
      },
    );
    return result;
  }
}
