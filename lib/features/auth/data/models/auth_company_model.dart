class AuthCompanyModel {
  const AuthCompanyModel({
    required this.id,
    required this.name,
    this.slug,
    this.website,
    this.description,
    this.teamSize,
    this.founded,
    this.expertise,
    this.cityName,
    this.countryName,
    this.cityId,
    this.countryId,
    this.timezone,
    this.timezoneId,
    this.locationLabel,
    this.photoUrl,
    this.status,
    this.statusLabel,
  });

  final String id;
  final String name;
  final String? slug;
  final String? website;
  final String? description;
  final String? teamSize;
  final String? founded;
  final String? expertise;
  final String? cityName;
  final String? countryName;
  final Object? cityId;
  final Object? countryId;
  final String? timezone;
  final Object? timezoneId;
  final String? locationLabel;
  final String? photoUrl;
  final String? status;
  final String? statusLabel;

  factory AuthCompanyModel.fromJson(Map<String, dynamic> json) {
    return AuthCompanyModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: json['slug']?.toString(),
      website: json['website']?.toString(),
      description: json['description']?.toString(),
      teamSize: json['team_size']?.toString(),
      founded: (json['founded'] ?? json['Founded'])?.toString(),
      expertise: json['expertise']?.toString(),
      cityName: (json['city_name'] ??
              (json['city'] is Map ? json['city']['name'] : json['city']))
          ?.toString(),
      countryName: (json['country_name'] ??
              (json['country'] is Map
                  ? json['country']['name']
                  : json['country']))
          ?.toString(),
      cityId: json['city_id'] ??
          (json['city'] is Map ? json['city']['id'] : null),
      countryId: json['country_id'] ??
          (json['country'] is Map ? json['country']['id'] : null),
      timezone: _companyTimezoneName(json),
      timezoneId: _companyTimezoneId(json),
      locationLabel: json['location_label']?.toString(),
      photoUrl: (json['photo_url'] ?? json['photo'])?.toString(),
      status: json['status']?.toString(),
      statusLabel: json['status_label']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'website': website,
    'description': description,
    'team_size': teamSize,
    'founded': founded,
    'expertise': expertise,
    'city_name': cityName,
    'country_name': countryName,
    'city_id': cityId,
    'country_id': countryId,
    'timezone': timezone,
    'timezone_id': timezoneId,
    'location_label': locationLabel,
    'photo_url': photoUrl,
    'status': status,
    'status_label': statusLabel,
  };

  static AuthCompanyModel? fromJsonOrNull(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if ((map['id'] == null || map['id'].toString().isEmpty) &&
        (map['name'] == null || map['name'].toString().isEmpty)) {
      return null;
    }
    return AuthCompanyModel.fromJson(map);
  }

  @override
  String toString() => 'AuthCompanyModel(id: $id, name: $name)';
}

String? _companyTimezoneName(Map<String, dynamic> json) {
  final raw =
      json['timezone_name'] ?? json['timezone'] ?? json['time_zone'];
  if (raw is Map) {
    return (raw['name'] ?? raw['iana'] ?? raw['label'] ?? raw['title'])
        ?.toString();
  }
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) return null;
  if (int.tryParse(value) != null) return null;
  return value;
}

Object? _companyTimezoneId(Map<String, dynamic> json) {
  final raw =
      json['timezone_id'] ??
      json['time_zone_id'] ??
      json['timezone'] ??
      json['time_zone'];
  if (raw is Map) return raw['id'] ?? raw['timezone_id'];
  if (raw is num) return raw.toInt();
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty || value.contains('/')) return null;
  return int.tryParse(value);
}
