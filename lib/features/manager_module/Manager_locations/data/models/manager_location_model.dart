import 'package:obecno/core/api/constants.dart';
import 'package:obecno/core/generated/assets.dart';
import 'package:obecno/features/auth/data/models/auth_location_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';

class ManagerLocationModel {
  const ManagerLocationModel({
    required this.id,
    required this.name,
    required this.address,
    this.image,
    this.latitude,
    this.longitude,
    this.present = 0,
    this.total = 0,
    this.lateCheckIns = 0,
    this.createdBy = '',
    this.createdAt = '',
    this.radiusMeters,
    this.isDefault = false,
    this.isActive = true,
    this.allowCheckinAnywhere = false,
    this.schedule,
  });

  final String id;
  final String name;
  final String address;
  final String? image;
  final double? latitude;
  final double? longitude;
  final int present;
  final int total;
  final int lateCheckIns;
  final String createdBy;
  final String createdAt;
  final int? radiusMeters;
  final bool isDefault;
  final bool isActive;
  final bool allowCheckinAnywhere;
  final LocationSchedule? schedule;

  LocationSchedule get policy => schedule ?? LocationSchedule.defaults;

  bool get hasNetworkImage =>
      image != null && image!.isNotEmpty && image!.startsWith('http');

  String get imagePath => image ?? Assets.imagesDummyMaps;

  factory ManagerLocationModel.fromJson(Map<String, dynamic> json) {
    final lat = _asDouble(
      json['latitude'] ?? json['lat'] ?? _latLonPart(json['lat_lon'], 0),
    );
    final lon = _asDouble(
      json['longitude'] ?? json['lon'] ?? _latLonPart(json['lat_lon'], 1),
    );

    return ManagerLocationModel(
      id: _asString(json['id']),
      name: _asString(json['name'] ?? json['title']),
      address: _asString(
        json['address'] ??
            json['location_label'] ??
            [
                  json['city'],
                  json['city_name'],
                  json['country'],
                  json['country_name'],
                ]
                .where((e) => e != null && e.toString().trim().isNotEmpty)
                .join(', '),
      ),
      image: _absoluteUrl(
        _asNullableString(json['photo_url'] ?? json['photo'] ?? json['image']),
      ),
      latitude: lat,
      longitude: lon,
      present: _asInt(json['present_today'] ?? json['present']),
      total: _asInt(
        json['total_employees'] ?? json['total'] ?? json['team_size'],
      ),
      lateCheckIns: _asInt(
        json['late_check_ins'] ?? json['lateCheckIns'] ?? json['late'],
      ),
      createdBy: _personName(json['created_by'] ?? json['createdBy']),
      createdAt: _formatDate(json['created_at'] ?? json['createdAt']),
      radiusMeters: _asIntOrNull(
        json['radius_meters'] ?? json['radius'] ?? json['geofence_radius'],
      ),
      isDefault: _asBool(json['is_default'] ?? json['isDefault']),
      isActive: _asBool(json['is_active'], fallback: true),
      allowCheckinAnywhere: _asBool(json['allow_checkin_anywhere']),
      schedule: LocationSchedule.tryParse(json),
    );
  }

  factory ManagerLocationModel.fromAuth(AuthLocationModel location) {
    return ManagerLocationModel(
      id: location.id,
      name: location.name,
      address: location.displayAddress,
      image: (location.image == null || location.image!.isEmpty)
          ? null
          : location.image,
      latitude: _latLonPart(location.latLon, 0),
      longitude: _latLonPart(location.latLon, 1),
      isDefault: location.isDefault,
      radiusMeters: location.radiusMeters,
    );
  }

  static List<ManagerLocationModel> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ManagerLocationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  ManagerLocationModel copyWith({
    String? id,
    String? name,
    String? address,
    String? image,
    double? latitude,
    double? longitude,
    int? present,
    int? total,
    int? lateCheckIns,
    String? createdBy,
    String? createdAt,
    int? radiusMeters,
    bool? isDefault,
    bool? isActive,
    bool? allowCheckinAnywhere,
    LocationSchedule? schedule,
  }) {
    return ManagerLocationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      image: image ?? this.image,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      present: present ?? this.present,
      total: total ?? this.total,
      lateCheckIns: lateCheckIns ?? this.lateCheckIns,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      allowCheckinAnywhere: allowCheckinAnywhere ?? this.allowCheckinAnywhere,
      schedule: schedule ?? this.schedule,
    );
  }
}

double? _latLonPart(dynamic raw, int index) {
  if (raw == null) return null;
  final parts = raw.toString().split(',');
  if (parts.length <= index) return null;
  return double.tryParse(parts[index].trim());
}

int _asInt(dynamic raw, {int fallback = 0}) => _asIntOrNull(raw) ?? fallback;

int? _asIntOrNull(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString().trim());
}

double? _asDouble(dynamic raw) {
  if (raw == null) return null;
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString().trim());
}

bool _asBool(dynamic raw, {bool fallback = false}) {
  if (raw == true ||
      raw == 1 ||
      raw == '1' ||
      raw == 'true' ||
      raw == 'active') {
    return true;
  }
  if (raw == false ||
      raw == 0 ||
      raw == '0' ||
      raw == 'false' ||
      raw == 'inactive') {
    return false;
  }
  return fallback;
}

String _asString(dynamic raw) => raw?.toString().trim() ?? '';

String _personName(dynamic raw) {
  if (raw == null) return '';
  if (raw is Map) {
    return _asString(
      raw['name'] ?? raw['full_name'] ?? raw['title'] ?? raw['email'],
    );
  }
  return _asString(raw);
}

String? _asNullableString(dynamic raw) {
  if (raw == null) return null;
  final value = raw.toString().trim();
  return value.isEmpty ? null : value;
}

String _formatDate(dynamic raw) {
  if (raw == null) return '';
  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) return raw.toString().trim();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}

String? _absoluteUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  final base = AppConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
  return '$base/${path.replaceFirst(RegExp(r'^/'), '')}';
}
