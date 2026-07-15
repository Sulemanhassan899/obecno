/// GPS coordinates captured for a single attendance action.
///
/// Shape matches exactly what `POST /api/employee/attendance` accepts
/// (confirmed via the live swagger example: `lat`, `lon`, and a combined
/// `current_location` string of `"lat,lon"`).
class LocationModel {
  final double lat;
  final double lon;

  const LocationModel({required this.lat, required this.lon});

  String get currentLocation => '$lat,$lon';

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        'current_location': currentLocation,
      };

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
      );

  @override
  String toString() => 'LocationModel($currentLocation)';
}
