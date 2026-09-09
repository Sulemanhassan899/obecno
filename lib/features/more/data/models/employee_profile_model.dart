import 'package:obecno/core/api/constants.dart';

class LookupItem {
  const LookupItem({required this.id, required this.name});

  final String id;
  final String name;

  factory LookupItem.fromJson(Map<String, dynamic> json) {
    return LookupItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? json['label'] ?? '').toString(),
    );
  }

  static List<LookupItem> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => LookupItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}

class ProfileField {
  const ProfileField({required this.label, required this.value});

  final String label;
  final String value;

  factory ProfileField.fromJson(Map<String, dynamic> json) {
    return ProfileField(
      label: (json['label'] ?? json['title'] ?? json['name'] ?? '').toString(),
      value: (json['value'] ?? json['display'] ?? '—').toString(),
    );
  }
}

class EmployeeProfileModel {
  const EmployeeProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    this.designation,
    this.employeeCode,
    this.address,
    this.countryId,
    this.cityId,
    this.departmentId,
    this.department,
    this.countries = const [],
    this.cities = const [],
    this.departments = const [],
    this.profileFields = const [],
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final String? designation;
  final String? employeeCode;
  final String? address;
  final String? countryId;
  final String? cityId;
  final String? departmentId;

  /// Direct department name from the API when provided as a string
  /// (e.g. login/profile `"department": "Sales"`).
  final String? department;

  final List<LookupItem> countries;
  final List<LookupItem> cities;
  final List<LookupItem> departments;

  final List<ProfileField> profileFields;

  /// Resolved display name for the employee's department.
  String? get departmentName {
    final direct = _displayName(department);
    if (direct != null) return direct;

    if (departmentId != null && departmentId!.isNotEmpty) {
      for (final item in departments) {
        if (item.id == departmentId) {
          final name = _displayName(item.name);
          if (name != null) return name;
        }
      }
    }

    for (final field in profileFields) {
      final label = field.label.toLowerCase();
      if (label == 'department' || label.contains('department')) {
        final value = _displayName(field.value);
        if (value != null) return value;
      }
    }
    return null;
  }

