import 'package:obecno/features/auth/data/models/auth_location_model.dart';
import 'package:obecno/shared/location/service/geofence_helper.dart';

class OfficeMatch {
  const OfficeMatch({
    required this.location,
    required this.distanceMeters,
    required this.isInside,
  });

  final AuthLocationModel location;
  final double distanceMeters;
  final bool isInside;
}

/// Matches the employee's current GPS point against assigned offices.
class OfficeGeofenceMatcher {
  OfficeGeofenceMatcher._();

  /// Assigned office whose geofence contains [user]. Closest wins on overlap.
  static OfficeMatch? bestInside({
    required List<AuthLocationModel> offices,
    required GeoPoint user,
  }) {
    OfficeMatch? best;
    for (final match in _rank(offices, user)) {
      if (!match.isInside) continue;
      if (best == null || match.distanceMeters < best.distanceMeters) {
        best = match;
      }
    }
    return best;
  }

  /// Closest assigned office with coordinates, even if outside its radius.
  static OfficeMatch? nearest({
    required List<AuthLocationModel> offices,
    required GeoPoint user,
  }) {
    OfficeMatch? best;
    for (final match in _rank(offices, user)) {
      if (!match.distanceMeters.isFinite) continue;
      if (best == null || match.distanceMeters < best.distanceMeters) {
        best = match;
      }
    }
    return best;
  }

  static Iterable<OfficeMatch> _rank(
    List<AuthLocationModel> offices,
    GeoPoint user,
  ) sync* {
    for (final office in offices) {
      final point = GeoPoint.tryParse(office.latLon);
      if (point == null) continue;
      final result = GeofenceHelper.evaluate(
        companyLocation: point,
        user: user,
        radiusMeters: office.radiusMeters,
        locationName: office.name,
      );
      yield OfficeMatch(
        location: office,
        distanceMeters: result.distanceMeters,
        isInside: result.isInside,
      );
    }
  }
}
