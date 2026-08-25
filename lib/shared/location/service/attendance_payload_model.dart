import 'dart:io' show Platform;
import 'dart:math';

import 'package:obecno/shared/location/data/location_model.dart';

class AttendanceAction {
  AttendanceAction._();

  static const String checkIn = 'checkin';
  static const String checkOut = 'checkout';
  static const String breakStart = 'breakout'; // leaving for a break
  static const String breakEnd = 'breakin'; // returning from a break
  static const String outOfRange = 'out_of_range';
}

class AttendancePayloadModel {
  final String action;
  final DateTime capturedAt;
  final LocationModel? location;

  final String requestId;

  final String deviceDetails;

  AttendancePayloadModel({
    required this.action,
    required this.capturedAt,
    this.location,
    String? requestId,
    String? deviceDetails,
  }) : requestId = requestId ?? _generateRequestId(action, capturedAt),
       deviceDetails = deviceDetails ?? _defaultDeviceDetails();

  static final Random _random = Random();

  static String _generateRequestId(String action, DateTime capturedAt) {
    final rand = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '${capturedAt.microsecondsSinceEpoch}-$action-$rand';
  }

  /// Fallback when [DeviceInfoService] is unavailable. Prefer injecting
  /// a real `deviceDetails` from DeviceInfoService (e.g. "Vivo e23 | Android 13").
  static String _defaultDeviceDetails() {
    try {
      final osLabel = Platform.isIOS
          ? 'iOS'
          : (Platform.isAndroid ? 'Android' : Platform.operatingSystem);
      return 'Unknown | $osLabel ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'unknown device';
    }
  }

  String get date =>
      '${capturedAt.year.toString().padLeft(4, '0')}-'
      '${capturedAt.month.toString().padLeft(2, '0')}-'
      '${capturedAt.day.toString().padLeft(2, '0')}';

  String get time =>
      '${capturedAt.hour.toString().padLeft(2, '0')}:'
      '${capturedAt.minute.toString().padLeft(2, '0')}';

  /// Wall-clock timestamp the API expects: `2026-08-10 03:00:00`.
  String get datetime =>
      '$date ${time}:${capturedAt.second.toString().padLeft(2, '0')}';

  Map<String, dynamic> toApiJson() => {
    'action': action,
    'device_details': deviceDetails,
    'datetime': datetime,
    if (location != null) 'lat': location!.lat,
    if (location != null) 'lon': location!.lon,
  };
  Map<String, dynamic> toQueueMap() => {
    'action': action,
    'date': date,
    'time': time,
    'lat': location?.lat,
    'lon': location?.lon,
    'created_at': capturedAt.toIso8601String(),
    'is_synced': 0,
    'request_id': requestId,
    'device_details': deviceDetails,
  };

  factory AttendancePayloadModel.fromQueueMap(Map<String, dynamic> map) {
    final lat = (map['lat'] as num?)?.toDouble();
    final lon = (map['lon'] as num?)?.toDouble();
    final storedRequestId = map['request_id'] as String?;
    final storedDeviceDetails = map['device_details'] as String?;
    return AttendancePayloadModel(
      action: map['action'] as String,
      capturedAt: DateTime.parse(map['created_at'] as String),
      location: (lat != null && lon != null)
          ? LocationModel(lat: lat, lon: lon)
          : null,
      requestId: storedRequestId,
      deviceDetails: storedDeviceDetails,
    );
  }

  @override
  String toString() =>
      'AttendancePayloadModel(action: $action, capturedAt: $capturedAt, '
      'location: $location, requestId: $requestId, '
      'deviceDetails: $deviceDetails)';
}
