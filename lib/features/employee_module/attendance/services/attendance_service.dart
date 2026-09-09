import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/employee_api_endpoints.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_details_data.dart';
import 'package:obecno/features/employee_module/attendance/data/models/employee_leave.dart';

class AttendanceChangeRequestPayload {
  const AttendanceChangeRequestPayload({
    this.attendanceDetailId,
    required this.oldValue,
    required this.newValue,
    this.type,
  });

  final String? attendanceDetailId;
  final String oldValue;
  final String newValue;
  final String? type;

  Map<String, dynamic> toJson() {
    final id = attendanceDetailId?.trim() ?? '';
    return {
      if (id.isNotEmpty) 'attendancedetail_id': int.tryParse(id) ?? id,
      if (type != null && type!.trim().isNotEmpty) 'type': type,
      'old_value': oldValue,
      'new_value': newValue,
    };
  }
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
      EmployeeApiEndpoints.attendance,
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
      EmployeeApiEndpoints.attendanceDetails,
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
            'id',
          ],
        );
        return AttendanceDetailsData.fromJson(data);
      },
    );
  }

  /// POST /employee/attendance/edit body. One request can include every
  /// changed punch for the day (check in, break, check out) in `changes`.
  ///
  /// For a day with no existing record (absent), pass [date] and clock
  /// times so the manager can approve new attendance rather than a fix.
  static Map<String, dynamic> editRequestBody({
    required int? attendanceId,
    required String deviceDetails,
    required double lat,
    required double lon,
    required List<AttendanceChangeRequestPayload> changes,
    String? date,
    String? checkIn,
    String? checkOut,
    String? breakStart,
    String? breakEnd,
  }) {
    final changesJson = changes.map((e) => e.toJson()).toList();
    return {
      if (attendanceId != null) 'id': attendanceId,
      if (date != null && date.isNotEmpty) 'date': date,
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
      'changes': changesJson,
      if (attendanceId == null && changesJson.isNotEmpty)
        'change_requests': changesJson,
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
    String? date,
    String? checkIn,
    String? checkOut,
    String? breakStart,
    String? breakEnd,
    ApiCancelToken? cancelToken,
  }) {
    return postRequest<String>(
      EmployeeApiEndpoints.attendanceEdit,
      cancelToken: cancelToken,
      data: editRequestBody(
        attendanceId: attendanceId,
        deviceDetails: deviceDetails,
        lat: lat,
        lon: lon,
        changes: changes,
        date: date,
        checkIn: checkIn,
        checkOut: checkOut,
        breakStart: breakStart,
        breakEnd: breakEnd,
      ),
      parser: _parseSubmitMessage,
    );
  }

  /// POST /employee/attendance for a day that has no record yet (absent).
  /// `/employee/attendance/edit` requires `id` and cannot create a new day.
  static Map<String, dynamic> createRequestBody({
    required String date,
    required String deviceDetails,
    required double lat,
    required double lon,
    String? checkIn,
    String? checkOut,
    String? breakStart,
    String? breakEnd,
    int? userId,
  }) {
    Map<String, dynamic> event(String type, String time) => {
      'type': type,
      'time': time,
    };

    final events = <Map<String, dynamic>>[
      if (checkIn != null && checkIn.isNotEmpty) event('checkin', checkIn),
      if (breakStart != null && breakStart.isNotEmpty)
        event('breakout', breakStart),
      if (breakEnd != null && breakEnd.isNotEmpty) event('breakin', breakEnd),
      if (checkOut != null && checkOut.isNotEmpty) event('checkout', checkOut),
    ];

    return {
      'date': date,
      'device_details': deviceDetails,
      'lat': lat,
      'lon': lon,
      if (userId != null) 'user_id': userId,
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
      if (events.isNotEmpty) 'events': events,
    };
  }

  Future<ApiResponse<String>> submitCreateAttendanceRequest({
    required String date,
    required String deviceDetails,
    required double lat,
    required double lon,
    String? checkIn,
    String? checkOut,
    String? breakStart,
    String? breakEnd,
    int? userId,
    ApiCancelToken? cancelToken,
  }) async {
    final created = await postRequest<String>(
      EmployeeApiEndpoints.attendance,
      cancelToken: cancelToken,
      data: createRequestBody(
        date: date,
        deviceDetails: deviceDetails,
        lat: lat,
        lon: lon,
        checkIn: checkIn,
        checkOut: checkOut,
        breakStart: breakStart,
        breakEnd: breakEnd,
        userId: userId,
      ),
      parser: _parseSubmitMessage,
    );
    if (created.success) return created;

    final punches = <Map<String, dynamic>>[
      if (checkIn != null && checkIn.isNotEmpty)
        {'action': 'checkin', 'datetime': '$date $checkIn'},
      if (breakStart != null && breakStart.isNotEmpty)
        {'action': 'breakout', 'datetime': '$date $breakStart'},
      if (breakEnd != null && breakEnd.isNotEmpty)
        {'action': 'breakin', 'datetime': '$date $breakEnd'},
      if (checkOut != null && checkOut.isNotEmpty)
        {'action': 'checkout', 'datetime': '$date $checkOut'},
    ];
    if (punches.isEmpty) return created;

    ApiResponse<String>? last;
    for (final punch in punches) {
      last = await postRequest<String>(
        EmployeeApiEndpoints.attendance,
        cancelToken: cancelToken,
        data: {
          ...punch,
          'device_details': deviceDetails,
          'lat': lat,
          'lon': lon,
          'date': date,
        },
        parser: _parseSubmitMessage,
      );
      if (!last.success) return last;
    }
    return last ?? created;
  }

  static String _parseSubmitMessage(dynamic json) {
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
              : 'Failed to submit attendance request.',
        );
      }
      return (message != null && message.isNotEmpty) ? message : fallback;
    }
    return fallback;
  }

  Future<ApiResponse<AttendanceCalendarData>> getCalendar({
    required String month,
    ApiCancelToken? cancelToken,
  }) {
    return getRequest<AttendanceCalendarData>(
      EmployeeApiEndpoints.attendanceCalendar,
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

  /// GET /employee/leaves — approved leave ranges for the signed-in employee.
  Future<ApiResponse<List<EmployeeLeave>>> getLeaves({
    String? dateFrom,
    String? dateTo,
    String? status,
    ApiCancelToken? cancelToken,
  }) {
    final query = <String, dynamic>{
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    return getRequest<List<EmployeeLeave>>(
      EmployeeApiEndpoints.employeeLeaves,
      queryParameters: query.isEmpty ? null : query,
      cancelToken: cancelToken,
      parser: EmployeeLeave.listFrom,
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
