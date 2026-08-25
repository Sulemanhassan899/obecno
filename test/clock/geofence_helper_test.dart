import 'package:obecno/shared/location/service/geofence_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeoPoint.tryParse', () {
    test('parses decimal lat,lon', () {
      final p = GeoPoint.tryParse('33.669,73.0719');
      expect(p?.lat, closeTo(33.669, 0.0001));
      expect(p?.lon, closeTo(73.0719, 0.0001));
    });

    test('returns null for garbage', () {
      expect(GeoPoint.tryParse(''), isNull);
      expect(GeoPoint.tryParse('nope'), isNull);
    });
  });

  group('GeofenceHelper.evaluate', () {
    const office = GeoPoint(lat: 33.67, lon: 73.07);
    const nearby = GeoPoint(lat: 33.6701, lon: 73.0701);
    const far = GeoPoint(lat: 34.0, lon: 74.0);

    test('inside radius', () {
      final result = GeofenceHelper.evaluate(
        companyLocation: office,
        user: nearby,
        radiusMeters: 200,
      );
      expect(result.isInside, isTrue);
      expect(result.message, isNull);
    });

    test('outside radius', () {
      final result = GeofenceHelper.evaluate(
        companyLocation: office,
        user: far,
        radiusMeters: 50,
        locationName: 'Head Office',
      );
      expect(result.isInside, isFalse);
      expect(result.message, contains('Head Office'));
    });

    test('missing company location is outside', () {
      final result = GeofenceHelper.evaluate(
        companyLocation: null,
        user: nearby,
      );
      expect(result.isInside, isFalse);
    });

    test('normalizeRadius defaults', () {
      expect(GeofenceHelper.normalizeRadius(null), kDefaultGeofenceRadiusMeters);
      expect(GeofenceHelper.normalizeRadius(0), kDefaultGeofenceRadiusMeters);
      expect(GeofenceHelper.normalizeRadius(80), 80);
    });
  });
}
