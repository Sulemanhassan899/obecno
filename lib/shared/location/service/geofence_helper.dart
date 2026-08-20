import 'package:geolocator/geolocator.dart';

const String kNotInOfficeRangeMessage = "Not in office range";

const List<int> kAllowedGeofenceRadiiMeters = [50];

const int kDefaultGeofenceRadiusMeters = 50;

class GeoPoint {
  final double lat;
  final double lon;

  const GeoPoint({required this.lat, required this.lon});

  static final RegExp _dmsToken = RegExp(
    r'''(\d+(?:\.\d+)?)\s*°\s*(\d+(?:\.\d+)?)\s*['′]\s*(?:(\d+(?:\.\d+)?)\s*["″])?\s*([NSEWnsew])''',
  );

  static GeoPoint? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    // Plain decimal "lat,lon" pair (e.g. "33.669,73.0719").
    final parts = raw.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0].trim());
      final lon = double.tryParse(parts[1].trim());
      if (lat != null && lon != null) return GeoPoint(lat: lat, lon: lon);
    }

    // DMS pair as returned by the API (e.g. 33°40'10.2"N 73°04'19.0"E).
    final matches = _dmsToken.allMatches(raw).toList();
    if (matches.length == 2) {
      double? lat, lon;
      for (final m in matches) {
        final deg = double.parse(m.group(1)!);
        final min = double.parse(m.group(2)!);
        final sec = double.tryParse(m.group(3) ?? '0') ?? 0;
        final hemi = m.group(4)!.toUpperCase();
        final decimal = deg + (min / 60) + (sec / 3600);
        final signed = (hemi == 'S' || hemi == 'W') ? -decimal : decimal;
        if (hemi == 'N' || hemi == 'S') {
          lat = signed;
        } else {
          lon = signed;
        }
      }
      if (lat != null && lon != null) return GeoPoint(lat: lat, lon: lon);
    }

    return null;
  }

  @override
  String toString() => '$lat,$lon';
}

class GeofenceResult {
  final bool isInside;
  final double distanceMeters;
  final int radiusMeters;
  final String? message;

  const GeofenceResult({
    required this.isInside,
    required this.distanceMeters,
    required this.radiusMeters,
    this.message,
  });
}

class GeofenceHelper {
  GeofenceHelper._();
  static int normalizeRadius(int? radiusMeters) {
    if (radiusMeters == null || radiusMeters <= 0) {
      return kDefaultGeofenceRadiusMeters;
    }
    return radiusMeters;
  }

  static double distanceMeters(GeoPoint from, GeoPoint to) {
    return Geolocator.distanceBetween(from.lat, from.lon, to.lat, to.lon);
  }

  static GeofenceResult evaluate({
    required GeoPoint? companyLocation,
    required GeoPoint user,
    int? radiusMeters,
    String? locationName,
  }) {
    final radius = normalizeRadius(radiusMeters);
    final notInRangeMsg =
        (locationName != null && locationName.trim().isNotEmpty)
        ? "Not in [${locationName.trim()}] range"
        : "Not in office range";

    if (companyLocation == null) {
      return GeofenceResult(
        isInside: false,
        distanceMeters: double.infinity,
        radiusMeters: radius,
        message: notInRangeMsg,
      );
    }

    final distance = distanceMeters(user, companyLocation);
    final inside = distance <= radius;

    return GeofenceResult(
      isInside: inside,
      distanceMeters: distance,
      radiusMeters: radius,
      message: inside ? null : notInRangeMsg,
    );
  }
}
