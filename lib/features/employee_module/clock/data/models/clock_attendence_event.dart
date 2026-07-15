import 'package:Obecno/core/constants/app_enums.dart';

/// ============================================================
/// ATTENDANCE EVENT MODELS
/// ------------------------------------------------------------
/// A single source of truth for every clock action the user
/// performs in a day. Everything else (First Check-In,
/// Last Check-Out, Total Working Duration, Total Break Duration,
/// current status) is DERIVED from this list by AttendanceEngine.
/// ============================================================

/// Type of a single attendance event.

/// A single timestamped attendance action.
class AttendanceEvent {
  final AttendanceEventType type;
  final DateTime time;
  final String? location;
  

  const AttendanceEvent({
    required this.type,
    required this.time,
    this.location,
  });

  AttendanceEvent copyWith({
    AttendanceEventType? type,
    DateTime? time,
    String? location,
  }) {
    return AttendanceEvent(
      type: type ?? this.type,
      time: time ?? this.time,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'time': time.toIso8601String(),
        'location': location,
      };

  factory AttendanceEvent.fromJson(Map<String, dynamic> json) {
    return AttendanceEvent(
      type: AttendanceEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AttendanceEventType.checkIn,
      ),
      time: DateTime.parse(json['time'] as String),
      location: json['location'] as String?,
    );
  }

  /// Human readable label, e.g. "Check-In", "Break Start"
  String get label {
    switch (type) {
      case AttendanceEventType.checkIn:
        return "Check-In";
      case AttendanceEventType.checkOut:
        return "Check-Out";
      case AttendanceEventType.breakStart:
        return "Break Start";
      case AttendanceEventType.breakEnd:
        return "Break End";
    }
  }
}

/// ------------------------------------------------------------
/// Shared formatting helpers used across ClockScreen,
/// AttendanceCard and AttendanceDetailsSheet so time/duration
/// text is always consistent.
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

  /// e.g. "17 October 2025" (used as the bottom sheet header)
  static String fullDate(DateTime d) {
    return "${d.day} ${_months[d.month - 1]} ${d.year}";
  }
}