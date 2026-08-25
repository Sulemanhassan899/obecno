import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_employee_attendance_model.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/features/manager_module/Manager_attendance/repositories/manager_attendance_repository.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/repositories/manager_employees_repository.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';

class ManagerAttendanceService {
  ManagerAttendanceService(
    this._repository, {
    ManagerEmployeesRepository? employeesRepository,
  }) : _employeesRepository = employeesRepository;

  final ManagerAttendanceRepository _repository;
  final ManagerEmployeesRepository? _employeesRepository;

  Future<ApiResponse<ManagerTeamAttendanceData>> loadTeamAttendance({
    required DateTime date,
    String? search,
    ApiCancelToken? cancelToken,
  }) async {
    final attendanceFuture = _repository.getTeamAttendance(
      date: _yyyyMMdd(date),
      search: search,
      cancelToken: cancelToken,
    );
    final membersFuture = _loadMembers(cancelToken);

    final attendanceResponse = await attendanceFuture;
    final members = await membersFuture;

    if (!attendanceResponse.success || attendanceResponse.data == null) {
      return attendanceResponse;
    }

    final merged = TeamAttendanceMapper.mergeWithMembers(
      attendance: attendanceResponse.data!.attendance,
      members: members,
    );

    return ApiResponse.success(
      ManagerTeamAttendanceData(
        date: attendanceResponse.data!.date,
        departmentId: attendanceResponse.data!.departmentId,
        filter: attendanceResponse.data!.filter,
        search: attendanceResponse.data!.search,
        total: merged.length,
        attendance: merged,
      ),
      message: attendanceResponse.message,
      statusCode: attendanceResponse.statusCode,
    );
  }

  Future<ApiResponse<ManagerEmployeeAttendanceData>> loadEmployeeAttendance({
    required int userId,
    required DateTime date,
    ApiCancelToken? cancelToken,
  }) {
    return loadEmployeeAttendanceRange(
      userId: userId,
      from: date,
      to: date,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<ManagerEmployeeAttendanceData>> loadEmployeeAttendanceRange({
    required int userId,
    required DateTime from,
    required DateTime to,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.getEmployeeAttendance(
      userId: userId,
      dateFrom: _yyyyMMdd(from),
      dateTo: _yyyyMMdd(to),
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<String>> saveEmployeeAttendance({
    required int? attendanceId,
    required int? userId,
    required DateTime day,
    required String deviceDetails,
    required double lat,
    required double lon,
    String? checkIn,
    String? checkOut,
    String? breakStart,
    String? breakEnd,
    required List<AttendanceChangeRequestPayload> changes,
    ApiCancelToken? cancelToken,
  }) {
    return _repository.saveEmployeeAttendance(
      attendanceId: attendanceId,
      userId: userId,
      date: _yyyyMMdd(day),
      deviceDetails: deviceDetails,
      lat: lat,
      lon: lon,
      checkIn: checkIn,
      checkOut: checkOut,
      breakStart: breakStart,
      breakEnd: breakEnd,
      changes: changes,
      cancelToken: cancelToken,
    );
  }

  Future<String?> loadEmployeePhoto({
    required int userId,
    ApiCancelToken? cancelToken,
  }) async {
    final repo = _employeesRepository;
    if (repo == null) return null;
    final userKey = userId.toString();

    try {
      final profile = await repo.getEmployeeProfile(
        userId: userId,
        cancelToken: cancelToken,
      );
      final photo = profile.data?.photo;
      if (photo != null && photo.isNotEmpty) return photo;
    } catch (_) {}

    try {
      final response = await repo.getEmployees(cancelToken: cancelToken);
      final photo = _photoForUser(response.data?.members, userKey);
      if (photo != null) return photo;
    } catch (_) {}

    try {
      final response = await repo.getTeamMembers(cancelToken: cancelToken);
      return _photoForUser(response.data?.members, userKey);
    } catch (_) {
      return null;
    }
  }

  static String? _photoForUser(
    List<ManagerEmployeeModel>? members,
    String userId,
  ) {
    if (members == null) return null;
    for (final member in members) {
      if (member.id != userId) continue;
      final photo = member.photo;
      if (photo != null && photo.isNotEmpty) return photo;
    }
    return null;
  }

  static String yyyyMMdd(DateTime date) => _yyyyMMdd(date);

  static String _yyyyMMdd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<List<ManagerEmployeeModel>> _loadMembers(
    ApiCancelToken? cancelToken,
  ) async {
    final repo = _employeesRepository;
    if (repo == null) return const [];
    try {
      var response = await repo.getEmployees(cancelToken: cancelToken);
      if (!response.success || response.data == null) {
        response = await repo.getTeamMembers(cancelToken: cancelToken);
      }
      if (!response.success || response.data == null) return const [];
      return response.data!.members;
    } catch (_) {
      return const [];
    }
  }
}
