import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_employee_attendance_model.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';

class ManagerAttendanceRepository extends BaseRepository {
  ManagerAttendanceRepository(super.apiClient);

  Future<ApiResponse<ManagerTeamAttendanceData>> getTeamAttendance({
    String? date,
    String? filter,
    String? search,
    String? locationId,
    ApiCancelToken? cancelToken,
  }) {
    final query = <String, dynamic>{
      if (date != null && date.isNotEmpty) 'date': date,
      if (filter != null && filter.isNotEmpty && filter != 'all')
        'filter': filter,
      if (search != null && search.isNotEmpty) 'search': search,
      if (locationId != null && locationId.isNotEmpty && locationId != 'all')
        'location_id': locationId,
    };

    return getRequest<ManagerTeamAttendanceData>(
      ManagerEmployeeApiEndpoints.teamAttendance,
      queryParameters: query.isEmpty ? null : query,
      cancelToken: cancelToken,
      parser: (json) {
        final data = _extractData(
          json,
          fallbackKeys: const ['date', 'attendance', 'total'],
        );
        if (data['attendance'] == null && json is Map && json['data'] is List) {
          return ManagerTeamAttendanceData.fromJson({
            'attendance': json['data'],
            'total': (json['data'] as List).length,
          });
        }
        return ManagerTeamAttendanceData.fromJson(data);
      },
    );
  }

  Future<ApiResponse<ManagerEmployeeAttendanceData>> getEmployeeAttendance({
    required int userId,
    required String dateFrom,
    required String dateTo,
    ApiCancelToken? cancelToken,
  }) async {
    final query = {
      'date_from': dateFrom,
      'date_to': dateTo,
      'user_id': userId,
    };

    final result = await getRequest<ManagerEmployeeAttendanceData>(
      ManagerEmployeeApiEndpoints.employeeAttendance(userId),
      queryParameters: query,
      cancelToken: cancelToken,
      parser: _parseEmployeeAttendance,
    );
    if (result.success && result.data != null) return result;

    return getRequest<ManagerEmployeeAttendanceData>(
      ManagerEmployeeApiEndpoints.legacyEmployeeAttendance,
      queryParameters: query,
      cancelToken: cancelToken,
      parser: _parseEmployeeAttendance,
    );
  }

  ManagerEmployeeAttendanceData _parseEmployeeAttendance(dynamic json) {
    final data = _extractData(
      json,
      fallbackKeys: const ['employee', 'history', 'hours_totals'],
    );
    return ManagerEmployeeAttendanceData.fromJson(data);
  }

  /// Applies check-in / check-out / break times immediately (manager save).
  Future<ApiResponse<String>> saveEmployeeAttendance({
    required int? attendanceId,
    required int? userId,
    required String date,
    required String deviceDetails,
    required double lat,
    required double lon,
    String? checkIn,
    String? checkOut,
    String? breakStart,
    String? breakEnd,
    required List<AttendanceChangeRequestPayload> changes,
    ApiCancelToken? cancelToken,
  }) async {
    final resolvedId = await _resolveAttendanceId(
      attendanceId: attendanceId,
      userId: userId,
      date: date,
      cancelToken: cancelToken,
    );

    final body = editSaveBody(
      attendanceId: resolvedId,
      userId: userId,
      date: date,
      deviceDetails: deviceDetails,
      lat: lat,
      lon: lon,
      checkIn: checkIn,
      checkOut: checkOut,
      breakStart: breakStart,
      breakEnd: breakEnd,
      changes: changes,
    );

    var result = await postRequest<String>(
      ManagerEmployeeApiEndpoints.teamAttendanceEditSave,
      cancelToken: cancelToken,
      data: body,
      parser: _parseSaveMessage,
    );

    if (_isRecordNotFound(result)) {
      result = await postRequest<String>(
        ManagerEmployeeApiEndpoints.teamAttendanceEdit,
        cancelToken: cancelToken,
        data: body,
        parser: _parseSaveMessage,
      );
    }

    if (_isRecordNotFound(result) && userId != null) {
      result = await putRequest<String>(
        '/manager/employees/$userId/attendance',
        cancelToken: cancelToken,
        data: {
          'date': date,
          if (resolvedId != null) 'attendance_id': resolvedId,
          if (checkIn != null && checkIn.isNotEmpty) 'check_in': checkIn,
          if (checkOut != null && checkOut.isNotEmpty) 'check_out': checkOut,
          if (breakStart != null && breakStart.isNotEmpty)
            'breakout': breakStart,
          if (breakEnd != null && breakEnd.isNotEmpty) 'breakin': breakEnd,
          'changes': changes.map((e) => e.toJson()).toList(),
        },
        parser: _parseSaveMessage,
      );
    }

    return result;
  }

