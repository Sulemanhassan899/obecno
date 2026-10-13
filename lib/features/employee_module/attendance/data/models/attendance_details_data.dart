import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_event.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart'
    show AttendanceEvent;

/// Response from GET /employee/attendance/details
class AttendanceDetailsData {
  const AttendanceDetailsData({
    this.userId,
    this.date,
    this.attendanceId,
    this.total = 0,
    this.details = const [],
  });

  final int? userId;
  final DateTime? date;
  final int? attendanceId;
  final int total;
  final List<AttendanceDetailItem> details;

  factory AttendanceDetailsData.fromJson(Map<String, dynamic> json) {
    final nestedRaw = json['attendance'];
    final nested = nestedRaw is Map
        ? Map<String, dynamic>.from(nestedRaw)
        : const <String, dynamic>{};

    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed == null) return null;
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    int? parseInt(dynamic raw) {
      if (raw == null) return null;
      if (raw is int) return raw;
      return int.tryParse(raw.toString());
    }

    final detailsRaw =
        json['attendance_details'] ?? nested['attendance_details'];
    final details = <AttendanceDetailItem>[];
    if (detailsRaw is List) {
      for (final raw in detailsRaw) {
        if (raw is Map) {
          final item = AttendanceDetailItem.tryParse(
            Map<String, dynamic>.from(raw),
          );
          if (item != null) details.add(item);
        }
      }
    }

    return AttendanceDetailsData(
      userId: parseInt(json['user_id'] ?? nested['user_id']),
      date: parseDate(json['date'] ?? nested['date']),
      attendanceId:
          parseInt(json['attendance_id'] ?? nested['attendance_id']) ??
          parseInt(json['id'] ?? nested['id']),
      total: parseInt(json['total']) ?? details.length,
      details: details,
    );
  }

  List<HistoryAttendanceEvent> toHistoryEvents() {
    final events =
        details
            .map((d) => d.toHistoryEvent())
            .whereType<HistoryAttendanceEvent>()
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    return events;
  }

  List<AttendanceEvent> toClockEvents() {
    final events =
        details
            .map((d) => d.toClockEvent())
            .whereType<AttendanceEvent>()
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    return events;
  }
}

class AttendanceDetailItem {
  const AttendanceDetailItem({
    required this.id,
    required this.type,
    required this.time,
    this.location,
    this.editRequests = const [],
  });

  final String id;
  final AttendanceHisotryEventType type;
  final DateTime time;
  final String? location;
  final List<AttendanceEditRequest> editRequests;

  factory AttendanceDetailItem.fromJson(Map<String, dynamic> json) {
    final type = _typeFromApi(
      json['type']?.toString() ??
          json['action']?.toString() ??
          json['event']?.toString(),
    );
    final time = _parseTime(json);
    if (type == null || time == null) {
      throw FormatException(
        'Invalid attendance detail: type=${json['type'] ?? json['action']} '
        'time missing',
      );
    }

    final location = _normalizedLocation(
      json['current_location'] ??
          (json['lat'] != null && json['lon'] != null
              ? '${json['lat']},${json['lon']}'
              : null),
    );

    final editRequests = AttendanceEditRequest.fromDetailArrays(
      changeRequests: json['change_requests'],
      changes: json['changes'],
    );

    final rawId =
        json['id'] ??
        json['attendance_detail_id'] ??
        json['attendancedetail_id'] ??
        json['detail_id'];
    final serverId = serverDetailId(rawId?.toString().trim()) ?? '';

    return AttendanceDetailItem(
      id: serverId.isNotEmpty
          ? serverId
          : 'local_${time.microsecondsSinceEpoch}',
      type: type,
      time: AttendanceEditRequest.applyApprovedTime(time, editRequests),
      location: location,
      editRequests: editRequests,
    );
  }

  /// Numeric server row id, or null when the value is a local/clock placeholder.
  static String? serverDetailId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = int.tryParse(raw);
    if (parsed != null) return parsed.toString();
    final asDouble = double.tryParse(raw);
    if (asDouble == null || asDouble != asDouble.roundToDouble()) return null;
    if (asDouble < 0) return null;
    return asDouble.toInt().toString();
  }

  static AttendanceDetailItem? tryParse(Map<String, dynamic> json) {
    try {
      return AttendanceDetailItem.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  HistoryAttendanceEvent? toHistoryEvent() {
    return HistoryAttendanceEvent(
      id: id,
      type: type,
      time: time,
      location: location,
      editRequests: editRequests,
    );
  }

  AttendanceEvent? toClockEvent() {
    final clockType = switch (type) {
      AttendanceHisotryEventType.checkIn => AttendanceEventType.checkIn,
      AttendanceHisotryEventType.checkOut => AttendanceEventType.checkOut,
      AttendanceHisotryEventType.breakStart => AttendanceEventType.breakStart,
      AttendanceHisotryEventType.breakEnd => AttendanceEventType.breakEnd,
    };

    return AttendanceEvent(
      id: id,
      type: clockType,
      time: time,
      location: location,
      editRequests: editRequests,
    );
  }

  static AttendanceHisotryEventType? _typeFromApi(String? raw) {
    switch (raw
        ?.trim()
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')) {
      case 'check in':
      case 'checkin':
      case 'clock in':
      case 'clockin':
      case 'in':
        return AttendanceHisotryEventType.checkIn;
      case 'check out':
      case 'checkout':
      case 'clock out':
      case 'clockout':
      case 'out':
        return AttendanceHisotryEventType.checkOut;
      case 'break out':
      case 'breakout':
      case 'break start':
      case 'breakstart':
        return AttendanceHisotryEventType.breakStart;
      case 'break in':
      case 'breakin':
      case 'break end':
      case 'breakend':
        return AttendanceHisotryEventType.breakEnd;
      default:
        return null;
    }
  }

  static DateTime? _parseTime(Map<String, dynamic> json) {
    final date = json['attendance_date']?.toString();
    final day = date != null ? DateTime.tryParse(date) : null;
    final base = day ?? DateTime.now();

    for (final key in const [
      'attendance_time',
      'time',
      'punch_time',
      'clock_time',
    ]) {
      final time = json[key]?.toString();
      if (time == null || time.trim().isEmpty) continue;
      final wall = AttendanceEditRequest.parseClockTime(time, date: base);
      if (wall != null) return wall;
    }

    DateTime? asLocalWall(DateTime parsed) {
      final local = parsed.toLocal();
      return DateTime(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
      );
    }

    for (final key in const ['occurred_at_iso', 'occurred_at', 'created_at']) {
      final raw = json[key]?.toString();
      if (raw == null || raw.isEmpty) continue;
      final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null) return asLocalWall(parsed);
    }

    return null;
  }

  static String? _normalizedLocation(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (s == '0,0' || s == '0.0,0.0') return null;
    return s;
  }
}
