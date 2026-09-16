import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obecno/shared/location/data/location_model.dart';

class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException();
  @override
  String toString() => 'Location services are disabled on this device.';
}

class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException();
  @override
  String toString() => 'Location permission was denied.';
}

class LocationAccuracyTooLowException implements Exception {
  const LocationAccuracyTooLowException(this.accuracyMeters);
  final double accuracyMeters;
  @override
  String toString() =>
      'Location accuracy too low (${accuracyMeters.toStringAsFixed(0)}m).';
}

class MockLocationDetectedException implements Exception {
  const MockLocationDetectedException();
  @override
  String toString() => 'A mock/fake location was detected.';
}

class LocationTimeoutException implements Exception {
  const LocationTimeoutException();
  @override
  String toString() => 'Timed out waiting for a GPS location.';
}

class GpsReading {
  final LocationModel location;
  final double accuracyMeters;
  final bool isMocked;

  const GpsReading({
    required this.location,
    required this.accuracyMeters,
    required this.isMocked,
  });
}

abstract class LocationService {
  Future<LocationModel> getCurrentLocation();
  Future<GpsReading> getCurrentReading();
  Future<GpsReading?> getLastKnownReading();
}

class LocationServiceImpl implements LocationService {
  static const double maxAcceptableAccuracyMeters = 50;

  static const Duration _positionTimeout = Duration(seconds: 15);
  static const Duration _fallbackTimeout = Duration(seconds: 10);

  @override
  Future<LocationModel> getCurrentLocation() async {
    final reading = await getCurrentReading();
    return reading.location;
  }

  @override
  Future<GpsReading> getCurrentReading() async {
    await _ensureLocationReady();

    try {
      return await _readCurrent(
        forceLocationManager: false,
        timeLimit: _positionTimeout,
      );
    } on TimeoutException {
      final fallback =
          await _androidGpsFallback() ?? await getLastKnownReading();
      if (fallback != null) return fallback;
      throw const LocationTimeoutException();
    } on LocationAccuracyTooLowException {
      final fallback =
          await _androidGpsFallback() ?? await getLastKnownReading();
      if (fallback != null) return fallback;
      rethrow;
    } on LocationTimeoutException {
      final fallback =
          await _androidGpsFallback() ?? await getLastKnownReading();
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  @override
  Future<GpsReading?> getLastKnownReading() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      return _readingFrom(position, enforceAccuracy: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException();
    }
  }

  Future<GpsReading?> _androidGpsFallback() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _readCurrent(
        forceLocationManager: true,
        timeLimit: _fallbackTimeout,
        enforceAccuracy: false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<GpsReading> _readCurrent({
    required bool forceLocationManager,
    required Duration timeLimit,
    bool enforceAccuracy = true,
  }) async {
    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: _settings(
          timeLimit: timeLimit,
          forceLocationManager: forceLocationManager,
        ),
      );
    } on TimeoutException {
      throw const LocationTimeoutException();
    }

    return _readingFrom(position, enforceAccuracy: enforceAccuracy);
  }

  GpsReading _readingFrom(Position position, {required bool enforceAccuracy}) {
    if (enforceAccuracy && position.accuracy > maxAcceptableAccuracyMeters) {
      throw LocationAccuracyTooLowException(position.accuracy);
    }

    return GpsReading(
      location: LocationModel(lat: position.latitude, lon: position.longitude),
      accuracyMeters: position.accuracy,
      isMocked: position.isMocked,
    );
  }

  LocationSettings _settings({
    required Duration timeLimit,
    bool forceLocationManager = false,
  }) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: forceLocationManager,
          timeLimit: timeLimit,
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        );
      default:
        return LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        );
    }
  }
}
