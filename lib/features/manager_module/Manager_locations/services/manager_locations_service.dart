import 'package:flutter/foundation.dart';
import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/auth/data/models/auth_company_model.dart';
import 'package:obecno/features/auth/data/models/auth_location_model.dart';
import 'package:obecno/features/auth/data/models/permission_item_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/services/manager_attendance_service.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
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

    final stamped = await _withAttendanceStats(
      locations: locations,
      date: date ?? DateTime.now(),
    );
    return ApiResponse.success(
      stamped,
      message: message,
      statusCode: statusCode,
    );
  }

  Future<List<ManagerLocationModel>> _withAttendanceStats({
    required List<ManagerLocationModel> locations,
    required DateTime date,
  }) async {
    final attendanceService = _attendanceService;
    if (attendanceService == null || locations.isEmpty) return locations;

    try {
      final response = await attendanceService.loadTeamAttendance(date: date);
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
    debugPrint(
      '[AddLocation] createLocation name="$name" '
      'seed=${seed?.id}/${seed?.name} city=${seed?.city} '
      'company=${company?.name} companyCity=${company?.cityName} '
      'resolvedCity=$resolvedCity resolvedCountry=$resolvedCountry '
      'resolvedTimezone=$resolvedTimezone',
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
    debugPrint(
      '[AddLocation] timezoneId=$resolvedTimezoneId payload=$payload',
    );
    final result = await _repository.createLocation(
      payload: payload,
      cancelToken: cancelToken,
    );
    debugPrint(
      '[AddLocation] service result success=${result.success} '
      'status=${result.statusCode} message=${result.message} '
      'fieldErrors=${result.fieldErrors} data=${result.data?.id}',
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
      debugPrint('[AddLocation] timezoneId from known seed/company=$fromKnown');
      return fromKnown;
    }

    final existing = await _repository.getLocations(cancelToken: cancelToken);
    if (existing.success && existing.data != null) {
      for (final location in existing.data!) {
        final id = ManagerLocationModel.timezoneIdFrom(location.timezoneId) ??
            ManagerLocationModel.timezoneIdFrom(location.timezone);
        if (id != null) {
          debugPrint(
            '[AddLocation] timezoneId from existing location ${location.id}=$id',
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
          debugPrint(
            '[AddLocation] timezoneId from location detail ${existing.data!.first.id}=$id',
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
    debugPrint(
      '[AddLocation] timezoneId from lookup iana=$iana '
      'options=${_timezones!.length} matched=$matched',
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
  }) {
    return _repository.updateLocation(
      locationId: location.id,
      payload: {
        'name': location.name,
        'address': location.address,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'radius_meters':
            location.radiusMeters ?? ManagerLocationModel.defaultRadiusMeters,
        'allow_checkin_anywhere': location.allowCheckinAnywhere,
      },
      cancelToken: cancelToken,
    );
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

    final lastWritten = _lastWrittenSchedules[locationId];
    final usedLastWrite =
        lastWritten != null && !resolved.samePolicyAs(lastWritten);
    if (usedLastWrite) {
      resolved = lastWritten;
    }

    if (!detail.success &&
        fromSchedule == null &&
        fromPerms.isEmpty &&
        company == null &&
        lastWritten == null) {
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
        'usedLastWrite': usedLastWrite,
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
    );
    if (!written.success) return written;

    _lastWrittenSchedules[locationId] = schedule;

    final latest = await loadLocationSchedule(
      locationId: locationId,
      cancelToken: cancelToken,
    );
    if (latest.success &&
        latest.data != null &&
        latest.data!.samePolicyAs(schedule)) {
      return latest;
    }
    return ApiResponse.success(
      written.data ?? schedule,
      message: written.message,
      statusCode: written.statusCode,
    );
  }

  Future<ApiResponse<bool>> deactivateLocation({
    required String locationId,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.updateLocationStatus(
      locationId: locationId,
      isActive: false,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<bool>> deleteLocation({
    required String locationId,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.deleteLocation(
      locationId: locationId,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<int>> addLocationMembers({
    required String locationId,
    required List<String> employeeIds,
    ApiCancelToken? cancelToken,
  }) async {
    rememberAssignedMembers(locationId, employeeIds);
    LocationPolicyLog.dump(
      sheet: 'add_members',
      phase: 'changed',
      locationId: locationId,
      extra: {'employeeIds': employeeIds.join(',')},
    );
    final result = await _repository.addLocationMembers(
      locationId: locationId,
      employeeIds: employeeIds,
      cancelToken: cancelToken,
    );
    LocationPolicyLog.dump(
      sheet: 'add_members',
      phase: 'response',
      locationId: locationId,
      success: result.success,
      statusCode: result.statusCode,
      message: result.message,
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
    if (result.success && result.data != null) {
      rememberAssignedMembers(
        locationId,
        result.data!.map((member) => member.id),
      );
    }
    LocationPolicyLog.dump(
      sheet: 'location_members',
      phase: 'fetched',
      locationId: locationId,
      success: result.success,
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
