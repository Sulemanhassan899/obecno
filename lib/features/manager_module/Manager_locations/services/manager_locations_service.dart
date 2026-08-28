import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/auth/data/models/auth_location_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/services/manager_attendance_service.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/location_attendance_stats.dart';
import 'package:obecno/features/manager_module/Manager_locations/repositories/manager_locations_repository.dart';

class ManagerLocationsService {
  ManagerLocationsService(
    this._repository, {
    List<AuthLocationModel> Function()? authLocationsProvider,
    ManagerAttendanceService? attendanceService,
  }) : _authLocationsProvider = authLocationsProvider,
       _attendanceService = attendanceService;

  final ManagerLocationsRepository _repository;
  final List<AuthLocationModel> Function()? _authLocationsProvider;
  final ManagerAttendanceService? _attendanceService;

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
}
