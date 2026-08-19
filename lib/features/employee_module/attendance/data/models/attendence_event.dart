import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';

class HistoryAttendanceEvent {
  final String? id;
  final AttendanceHisotryEventType type;
  final DateTime time;
  final String? location;
  final List<AttendanceEditRequest> editRequests;

  const HistoryAttendanceEvent({
    this.id,
    required this.type,
    required this.time,
    this.location,
    this.editRequests = const [],
  });

  bool get isEdited => editRequests.isNotEmpty;

  HistoryAttendanceEvent copyWith({
    String? id,
    AttendanceHisotryEventType? type,
    DateTime? time,
    String? location,
    List<AttendanceEditRequest>? editRequests,
  }) {
    return HistoryAttendanceEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      time: time ?? this.time,
      location: location ?? this.location,
      editRequests: editRequests ?? this.editRequests,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'time': time.toIso8601String(),
    'location': location,
    'edit_requests': editRequests.map((e) => e.toJson()).toList(),
  };

  factory HistoryAttendanceEvent.fromJson(Map<String, dynamic> json) {
    return HistoryAttendanceEvent(
      id: json['id']?.toString(),
      type: AttendanceHisotryEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AttendanceHisotryEventType.checkIn,
      ),
      time: DateTime.parse(json['time'] as String),
      location: json['location'] as String?,
      editRequests: AttendanceEditRequest.listFromJson(
        json['edit_requests'] ?? json['fix_requests'],
      ),
    );
  }

  String get label {
    switch (type) {
      case AttendanceHisotryEventType.checkIn:
        return "Check-In";
      case AttendanceHisotryEventType.checkOut:
        return "Check-Out";
      case AttendanceHisotryEventType.breakStart:
        return "Break Start";
      case AttendanceHisotryEventType.breakEnd:
        return "Break End";
    }
  }
}

/// ------------------------------------------------------------
/// Formatting Helpers
/// ------------------------------------------------------------
class AttendanceFormat {
  AttendanceFormat._();

  static String time(DateTime? t) {
    if (t == null) return "--";
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $ampm";
  }

  static String duration(Duration d) {
    if (d.isNegative) return "0m";
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;

    if (hours == 0 && minutes == 0) return "0m";
    if (hours == 0) return "${minutes}m";
    if (minutes == 0) return "${hours}h";
    return "${hours}h ${minutes}m";
  }

  static const List<String> _days = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];

  static const List<String> _months = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];

  static String weekdayDate(DateTime d) {
    return "${_days[d.weekday % 7]}, ${d.day} ${_months[d.month - 1]}";
  }

  static String fullDate(DateTime d) {
    return "${d.day} ${_months[d.month - 1]} ${d.year}";
  }
}
