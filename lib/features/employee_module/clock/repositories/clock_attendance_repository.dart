
import 'dart:convert';

import 'package:Obecno/core/api/api.dart';
import 'package:Obecno/core/api/api_client.dart';
import 'package:Obecno/core/api/api_endpoints.dart';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/shared/location/service/attendance_connectivity_service.dart';
import 'package:Obecno/shared/location/service/attendance_payload_model.dart';
import 'package:Obecno/shared/location/service/local_queue_service.dart';

/// Transport/HTTP-level failure (bad status code, unparsable body,
/// dropped connection, etc). These are treated as "we don't actually
/// know if the server accepted the action" -- safe to queue for retry.
class AttendanceApiException implements Exception {
  AttendanceApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Business-logic rejection: the request reached the server and the
/// server explicitly said `success: false` (e.g. invalid action, out of
/// range, duplicate check-in). Retrying this unchanged will just fail
/// again, so it must NOT be queued -- it needs to surface to the user
/// instead. Kept as a distinct type from [AttendanceApiException] so
/// [AttendanceRepository.submitAttendance] can tell the two apart.
class AttendanceBusinessException implements Exception {
  AttendanceBusinessException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AttendanceRepository {
  AttendanceRepository(
    this._client,
    this._connectivityService,
    this._queueService, [
    // ✅ ADD THIS: optional so every existing call site
    // (`AttendanceRepository(httpClient, connectivityService, queueService)`)
    // keeps compiling unchanged. When supplied, it powers
    // `fetchTodayEvents()` below -- reuses the SAME `ApiClient` already
    // built in AppBindings for the attendance-history GET calls, rather
    // than adding a second HTTP stack.
    this._statusClient,
  ]);

  final HttpApiClient _client;
  final AttendanceConnectivityService _connectivityService;
  final LocalQueueService _queueService;
  final ApiClient? _statusClient;

  /// Submits one attendance event.
  ///
  /// - Offline, or a transport-level failure ([AttendanceApiException]):
  ///   queued locally instead of being lost -- never thrown back to the
  ///   caller.
  /// - Business-logic rejection ([AttendanceBusinessException], i.e. the
  ///   server responded with `success: false`): rethrown as-is. Queuing
  ///   this would just replay the same rejected action forever, so the
  ///   caller (AttendanceProvider / SyncedClockScreenController) needs to
  ///   see it and surface the message instead.
  Future<void> submitAttendance(AttendancePayloadModel payload) async {
    final online = await _connectivityService.isOnline();

    if (!online) {
      await _queueService.insert(payload);
      return;
    }

    try {
      await _sendToApi(payload);
    } on AttendanceBusinessException {
      rethrow;
    } catch (_) {
      // Connectivity check said online but the request itself failed
      // (timeout, 5xx, dropped connection mid-flight, unparsable body,
      // etc.) -- fall back to the offline queue instead of losing the
      // event.
      await _queueService.insert(payload);
    }
  }

  /// Sends one payload directly to the API. Used by [SyncService] when
  /// replaying queued events -- unlike [submitAttendance], this DOES
  /// throw on failure, so the FIFO sync loop knows to stop.
  Future<void> sendQueuedPayload(AttendancePayloadModel payload) =>
      _sendToApi(payload);

  // ✅ ADD THIS: the actual fix for the "stuck on Check Out, every
  // checkout gets 409" loop. Local `_events` was previously built ONLY
  // from optimistic taps + SharedPreferences, with nothing to correct
  // it if it ever drifted from the server (a stale persisted event from
  // an earlier run, an action taken on another device, the server
  // auto-closing a session, etc). Once local and server disagreed,
  // every tap kept failing against the same server truth forever, and
  // restarting the app didn't help because SharedPreferences just
  // restored the same wrong state.
  //
  // Reuses the SAME endpoint (`ApiEndpoints.attendance`) and
  // `date_from`/`date_to` query params already used elsewhere in the
  // app for the attendance-history GET, via `ApiClient` (which already
  // handles 409s, retries, and double-encoded bodies).
  //
  // Returns:
  ///  - null  -> couldn't reach the server (offline, no `_statusClient`
  ///             wired, unexpected shape) -- caller should keep
  ///             whatever local/optimistic state it already has.
  ///  - []    -> server confirms no attendance recorded today.
  ///  - [...] -> reconstructed events matching the server's
  ///             checkin/breakout/breakin/checkout times for today.
  Future<List<AttendanceEvent>?> fetchTodayEvents() async {
    final client = _statusClient;
    if (client == null) return null;

    try {
      final today = _todayDateString();
      final response = await client.get(
        ApiEndpoints.attendance,
        queryParameters: {'date_from': today, 'date_to': today},
      );

      final container = _findTodayAttendanceContainer(response.data);
      if (container == null) return null;

      final todayAttendance = container['today_attendance'];
      if (todayAttendance is! Map) return const [];

      final events = <AttendanceEvent>[];
      void addIfPresent(dynamic raw, AttendanceEventType type) {
        final parsed = _parseTimeOfDay(raw?.toString());
        if (parsed == null) return;
        events.add(AttendanceEvent(type: type, time: parsed));
      }

      // Order matches the natural sequence of a day's session so the
      // engine's chronological sort produces the right open/closed
      // status even if two events share the same second.
      addIfPresent(todayAttendance['checkin'], AttendanceEventType.checkIn);
      addIfPresent(
        todayAttendance['breakout'],
        AttendanceEventType.breakStart,
      );
      addIfPresent(todayAttendance['breakin'], AttendanceEventType.breakEnd);
      addIfPresent(todayAttendance['checkout'], AttendanceEventType.checkOut);

      return events;
    } catch (_) {
      // Best-effort only -- never let a reconciliation failure crash or
      // block the actual clock action.
      return null;
    }
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Parses a server "HH:mm:ss" (or "HH:mm") time-of-day string, applied
  /// to today's date. Returns null for missing/empty/unparseable values
  /// (e.g. `""` for a break that hasn't started).
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

  /// The backend wraps its real payload in nested `data` keys, and
  /// sometimes double-encodes it as a JSON string (same quirk
  /// `_safeDecode` below works around for POST responses). Walks into
  /// `data` up to a few levels until it finds the map that actually has
  /// `today_attendance`, instead of hardcoding one exact nesting depth.
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

  Future<void> _sendToApi(AttendancePayloadModel payload) async {
    final response = await _client.post(
      ApiEndpoints.attendance,
      payload.toApiJson(),
    );

    final decoded = _safeDecode(response.body);

    if (decoded == null) {
      // Body wasn't valid/parseable JSON in either supported shape --
      // fall back to the HTTP status code alone.
      if (response.statusCode != 200) {
        throw AttendanceApiException(
          'Attendance failed (${response.statusCode}).',
        );
      }
      return;
    }

    final success = decoded['success'] == true;

    if (!success) {
      // Server understood the request and explicitly rejected it --
      // a business failure, NOT a transport failure. Must propagate as
      // its own type so `submitAttendance` doesn't queue it for retry.
      final message = decoded['message']?.toString() ?? 'Request failed.';
      throw AttendanceBusinessException(message);
    }

    if (response.statusCode != 200) {
      throw AttendanceApiException(
        'Attendance submit failed with status ${response.statusCode}.',
      );
    }
  }

  /// Safely parses the response body, supporting both shapes the backend
  /// may return:
  ///   Case A: `{"success": false, "message": "..."}`               (plain)
  ///   Case B: `{"data": "{\"success\":false,\"message\":\"...\"}"}` (the
  ///           real payload double-encoded as a string inside `data`)
  /// Returns null (never throws) if the body doesn't match either shape,
  /// so callers can fall back to the HTTP status code instead of crashing.
  Map<String, dynamic>? _safeDecode(String rawBody) {
    if (!rawBody.trim().startsWith('{')) return null;

    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is! Map<String, dynamic>) return null;

      // Case A: already the shape we want.
      if (decoded.containsKey('success')) return decoded;

      // Case B: the real object is stringified inside `data`.
      final inner = decoded['data'];
      if (inner is String) {
        try {
          final innerDecoded = jsonDecode(inner);
          if (innerDecoded is Map<String, dynamic>) return innerDecoded;
        } catch (_) {
          return null;
        }
      }

      return decoded;
    } catch (_) {
      return null;
    }
  }
}