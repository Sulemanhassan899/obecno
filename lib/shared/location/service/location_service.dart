
import 'package:Obecno/shared/location/data/location_model.dart';
import 'package:geolocator/geolocator.dart';

/// Thrown when location services (GPS) are switched off at the OS level.
/// This is distinct from a permission denial -- permission is checked
/// separately by `AttendancePermissionService` before this is ever
/// called.
class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException();

  @override
  String toString() => 'Location services are disabled on this device.';
}

abstract class LocationService {
  Future<LocationModel> getCurrentLocation();
}

/// Wraps `geolocator` behind a single, mockable interface so
/// `AttendanceProvider` never talks to the plugin directly.
///
/// Callers are expected to have already confirmed location permission
/// via `AttendancePermissionService.checkAndRequestPermissions()` --
/// this class only fetches the position, it does not request
/// permission itself.
class LocationServiceImpl implements LocationService {
  @override
  Future<LocationModel> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LocationModel(lat: position.latitude, lon: position.longitude);
  }
}
