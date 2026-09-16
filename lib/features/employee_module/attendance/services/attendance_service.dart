import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/employee_api_endpoints.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_details_data.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
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

  /// API time fields must be 24-hour `HH:mm:ss`. `--` is not a valid time.
  static String asHms(String raw) {
    final parsed = AttendanceEditRequest.parseClockTime(
      raw,
      date: DateTime(2000, 1, 1),
    );
    if (parsed == null) return '00:00:00';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(parsed.hour)}:${two(parsed.minute)}:${two(parsed.second)}';
  }

  int? get parsedDetailId {
    final id = attendanceDetailId?.trim() ?? '';
    if (id.isEmpty) return null;
    return int.tryParse(id);
  }

  bool get hasDetailId => parsedDetailId != null;

  String? get _typeOrNull {
    final value = type?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  /// Backend `changes[]` is strict: detail id + 24-hour old/new. Extra keys
  /// (including a row-level `id`) make Laravel reject the whole array.
  Map<String, dynamic> toChangesJson() {
    final parsedId = parsedDetailId;
    return {
      if (parsedId != null) 'attendancedetail_id': parsedId,
      'old_value': asHms(oldValue),
      'new_value': asHms(newValue),
    };
  }

  /// Spec `change_requests` rows.
  Map<String, dynamic> toChangeRequestJson() {
    final parsedId = parsedDetailId;
    return {
      if (parsedId != null) 'attendance_detail_id': parsedId,
      if (_typeOrNull != null) 'type': _typeOrNull,
      'original_time': asHms(oldValue),
      'requested_time': asHms(newValue),
    };
  }

  Map<String, dynamic> toJson() => {
    ...toChangesJson(),
    ...toChangeRequestJson(),
  };
}

class AttendancePunchSnapshot {
  const AttendancePunchSnapshot({
    this.attendanceId,
    this.checkInId,
    this.checkOutId,
    this.breakStartId,
    this.breakEndId,
    this.checkInHms,
    this.checkOutHms,
    this.breakStartHms,
    this.breakEndHms,
  });

  final int? attendanceId;
  final String? checkInId;
  final String? checkOutId;
  final String? breakStartId;
  final String? breakEndId;
  final String? checkInHms;
  final String? checkOutHms;
  final String? breakStartHms;
  final String? breakEndHms;

  String? idFor(String eventType) {
    switch (eventType) {
      case 'checkOut':
        return checkOutId;
      case 'breakStart':
        return breakStartId;
      case 'breakEnd':
        return breakEndId;
      default:
        return checkInId;
    }
  }

