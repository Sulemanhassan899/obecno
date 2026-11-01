import 'package:flutter/foundation.dart';
import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/api/base_repository.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/features/employee_module/attendance/services/attendance_service.dart';
import 'package:obecno/features/employee_module/attendance/services/day_classification_engine.dart';
import 'package:obecno/features/manager_module/Manager_attendance/data/models/manager_employee_attendance_model.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';

class ManagerAttendanceRepository extends BaseRepository {
  ManagerAttendanceRepository(super.apiClient);

  Future<ApiResponse<List<HolidayInfo>>> getCompanyHolidays({
    required String month,
    ApiCancelToken? cancelToken,
  }) {
    return AttendanceService(apiClient).getCompanyHolidays(
      month: month,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<ManagerTeamAttendanceData>> getTeamAttendance({
    String? date,
    String? filter,
    String? search,
    String? locationId,
    int page = 1,
    int pageSize = 200,
    ApiCancelToken? cancelToken,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      if (date != null && date.isNotEmpty) 'date': date,
      if (filter != null && filter.isNotEmpty && filter != 'all')
        'filter': filter,
      if (search != null && search.isNotEmpty) 'search': search,
      if (locationId != null && locationId.isNotEmpty && locationId != 'all')
        'location_id': locationId,
    };

    return getRequest<ManagerTeamAttendanceData>(
      ManagerEmployeeApiEndpoints.teamAttendance,
      queryParameters: query,
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
              'is_open': data['is_open'] ?? data['live_status'] == 'working',
              'location_id': data['location_id'],
              'location_name': data['location_name'],
              'hours_worked':
                  data['working_duration_label'] ?? data['hours_worked'],
              'current_location':
                  data['location_name'] ?? data['current_location'],
              'attendance_details':
                  data['attendance_details'] ?? data['details'],
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

  /// Creates a missing punch detail for [userId] on [date] (manager path).
  ///
  /// Open-shift checkout has no `attendancedetail_id` yet; PUT with only
  /// top-level `check_out` often returns success without persisting. Mint a
  /// real detail first (same idea as employee `ensureAttendanceRecord`), then
  /// the caller can PUT/update that id to the requested time.
  Future<({String? detailId, String? hms, int? attendanceId})>
  mintEmployeePunch({
    required int userId,
    required String date,
    required String action,
    required String deviceDetails,
    required double lat,
    required double lon,
    int? attendanceId,
    String? preferredTimeHms,
    Set<String> excludeDetailIds = const {},
    ApiCancelToken? cancelToken,
  }) async {
    final typeKey = _normalizePunchAction(action);
    final timeHms =
        (preferredTimeHms != null && preferredTimeHms.trim().isNotEmpty)
        ? preferredTimeHms.trim()
        : _placeholderHmsFor(typeKey);

    Future<({Set<String> typed, Set<String> all, int? attendanceId})>
    snapshot() async {
      final typed = <String>{};
      final all = <String>{};
      int? id = attendanceId;
      try {
        final response = await getEmployeeDayDetails(
          userId: userId,
          date: date,
          cancelToken: cancelToken,
        );
        final day = response.data?.history.isNotEmpty == true
            ? response.data!.history.first
            : null;
        id ??= day?.id;
        for (final detail in day?.details ?? const <ManagerEmployeeAttendanceDetail>[]) {
          final detailId = detail.id?.toString();
          if (detailId == null || detailId.isEmpty) continue;
          all.add(detailId);
          if (_detailMatchesAction(detail.type, typeKey)) {
            typed.add(detailId);
          }
        }
      } catch (_) {}
      return (typed: typed, all: all, attendanceId: id);
    }

    final before = await snapshot();
    for (final id in before.typed) {
      if (!excludeDetailIds.contains(id)) {
        return (
          detailId: id,
          hms: timeHms,
          attendanceId: before.attendanceId,
        );
      }
    }

    final path = ManagerEmployeeApiEndpoints.employeeAttendance(userId);
    final resolvedAttendanceId = before.attendanceId ?? attendanceId;

    // 1) Action-style punch (mirrors employee mint).
    try {
      await postRequest<String>(
        path,
        cancelToken: cancelToken,
        data: {
          'action': typeKey,
          'datetime': '$date $timeHms',
          'date': date,
          'device_details': deviceDetails,
          'lat': lat,
          'lon': lon,
          'user_id': userId,
          if (resolvedAttendanceId != null)
            'attendance_id': resolvedAttendanceId,
        },
        parser: _parseSaveMessage,
      );
    } catch (_) {}

    var after = await snapshot();
    String? findNew(Set<String> beforeSet, Set<String> afterSet) {
      for (final id in afterSet) {
        if (beforeSet.contains(id)) continue;
        if (excludeDetailIds.contains(id)) continue;
        return id;
      }
      return null;
    }

    var minted = findNew(before.typed, after.typed) ??
        findNew(before.all, after.all);
    if (minted != null) {
      return (
        detailId: minted,
        hms: timeHms,
        attendanceId: after.attendanceId ?? resolvedAttendanceId,
      );
    }

    // 2) Fallback: events[] without id (create row via §4.1 body).
    final eventType = switch (typeKey) {
      'checkout' => 'checkout',
      'breakout' => 'breakout',
      'breakin' => 'breakin',
      _ => 'checkin',
    };
    final body = <String, dynamic>{
      'date': date,
      'user_id': userId,
      if (resolvedAttendanceId != null) 'attendance_id': resolvedAttendanceId,
      'device_details': deviceDetails,
      'lat': lat,
      'lon': lon,
      'events': [
        {'type': eventType, 'time': timeHms},
      ],
      if (typeKey == 'checkout') 'check_out': timeHms,
      if (typeKey == 'checkin') 'check_in': timeHms,
      if (typeKey == 'breakout') 'breakout': timeHms,
      if (typeKey == 'breakin') 'breakin': timeHms,
    };
    try {
      await putRequest<String>(
        path,
        cancelToken: cancelToken,
        data: body,
        parser: _parseSaveMessage,
      );
    } catch (_) {
      try {
        await postRequest<String>(
          path,
          cancelToken: cancelToken,
          data: body,
          parser: _parseSaveMessage,
        );
      } catch (_) {}
    }

    after = await snapshot();
    minted = findNew(before.typed, after.typed) ??
        findNew(before.all, after.all);
    // Backend may upsert an existing typed row instead of inserting.
    if (minted == null) {
      for (final id in after.typed) {
        if (excludeDetailIds.contains(id)) continue;
        minted = id;
        break;
      }
    }

    return (
      detailId: minted,
      hms: timeHms,
      attendanceId: after.attendanceId ?? resolvedAttendanceId,
    );
  }

  static String _normalizePunchAction(String action) {
    switch (action.trim().toLowerCase()) {
      case 'check out':
      case 'checkout':
      case 'check-out':
      case 'check_out':
        return 'checkout';
      case 'break out':
      case 'breakout':
      case 'break start':
        return 'breakout';
      case 'break in':
      case 'breakin':
      case 'break end':
        return 'breakin';
      default:
        return 'checkin';
    }
  }

  static bool _detailMatchesAction(String rawType, String action) {
    final t = rawType.trim().toLowerCase();
    switch (action) {
      case 'checkout':
        return t.contains('check out') ||
            t == 'checkout' ||
            t == 'check-out' ||
            t == 'check_out';
      case 'breakout':
        return t.contains('break out') ||
            t == 'breakout' ||
            t.contains('break start');
      case 'breakin':
        return t.contains('break in') ||
            t == 'breakin' ||
            t.contains('break end');
      default:
        return t.contains('check in') ||
            t == 'checkin' ||
            t == 'check-in' ||
            t == 'check_in';
    }
  }

  static String _placeholderHmsFor(String action) {
    switch (action) {
      case 'checkout':
        return '00:03:00';
      case 'breakout':
        return '00:01:00';
      case 'breakin':
        return '00:02:00';
      default:
        return '00:00:00';
    }
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
    List<Map<String, dynamic>> additionalEvents = const [],
    required List<AttendanceChangeRequestPayload> changes,
    ApiCancelToken? cancelToken,
  }) async {
    final resolvedId = await _resolveAttendanceId(
      attendanceId: attendanceId,
      userId: userId,
      date: date,
      cancelToken: cancelToken,
    );

    final closingOpenShift =
        userId != null &&
        resolvedId != null &&
        checkOut != null &&
        checkOut.isNotEmpty &&
        (checkOutDetailId == null || checkOutDetailId.trim().isEmpty);

    if (closingOpenShift) {
      return _closeEmployeeOpenShift(
        userId: userId,
        attendanceId: resolvedId,
        date: date,
        checkIn: checkIn,
        checkOut: checkOut,
        checkInDetailId: checkInDetailId,
        breakStart: breakStart,
        breakEnd: breakEnd,
        deviceDetails: deviceDetails,
        lat: lat,
        lon: lon,
        cancelToken: cancelToken,
      );
    }

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
      additionalEvents: additionalEvents,
      changes: changes,
    );

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
        if (created.success) return created;

        created = await putRequest<String>(
          path,
          cancelToken: cancelToken,
          data: employeeBody,
          parser: _parseSaveMessage,
        );
        if (created.success) return created;
      } else {
        var primary = await putRequest<String>(
          path,
          cancelToken: cancelToken,
          data: employeeBody,
          parser: _parseSaveMessage,
        );
        if (primary.success) return primary;

        primary = await postRequest<String>(
          path,
          cancelToken: cancelToken,
          data: employeeBody,
          parser: _parseSaveMessage,
        );
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

    if (_isRecordNotFound(result) || !result.success) {
      result = await postRequest<String>(
        ManagerEmployeeApiEndpoints.teamAttendanceEdit,
        cancelToken: cancelToken,
        data: legacyBody,
        parser: _parseSaveMessage,
      );
    }

    return result;
  }

  /// Closes an open shift by trying every §4.1-compatible body the backend
  /// has been seen to accept. Stops at the first attempt that actually leaves
  /// a checkout on the employee day (verified via details GET / save body).
  Future<ApiResponse<String>> _closeEmployeeOpenShift({
    required int userId,
    required int attendanceId,
    required String date,
    required String checkOut,
    required String deviceDetails,
    required double lat,
    required double lon,
    String? checkIn,
    String? checkInDetailId,
    String? breakStart,
    String? breakEnd,
    ApiCancelToken? cancelToken,
  }) async {
    String? locationId;
    try {
      final existing = await getEmployeeDayDetails(
        userId: userId,
        date: date,
        cancelToken: cancelToken,
      );
      locationId = existing.data?.history.isNotEmpty == true
          ? existing.data!.history.first.locationId
          : null;
    } catch (_) {}

    Object? checkInEventId;
    final parsedCheckInId = int.tryParse((checkInDetailId ?? '').trim());
    if (parsedCheckInId != null) {
      checkInEventId = parsedCheckInId;
    } else if (checkInDetailId != null && checkInDetailId.trim().isNotEmpty) {
      checkInEventId = checkInDetailId.trim();
    }

    final attempts = <({String label, Map<String, dynamic> body})>[
      (
        label: 'simple+location',
        body: {
          'date': date,
          'user_id': userId,
          'attendance_id': attendanceId,
          if (locationId != null && locationId.isNotEmpty)
            'location_id': locationId,
          if (checkIn != null && checkIn.isNotEmpty) 'check_in': checkIn,
          'check_out': checkOut,
          'is_open': false,
          if (breakStart != null && breakStart.isNotEmpty) 'breakout': breakStart,
          if (breakEnd != null && breakEnd.isNotEmpty) 'breakin': breakEnd,
          'reason': 'Manager closed open shift',
        },
      ),
      (
        label: 'aliases',
        body: {
          'date': date,
          'user_id': userId,
          'attendance_id': attendanceId,
          if (locationId != null && locationId.isNotEmpty)
            'location_id': locationId,
          if (checkIn != null && checkIn.isNotEmpty) ...{
            'check_in': checkIn,
            'checkin': checkIn,
          },
          'check_out': checkOut,
          'checkout': checkOut,
          'is_open': false,
        },
      ),
      (
        label: 'events+checkout',
        body: {
          'date': date,
          'user_id': userId,
          'attendance_id': attendanceId,
          if (locationId != null && locationId.isNotEmpty)
            'location_id': locationId,
          if (checkIn != null && checkIn.isNotEmpty) 'check_in': checkIn,
          'check_out': checkOut,
          'is_open': false,
          'events': [
            if (checkIn != null &&
                checkIn.isNotEmpty &&
                checkInEventId != null)
              {'id': checkInEventId, 'type': 'checkin', 'time': checkIn},
            {'type': 'checkout', 'time': checkOut},
          ],
        },
      ),
      (
        label: 'events spaced types',
        body: {
          'date': date,
          'user_id': userId,
          'attendance_id': attendanceId,
          if (locationId != null && locationId.isNotEmpty)
            'location_id': locationId,
          if (checkIn != null && checkIn.isNotEmpty) 'check_in': checkIn,
          'check_out': checkOut,
          'is_open': false,
          'events': [
            if (checkIn != null &&
                checkIn.isNotEmpty &&
                checkInEventId != null)
              {'id': checkInEventId, 'type': 'check in', 'time': checkIn},
            {'type': 'check out', 'time': checkOut},
          ],
        },
      ),
      (
        label: 'attendance_details',
        body: {
          'date': date,
          'user_id': userId,
          'attendance_id': attendanceId,
          if (locationId != null && locationId.isNotEmpty)
            'location_id': locationId,
          if (checkIn != null && checkIn.isNotEmpty) 'check_in': checkIn,
          'check_out': checkOut,
          'is_open': false,
          'attendance_details': [
            if (checkIn != null && checkIn.isNotEmpty)
              {
                if (checkInEventId != null) 'id': checkInEventId,
                'type': 'checkin',
                'attendance_time': checkIn,
              },
            {'type': 'checkout', 'attendance_time': checkOut},
          ],
        },
      ),
      (
        label: 'legacy edit/save',
        body: {
          'id': attendanceId,
          'attendance_id': attendanceId,
          'user_id': userId,
          'date': date,
          'device_details': deviceDetails,
          'lat': lat,
          'lon': lon,
          if (checkIn != null && checkIn.isNotEmpty) ...{
            'checkin': checkIn,
            'check_in': checkIn,
          },
          'checkout': checkOut,
          'check_out': checkOut,
          'is_open': false,
          'changes': <Map<String, dynamic>>[],
        },
      ),
    ];

    final path = ManagerEmployeeApiEndpoints.employeeAttendance(userId);
    ApiResponse<String>? last;

    for (final attempt in attempts) {
      final targets = attempt.label.startsWith('legacy')
          ? <({String method, String path})>[
              (
                method: 'POST',
                path: ManagerEmployeeApiEndpoints.teamAttendanceEditSave,
              ),
              (
                method: 'POST',
                path: ManagerEmployeeApiEndpoints.teamAttendanceEdit,
              ),
            ]
          : <({String method, String path})>[
              (method: 'PUT', path: path),
              (method: 'POST', path: path),
            ];

      for (final target in targets) {
        debugPrint(
          '\x1B[31m[ManagerAttendance] close-open '
          '${target.method} ${attempt.label} body=${attempt.body}\x1B[0m',
        );
        final result = target.method == 'PUT'
            ? await putRequest<String>(
                target.path,
                cancelToken: cancelToken,
                data: attempt.body,
                parser: _parseSaveMessage,
              )
            : await postRequest<String>(
                target.path,
                cancelToken: cancelToken,
                data: attempt.body,
                parser: _parseSaveMessage,
              );
        last = result;
        if (!result.success) {
          debugPrint(
            '\x1B[31m[ManagerAttendance] close-open '
            '${attempt.label} failed: ${result.message}\x1B[0m',
          );
          continue;
        }
        final persisted = await _employeeDayHasCheckout(
          userId: userId,
          date: date,
          cancelToken: cancelToken,
        );
        debugPrint(
          '\x1B[31m[ManagerAttendance] close-open '
          '${attempt.label} api_ok persisted=$persisted\x1B[0m',
        );
        if (persisted) return result;
      }
    }

    return last?.success == true
        ? ApiResponse.failure(
            'Checkout did not save. Please try again.',
            statusCode: last?.statusCode,
          )
        : (last ??
              ApiResponse.failure('Checkout did not save. Please try again.'));
  }

  Future<bool> _employeeDayHasCheckout({
    required int userId,
    required String date,
    ApiCancelToken? cancelToken,
  }) async {
    try {
      final details = await getEmployeeDayDetails(
        userId: userId,
        date: date,
        cancelToken: cancelToken,
      );
      final day = details.data?.history.isNotEmpty == true
          ? details.data!.history.first
          : null;
      if (day == null) return false;
      final top = (day.checkout ?? '').trim();
      if (top.isNotEmpty) return true;
      for (final detail in day.details) {
        if (_detailMatchesAction(detail.type, 'checkout')) return true;
      }
      debugPrint(
        '\x1B[31m[ManagerAttendance] verify checkout missing '
        'checkin=${day.checkin} checkout=${day.checkout} '
        'details=${day.details.map((d) => '${d.type}:${d.id}').toList()}'
        '\x1B[0m',
      );
    } catch (e) {
      debugPrint(
        '\x1B[31m[ManagerAttendance] verify checkout error: $e\x1B[0m',
      );
    }
    return false;
  }

  /// Body for `PUT/POST /manager/employees/{id}/attendance` (API §4.1).
  ///
  /// Spec primary form is top-level `check_in` / `check_out` (no detail ids).
  /// Multi-session days may also send `events` **with** ids. Orphan
  /// `events` / `changes` rows without ids make several backends ignore
  /// `check_out` while still returning `success: true`.
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
    List<Map<String, dynamic>> additionalEvents = const [],
    required List<AttendanceChangeRequestPayload> changes,
  }) {
    bool hasId(String? id) => id != null && id.trim().isNotEmpty;

    Map<String, dynamic> event(String type, String time, String? id) {
      final payload = <String, dynamic>{'type': type, 'time': time};
      final parsedId = int.tryParse((id ?? '').trim());
      if (parsedId != null) {
        payload['id'] = parsedId;
      } else if (hasId(id)) {
        payload['id'] = id!.trim();
      }
      return payload;
    }

    // Existing open shift (has attendance_id, new checkout has no detail id):
    // §4.1 simple body only. Mixing id-less checkout events / change_requests
    // makes several backends return success while leaving the day open.
    final closingOpenShift =
        attendanceId != null &&
        checkOut != null &&
        checkOut.isNotEmpty &&
        !hasId(checkOutDetailId);

    if (closingOpenShift) {
      return {
        'date': date,
        if (userId != null) 'user_id': userId,
        'attendance_id': attendanceId,
        if (checkIn != null && checkIn.isNotEmpty) 'check_in': checkIn,
        'check_out': checkOut,
        if (breakStart != null && breakStart.isNotEmpty) 'breakout': breakStart,
        if (breakEnd != null && breakEnd.isNotEmpty) 'breakin': breakEnd,
      };
    }

    final creating = attendanceId == null;
    final events = <Map<String, dynamic>>[];
    void maybeEvent(String type, String? time, String? id) {
      if (time == null || time.isEmpty) return;
      // Existing day: only send events that update a known detail row.
      // New day: events without ids are how the server creates punches.
      if (!creating && !hasId(id)) return;
      events.add(event(type, time, id));
    }

    maybeEvent('checkin', checkIn, checkInDetailId);
    maybeEvent('breakout', breakStart, breakStartDetailId);
    maybeEvent('breakin', breakEnd, breakEndDetailId);
    maybeEvent('checkout', checkOut, checkOutDetailId);
    for (final extra in additionalEvents) {
      final id = extra['id']?.toString();
      if (!creating && !hasId(id)) continue;
      events.add(Map<String, dynamic>.from(extra));
    }

    final validChanges = changes.where((c) => c.hasDetailId).toList();

    return {
      'date': date,
      if (userId != null) 'user_id': userId,
      if (attendanceId != null) 'attendance_id': attendanceId,
      if (checkIn != null && checkIn.isNotEmpty) 'check_in': checkIn,
      if (checkOut != null && checkOut.isNotEmpty) 'check_out': checkOut,
      if (breakStart != null && breakStart.isNotEmpty) 'breakout': breakStart,
      if (breakEnd != null && breakEnd.isNotEmpty) 'breakin': breakEnd,
      if (events.isNotEmpty) 'events': events,
      if (validChanges.isNotEmpty)
        'changes': validChanges.map((e) => e.toJson()).toList(),
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
