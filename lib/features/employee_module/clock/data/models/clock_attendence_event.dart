import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/shared/location/service/geofence_helper.dart';

class AttendanceEvent {
  final String id;
  final AttendanceEventType type;
  final DateTime time;
  final String? location;

  final bool isValidLocation;

  const AttendanceEvent({
    required this.id,
    required this.type,
    required this.time,
    this.location,
    this.isValidLocation = true,
  });

  AttendanceEvent copyWith({
    String? id,
    AttendanceEventType? type,
    DateTime? time,
    String? location,
    bool? isValidLocation,
  }) {
    return AttendanceEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      time: time ?? this.time,
      location: location ?? this.location,
      isValidLocation: isValidLocation ?? this.isValidLocation,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'time': time.toIso8601String(),
    'location': location,
    'is_valid_location': isValidLocation,
  };

  factory AttendanceEvent.fromJson(Map<String, dynamic> json) {
    return AttendanceEvent(
      id: json['id'] as String? ?? "${DateTime.now().microsecondsSinceEpoch}",
      type: AttendanceEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AttendanceEventType.checkIn,
      ),
      time: DateTime.parse(json['time'] as String),
      location: json['location'] as String?,
      isValidLocation: json['is_valid_location'] as bool? ?? true,
    );
  }

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
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return "${hours}h ${mm}m ";
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

  static final RegExp _coordinatePattern = RegExp(
    r'^-?\d{1,3}(\.\d+)?,\s*-?\d{1,3}(\.\d+)?$',
  );

  static bool isRawCoordinates(String? location) {
    if (location == null) return false;
    final trimmed = location.trim();
    if (trimmed.isEmpty) return false;
    return _coordinatePattern.hasMatch(trimmed);
  }

  static String displayLocation(String? location) {
    if (location == null || location.trim().isEmpty) return "--";
    if (isRawCoordinates(location)) return "--";
    return location.trim();
  }

  static String resolvedDisplayLocation(
    String? location,
    List<KnownLocation> knownLocations,
  ) {
    if (location == null || location.trim().isEmpty) {
      return "Location unavailable";
    }
    if (!isRawCoordinates(location)) return location.trim();

    final point = GeoPoint.tryParse(location);
    if (point == null) return "Location unavailable";

    String? bestName;
    var bestDistance = double.infinity;
    for (final known in knownLocations) {
      final knownPoint = GeoPoint.tryParse(known.latLon);
      if (knownPoint == null) continue;
      final distance = GeofenceHelper.distanceMeters(point, knownPoint);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestName = known.name;
      }
    }

    if (bestName != null && bestDistance <= kDefaultGeofenceRadiusMeters) {
      return bestName;
    }
    return "Location unavailable";
  }
}

class KnownLocation {
  const KnownLocation({required this.name, required this.latLon});
  final String name;
  final String? latLon;
}
