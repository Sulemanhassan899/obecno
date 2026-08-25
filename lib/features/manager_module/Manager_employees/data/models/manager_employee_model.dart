import 'package:obecno/core/api/constants.dart';
import 'package:obecno/core/generated/assets.dart';

enum ManagerEmployeeStatus { active, pending, disabled, deleted }

enum ManagerEmployeeBadge { none, owner, manager, you }

class ManagerEmployeeModel {
  const ManagerEmployeeModel({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.phone,
    this.photo,
    this.locationId,
    this.locationIds = const [],
    this.locationName,
    this.departmentId,
    this.departmentTitle,
    this.employeeCode,
    this.address,
    this.createdBy,
    this.createdAt,
    this.schedule,
    this.status = ManagerEmployeeStatus.active,
    this.badge = ManagerEmployeeBadge.none,
  });

  final String id;
  final String name;
  final String role;
  final String? email;
  final String? phone;
  final String? photo;
  final String? locationId;
  final List<String> locationIds;
  final String? locationName;
  final String? departmentId;
  final String? departmentTitle;
  final String? employeeCode;
  final String? address;
  final String? createdBy;
  final String? createdAt;
  final Map<String, dynamic>? schedule;
  final ManagerEmployeeStatus status;
  final ManagerEmployeeBadge badge;

  int? get userId => int.tryParse(id.trim());

  bool get isRegularEmployee {
    if (badge == ManagerEmployeeBadge.owner ||
        badge == ManagerEmployeeBadge.manager) {
      return false;
    }
    final value = role.trim().toLowerCase();
    return value.isEmpty || value == 'employee';
  }

  bool assignedToLocation({required String id, String? name}) {
    final selectedId = id.trim().toLowerCase();
    if (selectedId.isEmpty || selectedId == 'all') return true;

    if (locationId != null && locationId!.trim().toLowerCase() == selectedId) {
      return true;
    }
    for (final item in locationIds) {
      if (item.trim().toLowerCase() == selectedId) return true;
    }

    final selectedName = (name ?? '').trim().toLowerCase();
    if (selectedName.isEmpty) return false;
    return (locationName ?? '').trim().toLowerCase() == selectedName;
  }

  bool get hasNetworkPhoto =>
      photo != null && photo!.isNotEmpty && photo!.startsWith('http');

  String get photoPath => photo ?? Assets.imagesUserimage;

  String? get badgeLabel {
    switch (badge) {
      case ManagerEmployeeBadge.owner:
        return 'Owner';
      case ManagerEmployeeBadge.manager:
        return 'Manager';
      case ManagerEmployeeBadge.you:
        return 'You';
      case ManagerEmployeeBadge.none:
        return null;
    }
  }

  String? get statusLabel {
    switch (status) {
      case ManagerEmployeeStatus.pending:
        return 'Pending';
      case ManagerEmployeeStatus.disabled:
        return 'Disabled';
      case ManagerEmployeeStatus.deleted:
        return 'Deleted';
      case ManagerEmployeeStatus.active:
        return null;
    }
  }

  factory ManagerEmployeeModel.fromJson(Map<String, dynamic> json) {
    final role = _asString(
      json['job_title'] ??
          json['role'] ??
          json['designation'] ??
          json['department_title'],
    );

    final locationIds = _locationIdsFrom(json);
    final defaultLocationId = _asNullableString(
      json['default_location_id'] ?? json['location_id'] ?? json['office_id'],
    ) ?? _defaultIdFromLocations(json['locations']);
    final locationName = _asNullableString(
      json['location_name'] ??
          json['office_name'] ??
          json['default_location_name'] ??
          _nestedName(json['location'] ?? json['office'] ?? json['default_location']),
    );
    final createdByRaw = json['created_by'] ?? json['createdBy'];
    final scheduleRaw = json['schedule'];

    return ManagerEmployeeModel(
      id: _asString(json['id'] ?? json['user_id']),
      name: _asString(json['name'] ?? json['employee_name'] ?? json['title']),
      role: role.isEmpty ? 'Employee' : role,
      email: _asNullableString(json['email']),
      phone: _asNullableString(json['phone'] ?? json['phone_number']),
      photo: _absoluteUrl(
        _asNullableString(
          json['photo_url'] ??
              json['profile_picture'] ??
              json['photo'] ??
              json['avatar'],
        ),
      ),
      locationId: defaultLocationId ??
          (locationIds.isEmpty ? null : locationIds.first),
      locationIds: locationIds,
      locationName: locationName,
      departmentId: _asNullableString(json['department_id']),
      departmentTitle: _asNullableString(
        json['department_title'] ?? json['department'],
      ),
      employeeCode: _asNullableString(
        json['employee_code'] ??
            json['company_id'] ??
            json['staff_id'] ??
            json['employee_id_number'],
      ),
      address: _asNullableString(json['address'] ?? json['home_address']),
      createdBy: createdByRaw is Map
          ? _asNullableString(createdByRaw['name'] ?? createdByRaw['title'])
          : _asNullableString(createdByRaw),
      createdAt: _asNullableString(json['created_at'] ?? json['joining_date']),
      schedule: scheduleRaw is Map
          ? Map<String, dynamic>.from(scheduleRaw)
          : null,
      status: _parseStatus(
        json['status'] ?? json['account_status'] ?? json['status_label'],
      ),
      badge: _parseBadge(
        json['badge'] ?? json['job_title'] ?? json['role'] ?? json['name'],
      ),
    );
  }

