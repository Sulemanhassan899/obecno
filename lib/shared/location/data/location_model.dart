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
