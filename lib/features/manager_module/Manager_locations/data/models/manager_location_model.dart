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
    this.timezone,
    this.timezoneId,
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
  final String? timezone;
  final Object? timezoneId;
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
      timezone: _timezoneNameFrom(json),
      timezoneId: ManagerLocationModel.timezoneIdFrom(
        json['timezone_id'] ??
            json['time_zone_id'] ??
            json['timezone'] ??
            json['time_zone'],
      ),
      schedule: LocationSchedule.tryParse(json),
    );
  }

  /// Body for `POST /manager/locations`.
  ///
  /// The New Location sheet only collects a name, but the API still requires
  /// address / lat / lng / radius (see manager spec §13.1).
  static const defaultLatitude = 52.4862;
  static const defaultLongitude = -1.8904;
  static const defaultRadiusMeters = 250;
  static const defaultCity = 'Birmingham';
  static const defaultCountry = 'United Kingdom';
  static const defaultTimezone = 'Europe/London';

  static String timezoneFor({
    String? timezone,
    String? city,
    String? country,
  }) {
    final explicit = timezone?.trim() ?? '';
    if (explicit.contains('/')) return explicit;

    final haystack = '$explicit ${city ?? ''} ${country ?? ''}'.toLowerCase();
    if (haystack.contains('pakistan') ||
        haystack.contains('islamabad') ||
        haystack.contains('karachi') ||
        haystack.contains('lahore')) {
      return 'Asia/Karachi';
    }
    if (haystack.contains('dubai') ||
        haystack.contains('emirates') ||
        haystack.contains('uae')) {
      return 'Asia/Dubai';
    }
    if (haystack.contains('london') ||
        haystack.contains('birmingham') ||
        haystack.contains('united kingdom') ||
        haystack.contains('england')) {
      return 'Europe/London';
    }
    if (explicit.isNotEmpty) return explicit;
    return defaultTimezone;
  }

  /// Numeric / UUID timezone row id. IANA names like `Europe/London` are
  /// not ids — Laravel `exists:timezones,id` rejects those.
  static Object? timezoneIdFrom(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return timezoneIdFrom(
        raw['id'] ?? raw['timezone_id'] ?? raw['time_zone_id'] ?? raw['value'],
      );
    }
    if (raw is num) return raw.toInt();
    final value = raw.toString().trim();
    if (value.isEmpty || value.contains('/')) return null;
    return int.tryParse(value) ?? (value.contains('-') ? value : null);
  }

  static Map<String, dynamic> createPayload({
    required String name,
    String? address,
    double? latitude,
    double? longitude,
    int radiusMeters = defaultRadiusMeters,
    String? city,
    String? country,
    Object? cityId,
    Object? countryId,
    String? timezone,
    Object? timezoneId,
  }) {
    final trimmedName = name.trim();
    final trimmedAddress = address?.trim() ?? '';
    final lat = latitude ?? defaultLatitude;
    final lng = longitude ?? defaultLongitude;
    final resolvedCity = (city ?? '').trim().isEmpty
        ? defaultCity
        : city!.trim();
    final resolvedCountry = (country ?? '').trim().isEmpty
        ? defaultCountry
        : country!.trim();
    final resolvedTimezone = timezoneFor(
      timezone: timezone,
      city: resolvedCity,
      country: resolvedCountry,
    );
    final tzId = timezoneIdFrom(timezoneId);
    final tzValue = tzId ?? resolvedTimezone;
    return {
      'name': trimmedName,
      'title': trimmedName,
      'address': trimmedAddress.isEmpty ? trimmedName : trimmedAddress,
      'latitude': lat,
      'longitude': lng,
      'lat_lon': '$lat,$lng',
      'radius_meters': radiusMeters,
      'city': resolvedCity,
      'city_name': resolvedCity,
      'country': resolvedCountry,
      'country_name': resolvedCountry,
      if (cityId != null) 'city_id': cityId,
      if (countryId != null) 'country_id': countryId,
      'timezone': tzValue,
      'time_zone': tzValue,
      'timeZone': tzValue,
      'timezone_id': tzValue,
      'time_zone_id': tzValue,
      'timeZoneId': tzValue,
      'timezone_name': resolvedTimezone,
    };
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
      timezone: location.timezone,
      timezoneId: location.timezoneId,
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
    String? timezone,
    Object? timezoneId,
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
      timezone: timezone ?? this.timezone,
      timezoneId: timezoneId ?? this.timezoneId,
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

String? _timezoneNameFrom(Map<String, dynamic> json) {
  final raw =
      json['timezone_name'] ?? json['timezone'] ?? json['time_zone'];
  if (raw is Map) {
    return _asNullableString(raw['name'] ?? raw['iana'] ?? raw['label']);
  }
  final value = _asNullableString(raw);
  if (value == null || int.tryParse(value) != null) return null;
  return value;
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

class TimezoneLookup {
  const TimezoneLookup({required this.id, required this.label});

  final Object id;
  final String label;

  factory TimezoneLookup.fromJson(Map<String, dynamic> json) {
    final id =
        json['id'] ??
        json['timezone_id'] ??
        json['time_zone_id'] ??
        json['value'] ??
        json['iana'] ??
        json['name'];
    final label =
        (json['iana'] ??
                json['name'] ??
                json['timezone'] ??
                json['time_zone'] ??
                json['label'] ??
                json['title'] ??
                json['value'] ??
                id)
            ?.toString()
            .trim() ??
        '';
    return TimezoneLookup(
      id: id is num ? id.toInt() : id,
      label: label,
    );
  }

  static Object? matchId(
    List<TimezoneLookup> options, {
    required String iana,
    String? city,
    String? country,
  }) {
    if (options.isEmpty) return null;

    String norm(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9/]+'), '');

    bool matches(TimezoneLookup option, String needle) {
      if (needle.isEmpty) return false;
      final label = norm(option.label);
      final id = norm(option.id.toString());
      return label == needle ||
          id == needle ||
          label.contains(needle) ||
          needle.contains(label);
    }

    final ianaN = norm(iana);
    for (final option in options) {
      if (matches(option, ianaN)) return option.id;
    }

    final inferred = ManagerLocationModel.timezoneFor(
      timezone: iana,
      city: city,
      country: country,
    );
    final inferredN = norm(inferred);
    if (inferredN != ianaN) {
      for (final option in options) {
        if (matches(option, inferredN)) return option.id;
      }
    }

    final haystack = '${city ?? ''} ${country ?? ''}'.toLowerCase();
    for (final option in options) {
      final label = option.label.toLowerCase();
      if ((haystack.contains('pakistan') ||
              haystack.contains('islamabad') ||
              haystack.contains('karachi')) &&
          (label.contains('karachi') || label.contains('pakistan'))) {
        return option.id;
      }
      if ((haystack.contains('kingdom') ||
              haystack.contains('london') ||
              haystack.contains('birmingham') ||
              haystack.contains('england')) &&
          (label.contains('london') || label.contains('britain'))) {
        return option.id;
      }
    }

    return options.first.id;
  }
}
