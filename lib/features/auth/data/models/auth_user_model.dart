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

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    // 🔥 FIX: handle nested "user"
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;

    // 🔥 FIX: extract role from roles array
    String? role;
    List<String> roleIds = const [];
    if (json['roles'] is List && (json['roles'] as List).isNotEmpty) {
      final roles = json['roles'] as List;
      role = roles.first.toString();
      roleIds = roles.map((e) => e.toString()).toList(growable: false);
    } else if (json['role'] != null) {
      role = json['role'].toString();
    }
    final company = AuthCompanyModel.fromJsonOrNull(json['company']);
    final locations = AuthLocationModel.listFrom(json['locations']);
    final token = TokenModel.fromJson(json);
    var permissions = PermissionItemModel.listFromEnvelope(json['permissions']);
    if (permissions.isEmpty && json['permission_sections'] != null) {
      permissions = PermissionItemModel.listFromEnvelope(
        json['permission_sections'],
      );
    }
    final permissionLocation = AuthLocationModel.fromJsonOrNull(
      json['permission_location'],
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
      isEmployee: json['is_employee'] as bool? ?? true,
      activeRoleView: json['active_role_view']?.toString(),
      canSwitchRoleView: json['can_switch_role_view'] == true,
      serverRememberMe: json['remember_me'] as bool? ?? true,
      permissionLocation: permissionLocation,
    );
  }

  @override
  String toString() =>
      'AuthUserModel(id: $id, name: $name, email: $email, role: $role, '
      'company: $company, locations: ${locations.length}, '
      'permissions: ${permissions.length}, hasToken: ${token != null})';
}
