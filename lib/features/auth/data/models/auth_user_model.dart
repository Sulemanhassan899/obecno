import 'auth_company_model.dart';
import 'auth_location_model.dart';
import 'permission_item_model.dart';
import 'token_model.dart';

class AuthUserModel {
  const AuthUserModel({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.roleIds = const [],
    this.company,
    this.locations = const [],
    this.token,
    this.permissions = const [],
    this.isEmployee = true,
    this.activeRoleView,
    this.canSwitchRoleView = false,
    this.serverRememberMe = true,
    this.permissionLocation,
    this.department,
    this.joiningDate,
  });

  final String id;
  final String name;
  final String email;
  final String? role;

  final List<String> roleIds;

  final AuthCompanyModel? company;
  final List<AuthLocationModel> locations;

  final TokenModel? token;
  final List<PermissionItemModel> permissions;
  final bool isEmployee;
  final String? activeRoleView;
  final bool canSwitchRoleView;
  final bool serverRememberMe;

  final AuthLocationModel? permissionLocation;

  /// Department display name from login/profile (e.g. "Sales").
  final String? department;

  /// Calendar date from `user.joining_date` (YYYY-MM-DD). Date-only local
  /// midnight — never a UTC-shifted timestamp.
  final DateTime? joiningDate;

  /// Parses API date-only strings (`YYYY-MM-DD`) without timezone drift.
  static DateTime? parseDateOnly(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (match != null) {
      final y = int.tryParse(match.group(1)!);
      final m = int.tryParse(match.group(2)!);
      final d = int.tryParse(match.group(3)!);
      if (y == null || m == null || d == null) return null;
      if (m < 1 || m > 12 || d < 1 || d > 31) return null;
      return DateTime(y, m, d);
    }

    final parsed = DateTime.tryParse(s);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;

    String? role;
    List<String> roleIds = const [];
    final rawRoles = user['roles'] ?? json['roles'];
    if (rawRoles is List && rawRoles.isNotEmpty) {
      final roles = rawRoles;
      role = roles.first.toString();
      roleIds = roles.map((e) => e.toString()).toList(growable: false);
    } else if (user['role'] != null) {
      role = user['role'].toString();
    } else if (json['role'] != null) {
      role = json['role'].toString();
    }

    final company =
        AuthCompanyModel.fromJsonOrNull(user['company'] ?? json['company']) ??
        AuthCompanyModel.fromJsonOrNull({
          'id': user['company_id'] ?? json['company_id'],
          'name': user['company_name'] ?? json['company_name'],
        });
    final locations = AuthLocationModel.listFrom(
      user['locations'] ?? json['locations'],
    );
    final token = TokenModel.fromJson(json);
    // Login may send nested policy maps under `permissions`, or structured
    // `permission_sections` / `permission_items`. listFromEnvelope handles all.
    var permissions = PermissionItemModel.listFromEnvelope(
      json['permissions'] ?? json['data'],
    );
    if (permissions.isEmpty && json['permission_sections'] != null) {
      permissions = PermissionItemModel.listFromEnvelope(
        json['permission_sections'],
      );
    }
    if (permissions.isEmpty && json['permission_items'] != null) {
      permissions = PermissionItemModel.listFromEnvelope(
        json['permission_items'],
      );
    }
    final permissionLocation = AuthLocationModel.fromJsonOrNull(
      user['permission_location'] ?? json['permission_location'],
    );

    String? department;
    final rawDepartment = user['department'] ?? json['department'];
    if (rawDepartment is Map) {
      department =
          (rawDepartment['name'] ??
                  rawDepartment['title'] ??
                  rawDepartment['label'])
              ?.toString();
    } else if (rawDepartment != null) {
      final asString = rawDepartment.toString().trim();
      if (asString.isNotEmpty && int.tryParse(asString) == null) {
        department = asString;
      }
    }
    department ??=
        (user['department_name'] ?? json['department_name'])?.toString();

    final joiningDate = parseDateOnly(
      user['joining_date'] ?? json['joining_date'],
    );

    return AuthUserModel(
      id: (user['id'] ?? user['user_id'] ?? '').toString(),
      name: (user['name'] ?? user['full_name'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      role: role,
      roleIds: roleIds,
      company: company,
      locations: locations,
      token: token,
      permissions: permissions,
      isEmployee: (user['is_employee'] ?? json['is_employee']) as bool? ?? true,
      activeRoleView:
          (user['active_role_view'] ?? json['active_role_view'])?.toString(),
      canSwitchRoleView:
          (user['can_switch_role_view'] ?? json['can_switch_role_view']) == true,
      serverRememberMe: json['remember_me'] as bool? ?? true,
      permissionLocation: permissionLocation,
      department: department,
      joiningDate: joiningDate,
    );
  }

  @override
  String toString() =>
      'AuthUserModel(id: $id, name: $name, email: $email, role: $role, '
      'company: $company, locations: ${locations.length}, '
      'permissions: ${permissions.length}, hasToken: ${token != null})';
}