  String? hmsFor(String eventType) {
    switch (eventType) {
      case 'checkOut':
        return checkOutHms;
      case 'breakStart':
        return breakStartHms;
      case 'breakEnd':
        return breakEndHms;
      default:
        return checkInHms;
    }
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
        if (json is Map) {
          final map = Map<String, dynamic>.from(json);
          final inner = map['data'];
          if (inner is List) {
            return AttendanceHistoryData.fromJson({'history': inner});
          }
        }
        final data = _extractData(
          json,
          fallbackKeys: const [
            'today',
            'today_attendance',
            'history',
            'attendances',
            'records',
            'days',
          ],
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

  static int? parseAttendanceId(dynamic json) {
    int? asInt(dynamic raw) {
      if (raw == null) return null;
      if (raw is int) return raw;
      if (raw is double && raw == raw.roundToDouble()) return raw.toInt();
      return int.tryParse(raw.toString()) ??
          double.tryParse(raw.toString())?.round();
    }

    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final named = asInt(map['attendance_id']) ?? asInt(map['attendanceId']);
    if (named != null) return named;

    for (final key in const ['data', 'attendance']) {
      final nested = map[key];
      if (nested is Map) {
        final parsed = parseAttendanceId(nested);
        if (parsed != null) return parsed;
      }
    }
    return asInt(map['id']);
  }

  static String hmsFromDateTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  Future<AttendancePunchSnapshot> loadPunchSnapshot(String date) async {
    String? idFor(
      AttendanceDetailsData? data,
      AttendanceHisotryEventType type,
    ) {
      if (data == null) return null;
      for (final item in data.details) {
        if (item.type == type) {
          return AttendanceDetailItem.serverDetailId(item.id);
        }
      }
      return null;
    }

    String? hmsFor(
      AttendanceDetailsData? data,
      AttendanceHisotryEventType type,
    ) {
      if (data == null) return null;
      for (final item in data.details) {
        if (item.type == type) return hmsFromDateTime(item.time);
      }
      return null;
    }

    try {
      final response = await getAttendanceDetails(date: date);
      final data = response.data;
      return AttendancePunchSnapshot(
        attendanceId: data?.attendanceId,
        checkInId: idFor(data, AttendanceHisotryEventType.checkIn),
        checkOutId: idFor(data, AttendanceHisotryEventType.checkOut),
        breakStartId: idFor(data, AttendanceHisotryEventType.breakStart),
        breakEndId: idFor(data, AttendanceHisotryEventType.breakEnd),
        checkInHms: hmsFor(data, AttendanceHisotryEventType.checkIn),
        checkOutHms: hmsFor(data, AttendanceHisotryEventType.checkOut),
        breakStartHms: hmsFor(data, AttendanceHisotryEventType.breakStart),
        breakEndHms: hmsFor(data, AttendanceHisotryEventType.breakEnd),
      );
    } catch (_) {
      return const AttendancePunchSnapshot();
    }
  }

  Future<void> _mintPunch({
    required String date,
    required String action,
    required String timeHms,
    required String deviceDetails,
    required double lat,
    required double lon,
  }) async {
    await postRequest<int?>(
      EmployeeApiEndpoints.attendance,
      data: {
        'action': action,
        'datetime': '$date $timeHms',
        'date': date,
        'device_details': deviceDetails,
        'lat': lat,
        'lon': lon,
      },
      parser: parseAttendanceId,
    );
  }

  /// `/employee/attendance/edit` requires a root `id` and every `changes`
  /// row needs `attendancedetail_id`. Absent days mint placeholder punches
  /// (not the requested times) so the edit request can be submitted.
  Future<AttendancePunchSnapshot> ensureAttendanceRecord({
    required String date,
    required String deviceDetails,
    required double lat,
    required double lon,
    int? attendanceId,
    List<String> mintActions = const [],
  }) async {
    var resolved = await loadPunchSnapshot(date);
    if (attendanceId == null && resolved.attendanceId == null) {
      await postRequest<int?>(
        EmployeeApiEndpoints.attendance,
        data: {
          'date': date,
          'device_details': deviceDetails,
          'lat': lat,
          'lon': lon,
        },
        parser: parseAttendanceId,
      );
      resolved = await loadPunchSnapshot(date);
    }

    const placeholders = <String, String>{
      'checkin': '00:00:00',
      'breakout': '00:01:00',
      'breakin': '00:02:00',
      'checkout': '00:03:00',
    };
    String? existingId(String action) {
      switch (action) {
        case 'checkout':
          return resolved.checkOutId;
        case 'breakout':
          return resolved.breakStartId;
        case 'breakin':
          return resolved.breakEndId;
        default:
          return resolved.checkInId;
      }
    }

    for (final action in ['checkin', 'breakout', 'breakin', 'checkout']) {
      if (!mintActions.contains(action)) continue;
      if (existingId(action) != null) continue;
      await _mintPunch(
        date: date,
        action: action,
        timeHms: placeholders[action]!,
        deviceDetails: deviceDetails,
        lat: lat,
        lon: lon,
      );
      resolved = await loadPunchSnapshot(date);
    }

    if (resolved.attendanceId != null || mintActions.isEmpty) {
      return AttendancePunchSnapshot(
        attendanceId: attendanceId ?? resolved.attendanceId,
        checkInId: resolved.checkInId,
        checkOutId: resolved.checkOutId,
        breakStartId: resolved.breakStartId,
        breakEndId: resolved.breakEndId,
        checkInHms: resolved.checkInHms,
        checkOutHms: resolved.checkOutHms,
        breakStartHms: resolved.breakStartHms,
        breakEndHms: resolved.breakEndHms,
      );
    }

    await _mintPunch(
      date: date,
      action: 'checkin',
      timeHms: '00:00:00',
      deviceDetails: deviceDetails,
      lat: lat,
      lon: lon,
    );
    resolved = await loadPunchSnapshot(date);
    return AttendancePunchSnapshot(
      attendanceId: attendanceId ?? resolved.attendanceId,
      checkInId: resolved.checkInId,
      checkOutId: resolved.checkOutId,
      breakStartId: resolved.breakStartId,
      breakEndId: resolved.breakEndId,
      checkInHms: resolved.checkInHms,
      checkOutHms: resolved.checkOutHms,
      breakStartHms: resolved.breakStartHms,
      breakEndHms: resolved.breakEndHms,
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
    final changesJson = [
      for (final item in changes)
        if (item.hasDetailId) item.toChangesJson(),
    ];
    final changeRequestsJson = [
      for (final item in changes)
        if (item.hasDetailId) item.toChangeRequestJson(),
    ];
    return {
      if (attendanceId != null) 'id': attendanceId,
      if (attendanceId != null) 'attendance_id': attendanceId,
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
      if (changeRequestsJson.isNotEmpty) 'change_requests': changeRequestsJson,
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
