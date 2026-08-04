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
      cityName: json['city_name']?.toString(),
      countryName: json['country_name']?.toString(),
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
