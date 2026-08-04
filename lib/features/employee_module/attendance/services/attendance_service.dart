import 'package:Obecno/core/api/api_cancel_token.dart';
import 'package:Obecno/core/api/api_endpoints.dart';
import 'package:Obecno/core/api/api_response.dart';
import 'package:Obecno/core/api/base_repository.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendance_day.dart';

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
