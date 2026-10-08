import 'package:flutter/foundation.dart';
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
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';

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

  /// Creates an extra punch row even when one of this type already exists.
  ///
  /// Backends often store only HH:mm (seconds are dropped), so each extra
  /// mint of the same action must use a different minute or it upserts the
  /// previous row. Callers must mint punches in chronological / state-machine
  /// order (check-in → … → break-out → break-in → … → check-out) so a second
  /// breakout is accepted while the day is still checked in.
  Future<({String? detailId, String? hms, int? attendanceId})>
  mintAdditionalPunch({
    required String date,
    required String action,
    required String deviceDetails,
    required double lat,
    required double lon,
    Set<String> excludeDetailIds = const {},
    String? preferredTimeHms,
  }) async {
    final type = switch (action) {
      'checkout' => AttendanceHisotryEventType.checkOut,
      'breakout' => AttendanceHisotryEventType.breakStart,
      'breakin' => AttendanceHisotryEventType.breakEnd,
      _ => AttendanceHisotryEventType.checkIn,
    };

    Set<String> idsOfType(AttendanceDetailsData? data, AttendanceHisotryEventType t) {
      final ids = <String>{};
      if (data == null) return ids;
      for (final item in data.details) {
        if (item.type != t) continue;
        final id = AttendanceDetailItem.serverDetailId(item.id);
        if (id != null) ids.add(id);
      }
      return ids;
    }

    Set<String> allIds(AttendanceDetailsData? data) {
      final ids = <String>{};
      if (data == null) return ids;
      for (final item in data.details) {
        final id = AttendanceDetailItem.serverDetailId(item.id);
        if (id != null) ids.add(id);
      }
      return ids;
    }

    Set<String> placeholderHmsOfType(
      AttendanceDetailsData? data,
      AttendanceHisotryEventType t,
    ) {
      final times = <String>{};
      if (data == null) return times;
      for (final item in data.details) {
        if (item.type != t) continue;
        if (!AttendanceEditRequest.isPlaceholderMint(item.time)) continue;
        times.add(hmsFromDateTime(item.time));
      }
      return times;
    }

    Future<({String? detailId, String? hms, int? attendanceId})> attempt({
      required String mintAction,
      required AttendanceHisotryEventType mintType,
      required String timeHms,
    }) async {
      AttendanceDetailsData? before;
      try {
        before = (await getAttendanceDetails(date: date)).data;
      } catch (_) {}
      final beforeTyped = idsOfType(before, mintType);
      final beforeAll = allIds(before);

      await _mintPunch(
        date: date,
        action: mintAction,
        timeHms: timeHms,
        deviceDetails: deviceDetails,
        lat: lat,
        lon: lon,
      );

      AttendanceDetailsData? after;
      try {
        after = (await getAttendanceDetails(date: date)).data;
      } catch (_) {}
      final afterTyped = idsOfType(after, mintType);
      for (final id in afterTyped) {
        if (beforeTyped.contains(id)) continue;
        if (excludeDetailIds.contains(id)) continue;
        return (
          detailId: id,
          hms: timeHms,
          attendanceId: after?.attendanceId ?? before?.attendanceId,
        );
      }
      // Some backends stamp the new row with an unexpected type — still use it.
      for (final id in allIds(after)) {
        if (beforeAll.contains(id)) continue;
        if (excludeDetailIds.contains(id)) continue;
        return (
          detailId: id,
          hms: timeHms,
          attendanceId: after?.attendanceId ?? before?.attendanceId,
        );
      }
      return (
        detailId: null,
        hms: timeHms,
        attendanceId: after?.attendanceId ?? before?.attendanceId,
      );
    }

    AttendanceDetailsData? snapshot;
    try {
      snapshot = (await getAttendanceDetails(date: date)).data;
    } catch (_) {}

    final placeholder = _nextPlaceholderHms(
      action: action,
      used: placeholderHmsOfType(snapshot, type),
    );
    var result = await attempt(
      mintAction: action,
      mintType: type,
      timeHms: placeholder,
    );
    if (result.detailId != null) return result;

    final preferred = preferredTimeHms?.trim();
    if (preferred != null &&
        preferred.isNotEmpty &&
        preferred != placeholder) {
      debugPrint(
        '\x1B[31m[AttendanceRequest] mint $action placeholder failed; '
        'retry at preferred=$preferred\x1B[0m',
      );
      result = await attempt(
        mintAction: action,
        mintType: type,
        timeHms: preferred,
      );
    }
    return result;
  }

  /// Unique placeholder in 00:00–00:39 for [action].
  ///
  /// Backends often store only HH:mm (seconds are dropped), so each extra
  /// mint of the same action must use a different minute or it upserts the
  /// previous row and the change request is dropped.
  static String _nextPlaceholderHms({
    required String action,
    required Set<String> used,
  }) {
    String two(int n) => n.toString().padLeft(2, '0');
    // Normalize used keys to HH:mm:00 so :01 seconds still count as taken.
    final usedMinutes = <int>{};
    for (final hms in used) {
      final parts = hms.split(':');
      if (parts.length < 2) continue;
      final hour = int.tryParse(parts[0]) ?? -1;
      final minute = int.tryParse(parts[1]) ?? -1;
      if (hour == 0 && minute >= 0 && minute < 40) usedMinutes.add(minute);
    }

    final preferred = switch (action) {
      'checkout' => 3,
      'breakout' => 1,
      'breakin' => 2,
      _ => 0,
    };

    for (var step = 0; step < 40; step++) {
      final minute = (preferred + step * 4) % 40;
      if (usedMinutes.contains(minute)) continue;
      return '00:${two(minute)}:00';
    }
    for (var minute = 0; minute < 40; minute++) {
      if (usedMinutes.contains(minute)) continue;
      return '00:${two(minute)}:00';
    }
    return '00:${two(preferred)}:00';
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
    // Include rows without a detail id so extra break times still reach the
    // portal when minting a second breakout/breakin is impossible.
    final changeRequestsJson = [
      for (final item in changes) item.toChangeRequestJson(),
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

  /// GET /employee/company-calendar?month=YYYY-MM — public holidays for the month.
  Future<ApiResponse<List<HolidayInfo>>> getCompanyHolidays({
    required String month,
    ApiCancelToken? cancelToken,
  }) async {
    try {
      final raw = await apiClient.get(
        EmployeeApiEndpoints.companyCalendar,
        queryParameters: {'month': month},
        cancelToken: cancelToken,
      );
      if (raw.statusCode >= 400) {
        return ApiResponse.success(const [], statusCode: raw.statusCode);
      }
      final parsed = _parseCompanyHolidays(raw.data);
      return ApiResponse.success(parsed, statusCode: raw.statusCode);
    } on ApiError catch (e) {
      return ApiResponse.failure(
        e.message,
        statusCode: e.statusCode,
        fieldErrors: e.fieldErrors,
      );
    } catch (e) {
      return ApiResponse.failure(e.toString());
    }
  }

  List<HolidayInfo> _parseCompanyHolidays(dynamic json) {
    final holidays = <HolidayInfo>[];
    final seen = <String>{};

    void addHoliday(DateTime date, String name) {
      final dateOnly = DateTime(date.year, date.month, date.day);
      final key = '${dateOnly.year}-${dateOnly.month}-${dateOnly.day}';
      if (!seen.add(key)) return;
      final trimmed = name.trim();
      holidays.add(
        HolidayInfo(
          date: dateOnly,
          name: trimmed.isEmpty ? 'Public Holiday' : trimmed,
        ),
      );
    }

    void consumeItem(
      Map<String, dynamic> map, {
      required bool preferAsHoliday,
    }) {
      if (_isNonHolidayEvent(map)) return;

      // Nested events under a day cell (company calendar grid payloads).
      final nested =
          map['events'] ?? map['items'] ?? map['holidays'] ?? map['entries'];
      var consumedNestedHoliday = false;
      if (nested is List) {
        final dayDate = _parseFlexibleDate(
          map['date'] ??
              map['holiday_date'] ??
              map['day'] ??
              map['start_date'] ??
              map['from_date'],
        );
        for (final event in nested) {
          if (event is! Map) continue;
          final eventMap = Map<String, dynamic>.from(event);
          if (_isNonHolidayEvent(eventMap)) continue;
          final parsed =
              _parseFlexibleDate(
                eventMap['date'] ??
                    eventMap['holiday_date'] ??
                    eventMap['day'] ??
                    eventMap['start_date'] ??
                    eventMap['from_date'],
              ) ??
              dayDate;
          if (parsed == null) continue;
          final accept =
              _hasExplicitHolidayFlag(eventMap) ||
              (preferAsHoliday && _rawHolidayName(eventMap) != null);
          if (!accept) continue;
          addHoliday(parsed, _holidayNameOf(eventMap));
          consumedNestedHoliday = true;
        }
      }

      // Day wrappers with nested events should not also become a holiday row
      // unless they explicitly mark themselves as a holiday.
      if (consumedNestedHoliday && !_hasExplicitHolidayFlag(map)) return;

      if (!_looksLikePublicHoliday(map, preferAsHoliday: preferAsHoliday)) {
        return;
      }
      final parsed = _parseFlexibleDate(
        map['date'] ??
            map['holiday_date'] ??
            map['day'] ??
            map['start_date'] ??
            map['from_date'] ??
            map['start'],
      );
      if (parsed == null) return;
      addHoliday(parsed, _holidayNameOf(map));
    }

    void consumeList(dynamic list, {required bool preferAsHoliday}) {
      if (list is! List) return;
      for (final item in list) {
        if (item is! Map) continue;
        consumeItem(
          Map<String, dynamic>.from(item),
          preferAsHoliday: preferAsHoliday,
        );
      }
    }

    void consumeMapSource(Map<String, dynamic> source) {
      // Real employee company-calendar payload:
      // data.holiday_dates is either [] or a date-keyed map / list.
      final holidayDates = source['holiday_dates'] ?? source['holidayDates'];
      if (holidayDates is List) {
        for (final item in holidayDates) {
          if (item is Map) {
            consumeItem(
              Map<String, dynamic>.from(item),
              preferAsHoliday: true,
            );
            continue;
          }
          final parsed = _parseFlexibleDate(item);
          if (parsed == null) continue;
          addHoliday(parsed, 'Public Holiday');
        }
      } else if (holidayDates is Map) {
        Map<String, dynamic>.from(holidayDates).forEach((key, value) {
          final keyDate = _parseFlexibleDate(key);
          if (value is List) {
            for (final item in value) {
              if (item is Map) {
                final map = Map<String, dynamic>.from(item);
                if (keyDate != null && map['date'] == null) {
                  map['date'] = key;
                }
                consumeItem(map, preferAsHoliday: true);
              } else if (keyDate != null) {
                final name = value.toString().trim();
                addHoliday(
                  keyDate,
                  name.isEmpty ? 'Public Holiday' : name,
                );
              }
            }
          } else if (value is Map) {
            final map = Map<String, dynamic>.from(value);
            if (keyDate != null && map['date'] == null) {
              map['date'] = key;
            }
            consumeItem(map, preferAsHoliday: true);
          } else if (keyDate != null) {
            final name = (value ?? '').toString().trim();
            addHoliday(keyDate, name.isEmpty ? 'Public Holiday' : name);
          }
        });
      }

      final dedicated =
          source['holidays'] ??
          source['public_holidays'] ??
          source['publicHolidays'] ??
          source['company_holidays'] ??
          source['companyHolidays'];
      if (dedicated is List) {
        consumeList(dedicated, preferAsHoliday: true);
      }

      final mixed =
          source['events'] ??
          source['items'] ??
          source['days'] ??
          source['calendar'] ??
          source['entries'] ??
          source['weeks'];
      if (mixed is List) {
        // weeks[] may wrap day cells; also accept flat event lists.
        for (final item in mixed) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final nestedDays =
              map['days'] ?? map['events'] ?? map['items'] ?? map['entries'];
          if (nestedDays is List) {
            consumeList(nestedDays, preferAsHoliday: dedicated is! List);
          } else {
            consumeItem(map, preferAsHoliday: dedicated is! List);
          }
        }
      } else if (mixed is Map) {
        // Date-keyed map: { "2026-08-14": {...} } or { "2026-08-14": [...] }
        Map<String, dynamic>.from(mixed).forEach((key, value) {
          final keyDate = _parseFlexibleDate(key);
          if (value is List) {
            for (final item in value) {
              if (item is! Map) continue;
              final map = Map<String, dynamic>.from(item);
              if (keyDate != null && map['date'] == null) {
                map['date'] = key;
              }
              consumeItem(map, preferAsHoliday: true);
            }
          } else if (value is Map) {
            final map = Map<String, dynamic>.from(value);
            if (keyDate != null && map['date'] == null) {
              map['date'] = key;
            }
            consumeItem(map, preferAsHoliday: true);
          }
        });
      }
    }

    if (json is List) {
      consumeList(json, preferAsHoliday: true);
      return holidays;
    }

    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      final inner = map['data'];
      if (inner is List) {
        // Common API shape: { success, data: [ { date, name }, ... ] }
        consumeList(inner, preferAsHoliday: true);
      } else if (inner is Map) {
        consumeMapSource(Map<String, dynamic>.from(inner));
      }
      consumeMapSource(map);
    }

    return holidays;
  }

  String? _rawHolidayName(Map<String, dynamic> map) {
    final raw =
        map['name'] ??
        map['title'] ??
        map['label'] ??
        map['holiday_name'] ??
        map['holidayName'] ??
        map['event_name'] ??
        map['eventName'] ??
        map['holiday'];
    if (raw == null) return null;
    final trimmed = raw.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _holidayNameOf(Map<String, dynamic> map) {
    return _rawHolidayName(map) ?? 'Public Holiday';
  }

  bool _isNonHolidayEvent(Map<String, dynamic> map) {
    final type = (map['type'] ??
            map['event_type'] ??
            map['eventType'] ??
            map['category'] ??
            map['kind'] ??
            map['event'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    final status = (map['status'] ?? map['day_status'] ?? map['dayStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return type.contains('birthday') ||
        type.contains('leave') ||
        type.contains('weekend') ||
        status.contains('birthday') ||
        status.contains('leave') ||
        status.contains('weekend');
  }

  bool _hasExplicitHolidayFlag(Map<String, dynamic> map) {
    final type = (map['type'] ??
            map['event_type'] ??
            map['eventType'] ??
            map['category'] ??
            map['kind'] ??
            map['event'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    final status = (map['status'] ?? map['day_status'] ?? map['dayStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return map['is_holiday'] == true ||
        map['is_holiday'] == 1 ||
        map['is_holiday'] == '1' ||
        map['isHoliday'] == true ||
        map['isHoliday'] == 1 ||
        map['isHoliday'] == '1' ||
        type.contains('holiday') ||
        status == 'holiday' ||
        status == 'public_holiday' ||
        status == 'public-holiday';
  }

  bool _looksLikePublicHoliday(
    Map<String, dynamic> map, {
    required bool preferAsHoliday,
  }) {
    if (_isNonHolidayEvent(map)) return false;

    if (_hasExplicitHolidayFlag(map)) return true;

    // Bare holiday rows usually have a date + title and omit type. Do not
    // treat empty day shells (date only) as holidays.
    if (preferAsHoliday) {
      final hasDate =
          _parseFlexibleDate(
            map['date'] ??
                map['holiday_date'] ??
                map['day'] ??
                map['start_date'] ??
                map['from_date'] ??
                map['start'],
          ) !=
          null;
      return hasDate && _rawHolidayName(map) != null;
    }
    return false;
  }

  DateTime? _parseFlexibleDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) {
      return DateTime(raw.year, raw.month, raw.day);
    }
    if (raw is int) {
      // Seconds or milliseconds since epoch.
      final ms = raw > 9999999999 ? raw : raw * 1000;
      final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
      return DateTime(dt.year, dt.month, dt.day);
    }

    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    final iso = DateTime.tryParse(s);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    final dig = RegExp(r'^(\d{1,4})[\/\-.](\d{1,2})[\/\-.](\d{1,4})$');
    final m = dig.firstMatch(s);
    if (m != null) {
      final a = int.tryParse(m.group(1)!);
      final b = int.tryParse(m.group(2)!);
      final c = int.tryParse(m.group(3)!);
      if (a != null && b != null && c != null) {
        // YYYY-MM-DD vs DD-MM-YYYY
        if (a > 31) {
          return DateTime(a, b, c);
        }
        if (c > 31) {
          return DateTime(c, b, a);
        }
      }
    }

    const months = {
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };
    final named = RegExp(
      r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$|^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})$',
    ).firstMatch(s);
    if (named != null) {
      if (named.group(1) != null) {
        final day = int.tryParse(named.group(1)!);
        final month = months[named.group(2)!.toLowerCase()];
        final year = int.tryParse(named.group(3)!);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      } else {
        final month = months[named.group(4)!.toLowerCase()];
        final day = int.tryParse(named.group(5)!);
        final year = int.tryParse(named.group(6)!);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }

    return null;
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
