import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/auth/data/models/auth_location_model.dart';
import 'package:obecno/shared/location/service/geofence_helper.dart';
import 'package:obecno/shared/location/service/office_geofence_matcher.dart';

void main() {
  const head = AuthLocationModel(
    id: '1',
    name: 'Head Office',
    latLon: '33.67,73.07',
    radiusMeters: 50,
    isDefault: true,
  );
  const north = AuthLocationModel(
    id: '2',
    name: 'North Office',
    latLon: '33.68,73.08',
    radiusMeters: 50,
  );
  const offices = [head, north];

  group('OfficeGeofenceMatcher.bestInside', () {
    test('selects the assigned office whose geofence contains the user', () {
      const user = GeoPoint(lat: 33.6701, lon: 73.0701);
      final match = OfficeGeofenceMatcher.bestInside(
        offices: offices,
        user: user,
      );
      expect(match?.location.id, '1');
      expect(match?.isInside, isTrue);
    });

    test('selects the closer office when geofences overlap', () {
      const overlappingHead = AuthLocationModel(
        id: '1',
        name: 'Head Office',
        latLon: '33.67,73.07',
        radiusMeters: 500,
      );
      const overlappingNorth = AuthLocationModel(
        id: '2',
        name: 'North Office',
        latLon: '33.6702,73.0702',
        radiusMeters: 500,
      );
      const user = GeoPoint(lat: 33.6702, lon: 73.0702);
      final match = OfficeGeofenceMatcher.bestInside(
        offices: [overlappingHead, overlappingNorth],
        user: user,
      );
      expect(match?.location.id, '2');
    });

    test('returns null when the user is outside every assigned office', () {
      const user = GeoPoint(lat: 34.0, lon: 74.0);
      final match = OfficeGeofenceMatcher.bestInside(
        offices: offices,
        user: user,
      );
      expect(match, isNull);
    });

    test('skips offices without coordinates', () {
      const noGps = AuthLocationModel(id: '3', name: 'Service Works');
      const user = GeoPoint(lat: 33.6701, lon: 73.0701);
      final match = OfficeGeofenceMatcher.bestInside(
        offices: [noGps, head],
        user: user,
      );
      expect(match?.location.id, '1');
    });
  });
}
