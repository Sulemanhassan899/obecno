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
      capturedAt: reconstructCapturedAt(map),
      location: (lat != null && lon != null)
          ? LocationModel(lat: lat, lon: lon)
          : null,
      requestId: storedRequestId,
      deviceDetails: storedDeviceDetails,
    );
  }

  /// Rebuilds the original action wall-clock from the queued row.
  ///
  /// Prefers the stored `date` + `time` columns (the calendar day and clock
  /// time of the punch) over parsing `created_at`, so a later timezone or
  /// UTC/local conversion cannot turn 21 Aug 09:00 into the sync day's date.
  /// Never falls back to [DateTime.now].
  static DateTime reconstructCapturedAt(Map<String, dynamic> map) {
    final createdAtRaw = map['created_at']?.toString();
    DateTime? createdAt;
    if (createdAtRaw != null && createdAtRaw.trim().isNotEmpty) {
      createdAt = DateTime.tryParse(createdAtRaw.trim());
    }

    var second = createdAt?.second ?? 0;
    final millisecond = createdAt?.millisecond ?? 0;
    final microsecond = createdAt?.microsecond ?? 0;

    final dateStr = map['date']?.toString().trim();
    final timeStr = map['time']?.toString().trim();
    if (dateStr != null &&
        dateStr.isNotEmpty &&
        timeStr != null &&
        timeStr.isNotEmpty) {
      final dateParts = dateStr.split('-');
      final timeParts = timeStr.split(':');
      if (dateParts.length == 3 && timeParts.length >= 2) {
        final year = int.tryParse(dateParts[0]);
        final month = int.tryParse(dateParts[1]);
        final day = int.tryParse(dateParts[2]);
        final hour = int.tryParse(timeParts[0]);
        final minute = int.tryParse(timeParts[1]);
        if (timeParts.length >= 3) {
          second = int.tryParse(timeParts[2]) ?? second;
        }
        if (year != null &&
            month != null &&
            day != null &&
            hour != null &&
            minute != null) {
          return DateTime(
            year,
            month,
            day,
            hour,
            minute,
            second,
            millisecond,
            microsecond,
          );
        }
      }
    }

    if (createdAt != null) {
      // Local wall-clock components of the stored instant — never "now".
      final local = createdAt.isUtc ? createdAt.toLocal() : createdAt;
      return DateTime(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
        local.millisecond,
        local.microsecond,
      );
    }

    throw FormatException('Queue row is missing both date/time and created_at');
  }

  @override
  String toString() =>
      'AttendancePayloadModel(action: $action, capturedAt: $capturedAt, '
      'location: $location, requestId: $requestId, '
      'deviceDetails: $deviceDetails)';
}
