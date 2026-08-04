
import 'dart:async';
import 'dart:convert';

import 'package:Obecno/core/api/api_cancel_token.dart';
import 'package:Obecno/core/api/api_client.dart';
import 'package:Obecno/core/api/api_endpoints.dart';
import 'package:Obecno/core/api/api_error.dart';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/shared/location/service/attendance_connectivity_service.dart';
import 'package:Obecno/shared/location/service/attendance_payload_model.dart';
import 'package:Obecno/shared/location/service/local_queue_service.dart';
import 'package:flutter/foundation.dart';

class AttendanceApiException implements Exception {
  AttendanceApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AttendanceBusinessException implements Exception {
  AttendanceBusinessException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AttendanceAuthException implements Exception {
  AttendanceAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AttendanceQueueException implements Exception {
  AttendanceQueueException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AttendanceCancelledException implements Exception {
  AttendanceCancelledException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AttendanceRepository {
  AttendanceRepository(
    this._client,
    this._connectivityService,
    this._queueService,
  );

  final ApiClient _client;
  final AttendanceConnectivityService _connectivityService;
  final LocalQueueService _queueService;
  Future<void> Function()? _syncTrigger;

  void attachSyncTrigger(Future<void> Function() trigger) {
    _syncTrigger = trigger;
  }

  void _triggerImmediateSync() {
    final trigger = _syncTrigger;
    if (trigger == null) return;
    unawaited(trigger());
  }

  Future<({bool synced, String? notification})> submitAttendance(
    AttendancePayloadModel payload, {
    ApiCancelToken? cancelToken,
  }) async {
    final online = await _connectivityService.isOnline();

    if (!online) {
      debugPrint(
        '[AttendanceRepository] submitAttendance: offline -> queuing '
        '"${payload.action}" locally',
      );
      final queued = await _queueService.insert(payload);
      if (!queued) {
        throw AttendanceQueueException(
          "Couldn't save this action locally. Please try again.",
        );
      }
      return (synced: false, notification: null);
    }

    try {
      final notification = await _sendToApi(payload, cancelToken: cancelToken);
      return (synced: true, notification: notification);
    } on AttendanceBusinessException {
      rethrow;
    } on AttendanceAuthException {
      rethrow;
    } on AttendanceCancelledException {
      rethrow;
    } catch (e) {
      debugPrint(
        '[AttendanceRepository] submitAttendance: online send failed ($e) '
        '-> falling back to local queue for "${payload.action}"',
      );
      final queued = await _queueService.insert(payload);
      if (!queued) {
        throw AttendanceQueueException(
          "Couldn't reach the server or save this action locally. "
          'Please try again.',
        );
      }
      _triggerImmediateSync();
      return (synced: false, notification: null);
    }
  }

  Future<String?> sendQueuedPayload(
    AttendancePayloadModel payload, {
    ApiCancelToken? cancelToken,
  }) =>
      _sendToApi(payload, cancelToken: cancelToken);

  Future<List<AttendanceEvent>?> fetchTodayEvents({
    ApiCancelToken? cancelToken,
  }) async {
    try {
      final today = _todayDateString();
      final response = await _client.get(
        ApiEndpoints.attendance,
        queryParameters: {'date_from': today, 'date_to': today},
        cancelToken: cancelToken,
      );

      final container = _findTodayAttendanceContainer(response.data);
      if (container == null) {
        debugPrint(
          '[AttendanceRepository] fetchTodayEvents: no today_attendance '
          'container found in response',
        );
        return null;
      }

      final detailsRaw = container['attendance_details'];
      if (detailsRaw is List && detailsRaw.isNotEmpty) {
        final parsed =
            detailsRaw
                .whereType<Map>()
                .map((raw) => _eventFromDetail(Map<String, dynamic>.from(raw)))
                .whereType<AttendanceEvent>()
                .toList()
              ..sort((a, b) => a.time.compareTo(b.time));

        final seen = <String>{};
        final events = <AttendanceEvent>[];
        for (final event in parsed) {
          final key = '${event.type.name}|${event.time.toIso8601String()}';
          if (seen.add(key)) events.add(event);
        }

        debugPrint(
          '[AttendanceRepository] fetchTodayEvents: parsed '
          '${events.length} event(s) from attendance_details '
          '(${detailsRaw.length} raw row(s), '
          '${parsed.length - events.length} duplicate(s) dropped)',
        );
        return events;
      }

      final todayAttendance = container['today_attendance'];

      final sessionsRaw = container['today_sessions'];
      final List<Map> sessionMaps;
      if (sessionsRaw is List && sessionsRaw.isNotEmpty) {
        sessionMaps = sessionsRaw.whereType<Map>().toList();
      } else if (todayAttendance is Map) {
        sessionMaps = [todayAttendance];
      } else {
        sessionMaps = const [];
      }

      if (sessionMaps.isEmpty) return const [];

      final events = <AttendanceEvent>[];

      for (final session in sessionMaps) {
        final sessionLocation = _dayLevelLocation(session);

        void addIfPresent(dynamic raw, AttendanceEventType type) {
          final parsed = _parseTimeOfDay(raw?.toString());
          if (parsed == null) return;
          events.add(
            AttendanceEvent(
              id: 'server_${type.name}_${parsed.microsecondsSinceEpoch}',
              type: type,
              time: parsed,
              location: sessionLocation,
            ),
          );
        }

        addIfPresent(session['checkin'], AttendanceEventType.checkIn);
        addIfPresent(session['breakout'], AttendanceEventType.breakStart);
        addIfPresent(session['breakin'], AttendanceEventType.breakEnd);
        addIfPresent(session['checkout'], AttendanceEventType.checkOut);
      }

      events.sort((a, b) => a.time.compareTo(b.time));

      debugPrint(
        '[AttendanceRepository] fetchTodayEvents: parsed ${events.length} '
        'event(s) from ${sessionMaps.length} session(s)',
      );

      return events;
    } catch (e, st) {
      debugPrint('[AttendanceRepository] fetchTodayEvents: failed -> $e\n$st');
      return null;
    }
  }

  AttendanceEvent? _eventFromDetail(Map<String, dynamic> detail) {
    final type = _eventTypeFromApiType(detail['type']?.toString());
    if (type == null) return null;

    final time = _parseDetailTimestamp(detail);
    if (time == null) return null;

    return AttendanceEvent(
      id:
          detail['id']?.toString() ??
          detail['name']?.toString() ??
          'server_${type.name}_${time.microsecondsSinceEpoch}',
      type: type,
      time: time,
      location: _dayLevelLocation(detail),
    );
  }

  AttendanceEventType? _eventTypeFromApiType(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'check in':
      case 'checkin':
        return AttendanceEventType.checkIn;
      case 'check out':
      case 'checkout':
        return AttendanceEventType.checkOut;
      case 'break out':
      case 'breakout':
        return AttendanceEventType.breakStart;
      case 'break in':
      case 'breakin':
        return AttendanceEventType.breakEnd;
      default:
        return null;
    }
  }

  DateTime? _parseDetailTimestamp(Map<String, dynamic> detail) {
    final iso = detail['occurred_at_iso']?.toString();
    if (iso != null && iso.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(iso.trim());
      if (parsed != null) return parsed.toLocal();
    }

    final timeStr = detail['attendance_time']?.toString();
    if (timeStr == null || timeStr.trim().isEmpty) return null;

    final dateStr = detail['attendance_date']?.toString();
    final datePart = (dateStr != null && dateStr.trim().isNotEmpty)
        ? DateTime.tryParse(dateStr.trim())
        : null;
    final base = datePart ?? DateTime.now();

    final parts = timeStr.trim().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    final second = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;

    return DateTime(base.year, base.month, base.day, hour, minute, second);
  }

  String? _dayLevelLocation(Map todayAttendance) {
    final raw = todayAttendance['current_location'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();

    final lat = todayAttendance['lat'];
    final lon = todayAttendance['lon'];
    if (lat != null && lon != null) return '$lat,$lon';

    return null;
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseTimeOfDay(String? hms) {
    if (hms == null || hms.trim().isEmpty) return null;
    final parts = hms.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    final second = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute, second);
  }

  Map<String, dynamic>? _findTodayAttendanceContainer(dynamic raw) {
    dynamic current = raw;
    for (var i = 0; i < 4; i++) {
      if (current is! Map) return null;
      final map = Map<String, dynamic>.from(current);
      if (map.containsKey('today_attendance')) return map;
      final next = map['data'];
      if (next == null) return null;
      current = next;
    }
    return null;
  }

  Future<String?> _sendToApi(
    AttendancePayloadModel payload, {
    ApiCancelToken? cancelToken,
  }) async {
    late final RawApiResponse response;
    try {
      response = await _client.post(
        ApiEndpoints.attendance,
        data: payload.toApiJson(),
        cancelToken: cancelToken,
      );
    } on ApiError catch (e) {
      if (e.type == ApiErrorType.cancelled) {
        throw AttendanceCancelledException(e.message);
      }
      if (e.type == ApiErrorType.unauthorized) {
        throw AttendanceAuthException(e.message);
      }
      throw AttendanceApiException(e.message);
    }

    final decoded = _asDecodedMap(response.data);

    if (decoded == null) {
      if (response.statusCode != 200) {
        throw AttendanceApiException(
          'Attendance failed (${response.statusCode}).',
        );
      }
      return null;
    }

    final success = decoded['success'] == true;

    if (!success) {
      final message = decoded['message']?.toString() ?? 'Request failed.';
      throw AttendanceBusinessException(message);
    }

    if (response.statusCode != 200) {
      throw AttendanceApiException(
        'Attendance submit failed with status ${response.statusCode}.',
      );
    }

    final data = decoded['data'];
    if (data is Map && data['notification'] != null) {
      final msg = data['notification'].toString().trim();
      if (msg.isNotEmpty) return msg;
    }
    final topLevel = decoded['notification']?.toString().trim();
    if (topLevel != null && topLevel.isNotEmpty) return topLevel;

    return null;
  }

  Map<String, dynamic>? _asDecodedMap(dynamic raw) {
    if (raw is! Map) return null;
    final decoded = Map<String, dynamic>.from(raw);

    if (decoded.containsKey('success')) return decoded;

    final inner = decoded['data'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    if (inner is String) {
      try {
        final innerDecoded = jsonDecode(inner);
        if (innerDecoded is Map<String, dynamic>) return innerDecoded;
      } catch (_) {
        return null;
      }
    }

    return decoded;
  }
}