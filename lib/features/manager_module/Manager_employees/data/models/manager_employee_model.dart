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
    this.departmentId,
    this.departmentTitle,
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
  final String? departmentId;
  final String? departmentTitle;
  final ManagerEmployeeStatus status;
  final ManagerEmployeeBadge badge;

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

    return ManagerEmployeeModel(
      id: _asString(json['id'] ?? json['user_id']),
      name: _asString(json['name'] ?? json['employee_name'] ?? json['title']),
      role: role.isEmpty ? 'Employee' : role,
      email: _asNullableString(json['email']),
      phone: _asNullableString(json['phone']),
      photo: _absoluteUrl(
        _asNullableString(json['photo_url'] ?? json['photo'] ?? json['avatar']),
      ),
      locationId: _asNullableString(
        json['location_id'] ?? json['office_id'] ?? json['default_location_id'],
      ),
      departmentId: _asNullableString(json['department_id']),
      departmentTitle: _asNullableString(
        json['department_title'] ?? json['department'],
      ),
      status: _parseStatus(
        json['status'] ?? json['account_status'] ?? json['status_label'],
      ),
      badge: _parseBadge(json['badge'] ?? json['job_title'] ?? json['role']),
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
    String? departmentId,
    String? departmentTitle,
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
      departmentId: departmentId ?? this.departmentId,
      departmentTitle: departmentTitle ?? this.departmentTitle,
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

String? _absoluteUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  final base = AppConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
  return '$base/${path.replaceFirst(RegExp(r'^/'), '')}';
}
