class AuthLocationModel {
  const AuthLocationModel({
    required this.id,
    required this.name,
    this.latLon,
    this.address,
    this.city,
    this.country,
    this.cityId,
    this.countryId,
    this.timezone,
    this.timezoneId,
    this.image,
    this.isDefault = false,
    this.isActive = true,
    this.radiusMeters,
  });

  final String id;
  final String name;
  final String? latLon;
  final String? address;
  final String? city;
  final String? country;
  final Object? cityId;
  final Object? countryId;
  final String? timezone;
  final Object? timezoneId;
  final String? image;
  final bool isDefault;
  final bool isActive;
  final int? radiusMeters;

  String get displayAddress {
    if (address != null && address!.trim().isNotEmpty) return address!;
    final parts = [
      city,
      country,
    ].where((e) => e != null && e.trim().isNotEmpty);
    return parts.join(', ');
  }

  AuthLocationModel copyWith({
    String? id,
    String? name,
    String? latLon,
    String? address,
    String? city,
    String? country,
    Object? cityId,
    Object? countryId,
    String? timezone,
    Object? timezoneId,
    String? image,
    bool? isDefault,
    bool? isActive,
    int? radiusMeters,
  }) {
    return AuthLocationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      latLon: latLon ?? this.latLon,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      cityId: cityId ?? this.cityId,
      countryId: countryId ?? this.countryId,
      timezone: timezone ?? this.timezone,
      timezoneId: timezoneId ?? this.timezoneId,
      image: image ?? this.image,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      radiusMeters: radiusMeters ?? this.radiusMeters,
    );
  }

  factory AuthLocationModel.fromJson(Map<String, dynamic> json) {
    final rawImage = (json['photo_url'] ?? json['photo'])?.toString() ?? '';

    // 🔥 FIX: ensure full URL
    final image = rawImage.startsWith('http')
        ? rawImage
        : rawImage.isNotEmpty
        ? "https://app.obecno.com$rawImage"
        : '';

    final rawIsDefault =
        json['is_default'] ?? json['isDefault'] ?? json['default'];
    final isDefault =
        rawIsDefault == true ||
        rawIsDefault?.toString().toLowerCase() == 'true' ||
        rawIsDefault?.toString() == '1';

    final rawIsActive = json['is_active'] ?? json['isActive'] ?? json['active'];
    final isActive = rawIsActive == null
        ? true
        : rawIsActive == true ||
            rawIsActive.toString().toLowerCase() == 'true' ||
            rawIsActive.toString() == '1';

    final rawRadius =
        json['radius_meters'] ??
        json['radius'] ??
        json['geofence_radius'] ??
        json['allowed_radius'];
    final radiusMeters = rawRadius is num
        ? rawRadius.toInt()
        : int.tryParse(rawRadius?.toString() ?? '');

    return AuthLocationModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      latLon: json['lat_lon']?.toString(),
      address: json['address']?.toString(),
      city: _placeName(json['city'] ?? json['city_name']),
      country: _placeName(json['country'] ?? json['country_name']),
      cityId:
          _placeId(json['city_id']) ??
          (json['city'] is Map ? _placeId(json['city']) : null),
      countryId:
          _placeId(json['country_id']) ??
          (json['country'] is Map ? _placeId(json['country']) : null),
      timezone: _placeName(
        json['timezone_name'] ?? json['timezone'] ?? json['time_zone'],
      ),
      timezoneId: _placeId(
        json['timezone_id'] ??
            json['time_zone_id'] ??
            json['timezone'] ??
            json['time_zone'],
      ),
      image: image,
      isDefault: isDefault,
      isActive: isActive,
      radiusMeters: radiusMeters,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lat_lon': latLon,
    'address': address,
    'city': city,
    'country': country,
    'city_id': cityId,
    'country_id': countryId,
    'timezone': timezone,
    'timezone_id': timezoneId,
    'photo_url': image,
    'is_default': isDefault,
    'is_active': isActive,
    'radius_meters': radiusMeters,
  };

  static List<AuthLocationModel> listFrom(
    dynamic raw, {
    String? defaultLocationId,
  }) {
    if (raw is! List) return const [];
    final list = raw
        .whereType<Map>()
        .map((e) => AuthLocationModel.fromJson(Map<String, dynamic>.from(e)))
        .where((location) => location.isActive)
        .toList(growable: false);
    return applyDefaultFlag(list, defaultLocationId);
  }

  /// Marks the manager-assigned default office. Never uses the employee's
  /// working/selected location — that lives separately as selectedLocation.
  /// If the flagged default was deactivated/removed, promotes the next office.
  static List<AuthLocationModel> applyDefaultFlag(
    List<AuthLocationModel> locations, [
    String? defaultLocationId,
  ]) {
    if (locations.isEmpty) return locations;

    final active = [
      for (final location in locations)
        if (location.isActive) location,
    ];
    if (active.isEmpty) return const [];

    if (active.any((location) => location.isDefault)) return active;

    final defaultId = defaultLocationId?.trim();
    if (defaultId == null || defaultId.isEmpty) return active;

    final match = active.any((location) => location.id == defaultId);
    if (match) {
      return [
        for (final location in active)
          location.id == defaultId
              ? location.copyWith(isDefault: true)
              : location.copyWith(isDefault: false),
      ];
    }

    // Cached/API default points at a deactivated office — use the next one.
    return [
      for (var i = 0; i < active.length; i++)
        active[i].copyWith(isDefault: i == 0),
    ];
  }

  static AuthLocationModel? fromJsonOrNull(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if ((map['id'] == null || map['id'].toString().isEmpty) &&
        (map['name'] == null || map['name'].toString().isEmpty)) {
      return null;
    }
    return AuthLocationModel.fromJson(map);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthLocationModel &&
        other.id == id &&
        other.name == name &&
        other.latLon == latLon &&
        other.address == address &&
        other.city == city &&
        other.country == country &&
        other.cityId == cityId &&
        other.countryId == countryId &&
        other.timezone == timezone &&
        other.timezoneId == timezoneId &&
        other.image == image &&
        other.isDefault == isDefault &&
        other.isActive == isActive &&
        other.radiusMeters == radiusMeters;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      latLon,
      address,
      city,
      country,
      cityId,
      countryId,
      timezone,
      timezoneId,
      image,
      isDefault,
      isActive,
      radiusMeters,
    );
  }

  static bool isSameLocationList(
    List<AuthLocationModel> a,
    List<AuthLocationModel> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'AuthLocationModel(id: $id, name: $name)';
}

String? _placeName(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    return _placeName(raw['name'] ?? raw['title'] ?? raw['label']);
  }
  final value = raw.toString().trim();
  if (value.isEmpty) return null;
  if (int.tryParse(value) != null) return null;
  return value;
}

Object? _placeId(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) return _placeId(raw['id']);
  if (raw is num) return raw.toInt();
  final value = raw.toString().trim();
  if (value.isEmpty) return null;
  return int.tryParse(value);
}
