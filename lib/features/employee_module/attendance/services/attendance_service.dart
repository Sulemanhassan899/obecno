import 'package:Obecno/core/api/api_cancel_token.dart';
import 'package:Obecno/core/api/api_endpoints.dart';
import 'package:Obecno/core/api/api_response.dart';
import 'package:Obecno/core/api/base_repository.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendance_day.dart';

/// Data-source layer for the attendance module.
///
/// Owns exactly two responsibilities:
///  1. Call the two attendance endpoints through the existing (http-based)
///     [ApiClient] via [BaseRepository].
///  2. Safely parse the raw JSON envelope into [AttendanceHistoryData] /
///     [AttendanceCalendarData], throwing a [FormatException] on anything
///     unexpected so [BaseRepository] converts it into a typed
///     `ApiError(type: ApiErrorType.parsing, ...)` instead of crashing.
///
/// No business rules (late thresholds, absents, sorting) live here — that's
/// [AttendanceRepository]'s job. This class never touches UI models.
class AttendanceService extends BaseRepository {
  AttendanceService(super.apiClient);

  /// `GET /api/employee/attendance?date_from=&date_to=`
  ///
  /// Both query params are optional (per the Swagger doc) — pass null/empty
  /// to fetch the server's default range.
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

  /// `GET /api/employee/calendar?month=YYYY-MM`
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

  /// Both endpoints wrap their payload as `{"data": {...}}`, but the
  /// calendar sample in the API doc omits a top-level `"success"` key, so
  /// this stays defensive rather than assuming one exact shape:
  ///  - if `json['data']` is a map, use it
  ///  - else, if `json` itself already looks like the payload
  ///    (contains one of [fallbackKeys]), use `json` directly
  ///  - otherwise, throw so the caller surfaces a parsing error
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