  static List<ManagerEmployeeModel> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ManagerEmployeeModel.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  ManagerEmployeeModel copyWith({
    String? id,
    String? name,
    String? role,
    String? email,
    String? phone,
    String? photo,
    String? locationId,
    List<String>? locationIds,
    String? locationName,
    String? departmentId,
    String? departmentTitle,
    String? employeeCode,
    String? address,
    String? createdBy,
    String? createdAt,
    Map<String, dynamic>? schedule,
    ManagerEmployeeStatus? status,
    ManagerEmployeeBadge? badge,
  }) {
    return ManagerEmployeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photo: photo ?? this.photo,
      locationId: locationId ?? this.locationId,
      locationIds: locationIds ?? this.locationIds,
      locationName: locationName ?? this.locationName,
      departmentId: departmentId ?? this.departmentId,
      departmentTitle: departmentTitle ?? this.departmentTitle,
      employeeCode: employeeCode ?? this.employeeCode,
      address: address ?? this.address,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      schedule: schedule ?? this.schedule,
      status: status ?? this.status,
      badge: badge ?? this.badge,
    );
  }
}

class ManagerTeamMembersData {
  const ManagerTeamMembersData({this.total = 0, this.members = const []});

  final int total;
  final List<ManagerEmployeeModel> members;

  factory ManagerTeamMembersData.fromJson(Map<String, dynamic> json) {
    final members = ManagerEmployeeModel.listFrom(
      json['members'] ?? json['employees'] ?? json['data'],
    );
    return ManagerTeamMembersData(
      total: _asInt(json['total']) == 0
          ? members.length
          : _asInt(json['total']),
      members: members,
    );
  }
}

ManagerEmployeeStatus _parseStatus(dynamic raw) {
  final value = raw?.toString().trim().toLowerCase() ?? '';
  switch (value) {
    case '0':
    case 'pending':
    case 'p':
    case 'invited':
      return ManagerEmployeeStatus.pending;
    case '2':
    case 'disabled':
    case 'inactive':
    case 'deactivated':
      return ManagerEmployeeStatus.disabled;
    case '3':
    case 'deleted':
      return ManagerEmployeeStatus.deleted;
    case '1':
    case 'active':
    case 'enabled':
      return ManagerEmployeeStatus.active;
    default:
      return ManagerEmployeeStatus.active;
  }
}

ManagerEmployeeBadge _parseBadge(dynamic raw) {
  final value = raw?.toString().trim().toLowerCase() ?? '';
  switch (value) {
    case 'owner':
    case 'ceo':
      return ManagerEmployeeBadge.owner;
    case 'manager':
    case 'you':
      return value == 'you'
          ? ManagerEmployeeBadge.you
          : ManagerEmployeeBadge.manager;
    default:
      if (value.contains('manager')) return ManagerEmployeeBadge.manager;
      if (value.contains('owner') || value.contains('ceo')) {
        return ManagerEmployeeBadge.owner;
      }
      return ManagerEmployeeBadge.none;
  }
}

int _asInt(dynamic raw, {int fallback = 0}) {
  if (raw == null) return fallback;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString().trim()) ?? fallback;
}

String _asString(dynamic raw) => raw?.toString().trim() ?? '';

String? _asNullableString(dynamic raw) {
  if (raw == null) return null;
  final value = raw.toString().trim();
  return value.isEmpty ? null : value;
}

String? _nestedName(dynamic raw) {
  if (raw is Map) {
    return _asNullableString(raw['name'] ?? raw['title'] ?? raw['label']);
  }
  if (raw is String) return _asNullableString(raw);
  return null;
}

List<String> _locationIdsFrom(Map<String, dynamic> json) {
  final ids = <String>[];

  void add(dynamic raw) {
    final value = _asNullableString(raw);
    if (value == null) return;
    if (ids.any((id) => id.toLowerCase() == value.toLowerCase())) return;
    ids.add(value);
  }

  void addFrom(dynamic raw) {
    if (raw is Map) {
      add(raw['id'] ?? raw['location_id'] ?? raw['office_id']);
      return;
    }
    if (raw is List) {
      for (final item in raw) {
        addFrom(item);
      }
      return;
    }
    add(raw);
  }

  add(json['location_id'] ?? json['office_id'] ?? json['default_location_id']);
  addFrom(json['location_ids']);
  addFrom(json['locations']);
  addFrom(json['location'] ?? json['office'] ?? json['default_location']);
  return ids;
}

String? _defaultIdFromLocations(dynamic raw) {
  if (raw is! List) return null;
  String? firstId;
  for (final item in raw) {
    if (item is! Map) continue;
    final id = _asNullableString(
      item['id'] ?? item['location_id'] ?? item['office_id'],
    );
    if (id == null) continue;
    firstId ??= id;
    final isDefault = item['is_default'] == true ||
        item['is_default'] == 1 ||
        item['is_default']?.toString() == '1';
    if (isDefault) return id;
  }
  return firstId;
}

String? _absoluteUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  final base = AppConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
  return '$base/${path.replaceFirst(RegExp(r'^/'), '')}';
}
