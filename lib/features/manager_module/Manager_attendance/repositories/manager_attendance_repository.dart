import 'package:flutter/foundation.dart';
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
    final query = {'date_from': dateFrom, 'date_to': dateTo, 'user_id': userId};

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

  Future<ApiResponse<ManagerEmployeeAttendanceData>> getEmployeeDayDetails({
    required int userId,
    required String date,
    ApiCancelToken? cancelToken,
  }) {
    return getRequest<ManagerEmployeeAttendanceData>(
      ManagerEmployeeApiEndpoints.employeeAttendanceDetails(userId),
      queryParameters: {'date': date, 'user_id': userId},
      cancelToken: cancelToken,
      parser: (json) {
        final data = _extractData(
          json,
          fallbackKeys: const [
            'attendance_details',
            'date',
            'attendance_id',
            'check_in',
            'checkin',
          ],
        );
        return ManagerEmployeeAttendanceData.fromJson({
          'employee': {
            'id': data['employee_id'] ?? userId,
            'name': data['employee_name'] ?? data['name'],
            'photo_url': data['photo_url'],
          },
          'history': [
            {
              'date': data['date'] ?? date,
              'attendance_id': data['attendance_id'] ?? data['id'],
              'id': data['attendance_id'] ?? data['id'],
              'checkin': data['check_in'] ?? data['checkin'],
              'checkout': data['check_out'] ?? data['checkout'],
              'hours_worked':
                  data['working_duration_label'] ?? data['hours_worked'],
              'current_location':
                  data['location_name'] ?? data['current_location'],
              'attendance_details': data['attendance_details'],
            },
          ],
        });
      },
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
  ///
  /// Spec §4.1: `PUT /manager/employees/{employee_id}/attendance` is the
  /// primary create/edit path. Team-attendance edit endpoints are fallbacks
  /// for older backends.
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
    String? checkInDetailId,
    String? checkOutDetailId,
    String? breakStartDetailId,
    String? breakEndDetailId,
    required List<AttendanceChangeRequestPayload> changes,
    ApiCancelToken? cancelToken,
  }) async {
    final resolvedId = await _resolveAttendanceId(
      attendanceId: attendanceId,
      userId: userId,
      date: date,
      cancelToken: cancelToken,
    );

    final employeeBody = employeeAttendanceSaveBody(
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
      checkInDetailId: checkInDetailId,
      checkOutDetailId: checkOutDetailId,
      breakStartDetailId: breakStartDetailId,
      breakEndDetailId: breakEndDetailId,
      changes: changes,
    );
    debugPrint(
      '[ManagerAttendance] SAVE userId=$userId attendanceId=$attendanceId '
      'resolvedId=$resolvedId date=$date '
      'in=$checkIn out=$checkOut break=$breakStart-$breakEnd '
      'inId=$checkInDetailId outId=$checkOutDetailId '
      'body=$employeeBody',
    );

    void logResult(String step, ApiResponse<String> result) {
      debugPrint(
        '[ManagerAttendance] SAVE $step success=${result.success} '
        'status=${result.statusCode} message=${result.message} '
        'data=${result.data}',
      );
    }

    // Primary: documented manager create/edit endpoint.
    if (userId != null) {
      final path = ManagerEmployeeApiEndpoints.employeeAttendance(userId);
      if (resolvedId == null) {
        var created = await postRequest<String>(
          path,
          cancelToken: cancelToken,
          data: employeeBody,
          parser: _parseSaveMessage,
        );
        logResult('POST $path', created);
        if (created.success) return created;

        created = await putRequest<String>(
          path,
          cancelToken: cancelToken,
          data: employeeBody,
          parser: _parseSaveMessage,
        );
        logResult('PUT $path', created);
        if (created.success) return created;
      } else {
        var primary = await putRequest<String>(
          path,
          cancelToken: cancelToken,
          data: employeeBody,
          parser: _parseSaveMessage,
        );
        logResult('PUT $path', primary);
        if (primary.success) return primary;

        primary = await postRequest<String>(
          path,
          cancelToken: cancelToken,
          data: employeeBody,
          parser: _parseSaveMessage,
        );
        logResult('POST $path', primary);
        if (primary.success) return primary;
      }
    }

    final legacyBody = editSaveBody(
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
      data: legacyBody,
      parser: _parseSaveMessage,
    );
    logResult('POST teamAttendanceEditSave', result);

    if (_isRecordNotFound(result) || !result.success) {
      result = await postRequest<String>(
        ManagerEmployeeApiEndpoints.teamAttendanceEdit,
        cancelToken: cancelToken,
        data: legacyBody,
        parser: _parseSaveMessage,
      );
      logResult('POST teamAttendanceEdit', result);
    }

    return result;
  }

  /// Body for `PUT/POST /manager/employees/{id}/attendance` (API §4.1).
  static Map<String, dynamic> employeeAttendanceSaveBody({
    required int? attendanceId,
    int? userId,
    required String date,
    required String deviceDetails,
    required double lat,
    required double lon,
    String? checkIn,
    String? checkOut,
    String? breakStart,
    String? breakEnd,
    String? checkInDetailId,
    String? checkOutDetailId,
    String? breakStartDetailId,
    String? breakEndDetailId,
    required List<AttendanceChangeRequestPayload> changes,
  }) {
    Map<String, dynamic> event(String type, String time, String? id) {
      final payload = <String, dynamic>{'type': type, 'time': time};
      final parsedId = int.tryParse((id ?? '').trim());
      if (parsedId != null) {
        payload['id'] = parsedId;
      } else if (id != null && id.trim().isNotEmpty) {
        payload['id'] = id.trim();
      }
      return payload;
    }

    final events = <Map<String, dynamic>>[
      if (checkIn != null && checkIn.isNotEmpty)
        event('checkin', checkIn, checkInDetailId),
      if (breakStart != null && breakStart.isNotEmpty)
        event('breakout', breakStart, breakStartDetailId),
      if (breakEnd != null && breakEnd.isNotEmpty)
        event('breakin', breakEnd, breakEndDetailId),
      if (checkOut != null && checkOut.isNotEmpty)
        event('checkout', checkOut, checkOutDetailId),
    ];

    return {
      'date': date,
      if (userId != null) 'user_id': userId,
      if (attendanceId != null) 'attendance_id': attendanceId,
      if (checkIn != null && checkIn.isNotEmpty) 'check_in': checkIn,
      if (checkOut != null && checkOut.isNotEmpty) 'check_out': checkOut,
      if (breakStart != null && breakStart.isNotEmpty) 'breakout': breakStart,
      if (breakEnd != null && breakEnd.isNotEmpty) 'breakin': breakEnd,
      if (events.isNotEmpty) 'events': events,
      if (changes.isNotEmpty)
        'changes': changes.map((e) => e.toJson()).toList(),
    };
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
    if (userId == null) return null;

    try {
      final existing = await getEmployeeAttendance(
        userId: userId,
        dateFrom: date,
        dateTo: date,
        cancelToken: cancelToken,
      );
      if (existing.success && existing.data != null) {
        for (final day in existing.data!.history) {
          final dayDate = day.date;
          if (dayDate == null) continue;
          final key =
              '${dayDate.year.toString().padLeft(4, '0')}-'
              '${dayDate.month.toString().padLeft(2, '0')}-'
              '${dayDate.day.toString().padLeft(2, '0')}';
          if (key == date && day.id != null) return day.id;
        }
      }
    } catch (_) {}

    return null;
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
