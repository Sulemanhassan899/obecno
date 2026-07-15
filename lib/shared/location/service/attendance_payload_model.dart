import 'package:Obecno/shared/location/data/location_model.dart';

/// Standardized action strings sent to the backend.
///
/// CONFIRMED against the live API's own error response (422):
/// "Invalid action. Use checkin, checkout, breakout, or breakin."
/// -- the server does NOT accept "break_start"/"break_end"; every break
/// action was being rejected as a business failure until this was fixed.
class AttendanceAction {
  AttendanceAction._();

  static const String checkIn = 'checkin';
  static const String checkOut = 'checkout';
  static const String breakStart = 'breakout'; // leaving for a break
  static const String breakEnd = 'breakin'; // returning from a break
  static const String outOfRange = 'out_of_range';
}

/// One attendance action, captured once and never re-timestamped.
///
/// [capturedAt] is set the instant the user taps the button (see
/// `AttendanceProvider`) and is carried through unchanged -- to the API
/// call if online, or into the SQLite queue if offline -- so a delayed
/// sync never sends the sync time instead of the real action time.
class AttendancePayloadModel {
  final String action;
  final DateTime capturedAt;
  final LocationModel? location;

  const AttendancePayloadModel({
    required this.action,
    required this.capturedAt,
    this.location,
  });

  String get date =>
      '${capturedAt.year.toString().padLeft(4, '0')}-'
      '${capturedAt.month.toString().padLeft(2, '0')}-'
      '${capturedAt.day.toString().padLeft(2, '0')}';

  String get time =>
      '${capturedAt.hour.toString().padLeft(2, '0')}:'
      '${capturedAt.minute.toString().padLeft(2, '0')}';

  /// Body actually accepted by `POST /api/employee/attendance` --
  /// action + optional lat/lon/current_location only. Date/time are
  /// deliberately NOT sent; the live endpoint doesn't take them (the
  /// server stamps its own received time), per the confirmed swagger
  /// example.
  Map<String, dynamic> toApiJson() => {
    'action': action,
    if (location != null) ...location!.toJson(),
  };

  /// Row shape for the local `attendance_queue` SQLite table. Keeps
  /// date/time locally (useful for the offline queue UI / debugging)
  /// even though they're not sent to the API.
  Map<String, dynamic> toQueueMap() => {
    'action': action,
    'date': date,
    'time': time,
    'lat': location?.lat,
    'lon': location?.lon,
    'created_at': capturedAt.toIso8601String(),
    'is_synced': 0,
  };

  factory AttendancePayloadModel.fromQueueMap(Map<String, dynamic> map) {
    final lat = (map['lat'] as num?)?.toDouble();
    final lon = (map['lon'] as num?)?.toDouble();
    return AttendancePayloadModel(
      action: map['action'] as String,
      capturedAt: DateTime.parse(map['created_at'] as String),
      location: (lat != null && lon != null)
          ? LocationModel(lat: lat, lon: lon)
          : null,
    );
  }

  @override
  String toString() =>
      'AttendancePayloadModel(action: $action, capturedAt: $capturedAt, location: $location)';
}
