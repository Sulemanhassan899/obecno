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
    final detailsRaw = json['attendance_details'];
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

    return AttendanceDetailsData(
      userId: parseInt(json['user_id']),
      date: parseDate(json['date']),
      attendanceId: parseInt(json['attendance_id']),
      total: parseInt(json['total']) ?? details.length,
      details: details,
    );
  }

  List<HistoryAttendanceEvent> toHistoryEvents() {
    final events = details
        .map((d) => d.toHistoryEvent())
        .whereType<HistoryAttendanceEvent>()
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    return events;
  }

  List<AttendanceEvent> toClockEvents() {
    final events = details
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
    final type = _typeFromApi(json['type']?.toString());
    final time = _parseTime(json);
    if (type == null || time == null) {
      throw FormatException(
        'Invalid attendance detail: type=${json['type']} time missing',
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

    return AttendanceDetailItem(
      id: json['id']?.toString() ?? '${time.microsecondsSinceEpoch}',
      type: type,
      time: AttendanceEditRequest.applyApprovedTime(time, editRequests),
      location: location,
      editRequests: editRequests,
    );
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
    switch (raw?.trim().toLowerCase()) {
      case 'check in':
      case 'checkin':
        return AttendanceHisotryEventType.checkIn;
      case 'check out':
      case 'checkout':
        return AttendanceHisotryEventType.checkOut;
      case 'break out':
      case 'breakout':
      case 'break start':
        return AttendanceHisotryEventType.breakStart;
      case 'break in':
      case 'breakin':
      case 'break end':
        return AttendanceHisotryEventType.breakEnd;
      default:
        return null;
    }
  }

  static DateTime? _parseTime(Map<String, dynamic> json) {
    final iso = json['occurred_at_iso']?.toString();
    if (iso != null && iso.isNotEmpty) {
      final parsed = DateTime.tryParse(iso);
      // Always local — UTC ISO without toLocal() sorts/displays wrong vs
      // attendance_time wall-clock values and can reorder first check-in.
      if (parsed != null) return parsed.toLocal();
    }

    final created = json['created_at']?.toString();
    if (created != null && created.isNotEmpty) {
      final normalized =
          created.contains('T') ? created : created.replaceFirst(' ', 'T');
      final parsed = DateTime.tryParse(normalized);
      if (parsed != null) return parsed.toLocal();
    }

    final date = json['attendance_date']?.toString();
    final time = json['attendance_time']?.toString();
    if (date == null || time == null) return null;

    final parts = time.split(':');
    final h = int.tryParse(parts.elementAt(0)) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final s = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    final day = DateTime.tryParse(date);
    if (day == null) return null;
    return DateTime(day.year, day.month, day.day, h, m, s);
  }

  static String? _normalizedLocation(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (s == '0,0' || s == '0.0,0.0') return null;
    return s;
  }
}
