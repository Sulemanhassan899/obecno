import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_endpoints.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_details_data.dart';

class AttendanceChangeRequestPayload {
  const AttendanceChangeRequestPayload({
    required this.attendanceDetailId,
    required this.oldValue,
    required this.newValue,
  });

  final String attendanceDetailId;
  final String oldValue;
  final String newValue;

  Map<String, dynamic> toJson() => {
    'attendancedetail_id':
        int.tryParse(attendanceDetailId) ?? attendanceDetailId,
    'old_value': oldValue,
    'new_value': newValue,
  };
}

class AttendanceService extends BaseRepository {
  AttendanceService(super.apiClient);

  Future<ApiResponse<AttendanceHistoryData>> getAttendance({
    String? dateFrom,
    String? dateTo,
    ApiCancelToken? cancelToken,
  }) {
    final query = <String, dynamic>{
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
    };

    return getRequest<AttendanceHistoryData>(
      ApiEndpoints.attendance,
      queryParameters: query.isEmpty ? null : query,
      cancelToken: cancelToken,
      parser: (json) {
        final data = _extractData(
          json,
          fallbackKeys: const ['today', 'today_attendance', 'history'],
        );
        return AttendanceHistoryData.fromJson(data);
      },
    );
  }

  /// GET /employee/attendance/details?date=YYYY-MM-DD
  ///
  /// Returns the full per-event timeline for a day, including
  /// `change_requests` / `changes` used by the edit-history UI.
  Future<ApiResponse<AttendanceDetailsData>> getAttendanceDetails({
    required String date,
    ApiCancelToken? cancelToken,
  }) {
    return getRequest<AttendanceDetailsData>(
      ApiEndpoints.attendanceDetails,
      queryParameters: {'date': date},
      cancelToken: cancelToken,
      parser: (json) {
        final data = _extractData(
          json,
          fallbackKeys: const [
            'attendance_details',
            'date',
            'attendance_id',
            'user_id',
          ],
        );
        return AttendanceDetailsData.fromJson(data);
      },
    );
  }

  /// POST /employee/attendance/edit body. One request can include every
  /// changed punch for the day (check in, break, check out) in `changes`.
  static Map<String, dynamic> editRequestBody({
    required int? attendanceId,
    required String deviceDetails,
    required double lat,
    required double lon,
    required List<AttendanceChangeRequestPayload> changes,
  }) {
    return {
      'id': attendanceId,
      'device_details': deviceDetails,
      'lat': lat,
      'lon': lon,
      'changes': changes.map((e) => e.toJson()).toList(),
    };
  }

  /// POST /employee/attendance/edit
  ///
  /// Submits one or more attendance time fix requests. Returns the
  /// server message (e.g. pending-approval confirmation).
  Future<ApiResponse<String>> submitAttendanceChangeRequests({
    required int? attendanceId,
    required String deviceDetails,
    required double lat,
    required double lon,
    required List<AttendanceChangeRequestPayload> changes,
    ApiCancelToken? cancelToken,
  }) {
    return postRequest<String>(
      ApiEndpoints.attendanceEdit,
      cancelToken: cancelToken,
      data: editRequestBody(
        attendanceId: attendanceId,
        deviceDetails: deviceDetails,
        lat: lat,
        lon: lon,
        changes: changes,
      ),
      parser: (json) {
        const fallback =
            'Your change request was submitted and is pending approval.';
        if (json is Map) {
          final map = Map<String, dynamic>.from(json);
          final success = map['success'] != false;
          final message = (map['message'] as String?)?.trim();
          if (!success) {
            throw ApiError(
              type: ApiErrorType.validation,
              message: (message != null && message.isNotEmpty)
                  ? message
                  : 'Failed to submit attendance fix request.',
            );
          }
          return (message != null && message.isNotEmpty) ? message : fallback;
        }
        return fallback;
      },
    );
  }

  Future<ApiResponse<AttendanceCalendarData>> getCalendar({
    required String month,
    ApiCancelToken? cancelToken,
  }) {
    return getRequest<AttendanceCalendarData>(
      ApiEndpoints.attendanceCalendar,
      queryParameters: {'month': month},
      cancelToken: cancelToken,
      parser: (json) {
        final data = _extractData(
          json,
          fallbackKeys: const ['month_label', 'attendance_dates'],
        );
        return AttendanceCalendarData.fromJson(data);
      },
    );
  }

  Map<String, dynamic> _extractData(
    dynamic json, {
    required List<String> fallbackKeys,
  }) {
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);

      final inner = map['data'];
      if (inner is Map) {
        return Map<String, dynamic>.from(inner);
      }

      if (fallbackKeys.any(map.containsKey)) {
        return map;
      }
    }

    throw const FormatException('Unexpected attendance response shape.');
  }
}
