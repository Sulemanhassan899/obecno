import 'dart:async';
import 'package:Obecno/core/constants/app_enums.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Obecno/shared/location/service/geofence_helper.dart';
import 'package:Obecno/shared/location/service/location_service.dart';

class LocationProvider extends ChangeNotifier {
  LocationProvider({LocationService? locationService})
    : _locationService = locationService ?? LocationServiceImpl() {
    unawaited(_restoreCachedCompanyLocation());
    unawaited(_restoreCachedRadius());
  }

  final LocationService _locationService;

  static const String _cacheKeyLat = 'location_provider_company_lat';
  static const String _cacheKeyLon = 'location_provider_company_lon';
  static const String _cacheKeyName = 'location_provider_company_name';
  static const String _cacheKeyRadius = 'location_provider_radius_meters';

  GeoPoint? _companyLocation;
  GeoPoint? get companyLocation => _companyLocation;

  String? companyLocationName;

  int _radiusMeters = kDefaultGeofenceRadiusMeters;
  int get radiusMeters => _radiusMeters;

  void configureRadius(int? meters) {
    if (meters != null) {
      _radiusMeters = GeofenceHelper.normalizeRadius(meters);
      unawaited(_cacheRadius(_radiusMeters));
    }
    _recomputeGeofence();
    notifyListeners();
  }

  Future<void> _cacheRadius(int meters) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cacheKeyRadius, meters);
    } catch (_) {}
  }

  Future<void> _restoreCachedRadius() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getInt(_cacheKeyRadius);
      if (cached == null) return;
      _radiusMeters = GeofenceHelper.normalizeRadius(cached);
      _recomputeGeofence();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> bindCompanyLocation({
    required String name,
    required String? latLon,
  }) async {
    companyLocationName = name;
    final parsed = GeoPoint.tryParse(latLon);

    if (parsed != null) {
      _companyLocation = parsed;
      unawaited(_cacheCompanyLocation(name, parsed));
    } else if (_companyLocation == null) {
      await _restoreCachedCompanyLocation();
    }

    _recomputeGeofence();
    notifyListeners();
  }

  Future<void> _cacheCompanyLocation(String name, GeoPoint point) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyName, name);
      await prefs.setDouble(_cacheKeyLat, point.lat);
      await prefs.setDouble(_cacheKeyLon, point.lon);
    } catch (_) {}
  }

  Future<void> _restoreCachedCompanyLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_cacheKeyLat);
      final lon = prefs.getDouble(_cacheKeyLon);
      if (lat == null || lon == null) return;
      _companyLocation = GeoPoint(lat: lat, lon: lon);
      companyLocationName ??= prefs.getString(_cacheKeyName);
      _recomputeGeofence();
      notifyListeners();
    } catch (_) {}
  }

  GeoPoint? _userLocation;
  GeoPoint? get userLocation => _userLocation;

  double? _accuracyMeters;
  double? get accuracyMeters => _accuracyMeters;

  bool isRefreshing = false;
  LocationErrorType errorType = LocationErrorType.none;
  String? errorMessage;

  Future<void> refreshUserLocation() async {
    isRefreshing = true;
    errorType = LocationErrorType.none;
    errorMessage = null;
    notifyListeners();

    try {
      final reading = await _locationService.getCurrentReading();
      _userLocation = GeoPoint(
        lat: reading.location.lat,
        lon: reading.location.lon,
      );
      _accuracyMeters = reading.accuracyMeters;
      _recomputeGeofence();
    } on LocationPermissionDeniedException {
      errorType = LocationErrorType.permissionDenied;
      errorMessage = 'Location permission is required to check office range.';
      _clearUserLocation();
    } on LocationServiceDisabledException {
      errorType = LocationErrorType.serviceDisabled;
      errorMessage = 'Please turn on location services.';
      _clearUserLocation();
    } on LocationAccuracyTooLowException catch (e) {
      errorType = LocationErrorType.accuracyTooLow;
      errorMessage =
          'Location accuracy too low (${e.accuracyMeters.toStringAsFixed(0)}m). Move to an open area and try again.';
      _clearUserLocation();
    } on MockLocationDetectedException {
      errorType = LocationErrorType.mockLocationDetected;
      errorMessage =
          'A mock location was detected. Please disable it to continue.';
      _clearUserLocation();
    } catch (_) {
      errorType = LocationErrorType.unknown;
      errorMessage = 'Unable to get your location. Please try again.';
      _clearUserLocation();
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  void _clearUserLocation() {
    _userLocation = null;
    _accuracyMeters = null;
    _geofenceResult = null;
  }

  GeofenceResult? _geofenceResult;
  GeofenceResult? get geofenceResult => _geofenceResult;

  bool get isInRange => _geofenceResult?.isInside ?? false;

  String? get rangeMessage => errorMessage ?? _geofenceResult?.message;

  void _recomputeGeofence() {
    final user = _userLocation;
    if (user == null) {
      _geofenceResult = null;
      return;
    }
    _geofenceResult = GeofenceHelper.evaluate(
      companyLocation: _companyLocation,
      user: user,
      radiusMeters: _radiusMeters,
    );
  }
}
