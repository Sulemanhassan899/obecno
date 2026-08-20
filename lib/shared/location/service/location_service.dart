import 'dart:async';

import 'package:obecno/shared/location/data/location_model.dart';
import 'package:geolocator/geolocator.dart';

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
}

class LocationServiceImpl implements LocationService {
  static const double maxAcceptableAccuracyMeters = 50;

  static const Duration _positionTimeout = Duration(seconds: 15);

  @override
  Future<LocationModel> getCurrentLocation() async {
    final reading = await getCurrentReading();
    return reading.location;
  }

  @override
  Future<GpsReading> getCurrentReading() async {
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

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: _positionTimeout,
      );
    } on TimeoutException {
      throw const LocationTimeoutException();
    }

    if (position.isMocked) {
      throw const MockLocationDetectedException();
    }

    if (position.accuracy > maxAcceptableAccuracyMeters) {
      throw LocationAccuracyTooLowException(position.accuracy);
    }

    return GpsReading(
      location: LocationModel(lat: position.latitude, lon: position.longitude),
      accuracyMeters: position.accuracy,
      isMocked: position.isMocked,
    );
  }
}
