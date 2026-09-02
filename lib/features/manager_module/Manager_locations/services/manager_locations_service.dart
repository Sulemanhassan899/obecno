import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/auth/data/models/auth_location_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/services/manager_attendance_service.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/location_attendance_stats.dart';
import 'package:obecno/features/manager_module/Manager_locations/repositories/manager_locations_repository.dart';

class ManagerLocationsService {
  ManagerLocationsService(
    this._repository, {
    List<AuthLocationModel> Function()? authLocationsProvider,
    ManagerAttendanceService? attendanceService,
    Future<LocationSchedule?> Function()? companyScheduleProvider,
  }) : _authLocationsProvider = authLocationsProvider,
       _attendanceService = attendanceService,
       _companyScheduleProvider = companyScheduleProvider;

  final ManagerLocationsRepository _repository;
  final List<AuthLocationModel> Function()? _authLocationsProvider;
  final ManagerAttendanceService? _attendanceService;
  final Future<LocationSchedule?> Function()? _companyScheduleProvider;

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
    int radiusMeters = 100,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.createLocation(
      payload: {
        'name': name,
        if (address != null && address.trim().isNotEmpty) 'address': address,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'radius_meters': radiusMeters,
      },
      cancelToken: cancelToken,
    );
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
        'radius_meters': location.radiusMeters ?? 100,
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
    String? message;
    int? statusCode;

    final results = await Future.wait([
      _repository.getLocation(locationId: locationId, cancelToken: cancelToken),
      _repository.getLocationSchedule(
        locationId: locationId,
        cancelToken: cancelToken,
      ),
    ]);
    final detail = results[0] as ApiResponse<ManagerLocationModel>;
    final dedicated = results[1] as ApiResponse<LocationSchedule>;

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

    final preferred = fromSchedule ?? fromDetail;
    final resolved = preferred ?? fallback;

    if (!detail.success && fromSchedule == null && company == null) {
      return ApiResponse.failure(
        message ?? 'Failed to load location timings.',
        statusCode: statusCode,
      );
    }

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
    final written = await _repository.updateLocationSchedule(
      locationId: locationId,
      schedule: schedule,
      cancelToken: cancelToken,
    );
    if (!written.success) return written;

    final latest = await loadLocationSchedule(
      locationId: locationId,
      cancelToken: cancelToken,
    );
    if (latest.success && latest.data != null) return latest;
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
  }) {
    return _repository.addLocationMembers(
      locationId: locationId,
      employeeIds: employeeIds,
      cancelToken: cancelToken,
    );
  }
}