  static String? _displayName(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty || value == '—' || value == '--' || value == '-') {
      return null;
    }
    return value;
  }

  static String? _readDepartmentName(
    Map<String, dynamic> profile,
    Map<String, dynamic> json,
    Map<String, dynamic> company,
  ) {
    String? fromRaw(dynamic raw) {
      if (raw == null) return null;
      if (raw is Map) {
        return fromRaw(
          raw['name'] ?? raw['title'] ?? raw['label'] ?? raw['department_title'],
        );
      }
      final asString = raw.toString().trim();
      if (asString.isEmpty ||
          asString == '—' ||
          asString == '--' ||
          asString == '-') {
        return null;
      }
      // Numeric-only strings are ids, not display names.
      if (int.tryParse(asString) != null) return null;
      return asString;
    }

    return fromRaw(profile['department'] ?? json['department']) ??
        fromRaw(profile['department_name'] ?? json['department_name']) ??
        fromRaw(profile['department_title'] ?? json['department_title']) ??
        fromRaw(company['department'] ?? company['department_name']);
  }

  factory EmployeeProfileModel.fromJson(Map<String, dynamic> json) {
    final profile = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;

    final company = json['company'] is Map<String, dynamic>
        ? json['company'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final reportsTo = json['reports_to'] is Map<String, dynamic>
        ? json['reports_to'] as Map<String, dynamic>
        : const <String, dynamic>{};

    String? designation = (profile['job_title'] ?? profile['designation'])
        ?.toString();

    final rawPhoto = (json['photo_url'] ?? profile['photo'])?.toString();

    final countries = LookupItem.listFrom(json['countries']);
    final cities = LookupItem.listFrom(json['cities']);
    final departments = LookupItem.listFrom(json['departments']);

    // Department may arrive as a plain string, an id, a nested object,
    // or manager-style `department_title`.
    String? departmentName = _readDepartmentName(profile, json, company);

    final profileFields = _buildProfileFields(
      json: json,
      profile: profile,
      company: company,
      reportsTo: reportsTo,
      lookups: {
        'country_id': countries,
        'city_id': cities,
        'department_id': departments,
      },
    );

    return EmployeeProfileModel(
      id: (profile['id'] ?? '').toString(),
      name: (profile['name'] ?? profile['title'] ?? '').toString(),
      email: (profile['email'] ?? '').toString(),
      phone: profile['phone']?.toString(),
      photoUrl: _absoluteUrl(rawPhoto),
      designation: designation,
      employeeCode: company['id']?.toString(),
      address: company['address']?.toString(),
      countryId: profile['country_id']?.toString(),
      cityId: profile['city_id']?.toString(),
      departmentId: profile['department_id']?.toString(),
      department: departmentName,
      countries: countries,
      cities: cities,
      departments: departments,
      profileFields: profileFields,
    );
  }

  static List<ProfileField> _buildProfileFields({
    required Map<String, dynamic> json,
    required Map<String, dynamic> profile,
    required Map<String, dynamic> company,
    required Map<String, dynamic> reportsTo,
    required Map<String, List<LookupItem>> lookups,
  }) {
    final rawFields = json['profile_fields'] ?? json['fields'];

    if (rawFields is List) {
      return rawFields
          .whereType<Map>()
          .map((e) => ProfileField.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }

    final merged = _merge(profile, company, reportsTo);
    final flat = _flatten(merged);
    final orderedKeys = _applyOrdering(flat, json['field_order']);

    final fields = <ProfileField>[];

    for (final key in orderedKeys) {
      if (_hiddenProfileKeys.contains(key)) continue;

      final value = flat[key];
      if (value == null || value.toString().trim().isEmpty) continue;

      String display;

      if (lookups.containsKey(key)) {
        final resolved = _resolveIdToLabel(value.toString(), lookups[key]!);
        if (resolved == null) continue;
        display = resolved;
      } else if (value is List) {
        display = value.join(', ');
      } else {
        display = value.toString();
      }

      fields.add(ProfileField(label: _humanizeKey(key), value: display));
    }

    return fields;
  }

  static Map<String, dynamic> _merge(
    Map<String, dynamic> user,
    Map<String, dynamic> company,
    Map<String, dynamic> reportsTo,
  ) {
    final Map<String, dynamic> merged = {};

    void add(String prefix, Map<String, dynamic> map) {
      map.forEach((k, v) {
        final key = prefix.isEmpty ? k : '${prefix}_$k';
        merged[key] = v;
      });
    }

    add('', user);
    add('company', company);
    add('reports_to', reportsTo);

    return merged;
  }

  static Map<String, dynamic> _flatten(Map<String, dynamic> input) {
    final Map<String, dynamic> flat = {};

    input.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        value.forEach((k, v) {
          flat['${key}_$k'] = v;
        });
      } else {
        flat[key] = value;
      }
    });

    return flat;
  }

  static List<String> _applyOrdering(
    Map<String, dynamic> data,
    List<dynamic>? order,
  ) {
    final keys = data.keys.toList();

    if (order == null) return keys;

    final ordered = <String>[];

    for (var k in order) {
      if (keys.contains(k)) ordered.add(k.toString());
    }

    for (var k in keys) {
      if (!ordered.contains(k)) ordered.add(k);
    }

    return ordered;
  }

  static String? _resolveIdToLabel(String? id, List<LookupItem> list) {
    if (id == null) return null;
    for (final item in list) {
      if (item.id == id) return item.name;
    }
    return null;
  }

  static String? _absoluteUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;

    final base = AppConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/${path.replaceFirst(RegExp(r'^/'), '')}';
  }

  static const Set<String> _hiddenProfileKeys = {
    'id',
    'name',
    'title',
    'photo',
    'photo_url',
    'avatar',
    'roles',
    'role_ids',
    'created_at',
    'updated_at',
    'deleted_at',
    'status',
  };

  static String _humanizeKey(String key) {
    return key
        .replaceAll('-', '_')
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