  static Map<String, dynamic> editSaveBody({
    required int? attendanceId,
    required int? userId,
    required String date,
    required String deviceDetails,
    required double lat,
    required double lon,
    String? checkIn,
    String? checkOut,
    String? breakStart,
    String? breakEnd,
    required List<AttendanceChangeRequestPayload> changes,
  }) {
    return {
      if (attendanceId != null) 'id': attendanceId,
      if (attendanceId != null) 'attendance_id': attendanceId,
      if (userId != null) 'user_id': userId,
      'date': date,
      'device_details': deviceDetails,
      'lat': lat,
      'lon': lon,
      if (checkIn != null && checkIn.isNotEmpty) ...{
        'checkin': checkIn,
        'check_in': checkIn,
      },
      if (checkOut != null && checkOut.isNotEmpty) ...{
        'checkout': checkOut,
        'check_out': checkOut,
      },
      if (breakStart != null && breakStart.isNotEmpty) 'breakout': breakStart,
      if (breakEnd != null && breakEnd.isNotEmpty) 'breakin': breakEnd,
      'changes': changes.map((e) => e.toJson()).toList(),
    };
  }

  Future<int?> _resolveAttendanceId({
    required int? attendanceId,
    required int? userId,
    required String date,
    ApiCancelToken? cancelToken,
  }) async {
    if (attendanceId != null) return attendanceId;

    final query = <String, dynamic>{
      if (userId != null) 'user_id': userId,
      'date': date,
    };

    for (final path in [
      ManagerEmployeeApiEndpoints.teamAttendanceDetails,
      ManagerEmployeeApiEndpoints.teamAttendanceEdit,
    ]) {
      try {
        final response = await getRequest<int?>(
          path,
          queryParameters: query,
          cancelToken: cancelToken,
          parser: _parseAttendanceId,
        );
        if (response.success && response.data != null) return response.data;
      } catch (_) {}
    }

    return null;
  }

  int? _parseAttendanceId(dynamic json) {
    final data = _asMap(json) ?? const <String, dynamic>{};
    final inner = data['data'];
    final map = inner is Map
        ? Map<String, dynamic>.from(inner)
        : data['attendance'] is Map
        ? Map<String, dynamic>.from(data['attendance'] as Map)
        : data;
    final nested = map['attendance'];
    return _asIntOrNull(
      map['attendance_id'] ??
          (nested is Map ? nested['attendance_id'] ?? nested['id'] : null) ??
          map['id'],
    );
  }

  String _parseSaveMessage(dynamic json) {
    const fallback = 'Attendance updated.';
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      if (map['success'] == false) {
        throw ApiError(
          type: ApiErrorType.validation,
          message:
              (map['message'] as String?) ?? 'Failed to update attendance.',
        );
      }
      final message = (map['message'] as String?)?.trim();
      return (message != null && message.isNotEmpty) ? message : fallback;
    }
    return fallback;
  }

  bool _isRecordNotFound(ApiResponse<String> result) {
    if (result.success) return false;
    final message = (result.message ?? '').toLowerCase();
    return message.contains('not found') || result.statusCode == 404;
  }

  int? _asIntOrNull(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString().trim());
  }

  Map<String, dynamic>? _asMap(dynamic json) {
    if (json is Map) return Map<String, dynamic>.from(json);
    return null;
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
              (map['message'] as String?) ?? 'Failed to load team attendance.',
        );
      }

      final inner = map['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      if (inner is List) {
        return {'attendance': inner, 'total': inner.length};
      }

      if (fallbackKeys.any(map.containsKey)) return map;
    }

    if (json is List) return {'attendance': json, 'total': json.length};

    throw const FormatException('Unexpected team attendance response shape.');
  }
}
