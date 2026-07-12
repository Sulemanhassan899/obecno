/// Domain model for the logged-in user, produced by [AuthRepository] from
/// the raw `data` object inside the login response. Kept separate from the
/// raw JSON map so the rest of the app (provider, UI) never touches
/// backend field names directly.
class AuthUserModel {
  const AuthUserModel({
    required this.id,
    required this.name,
    required this.email,
    this.role,
  });

  final String id;
  final String name;
  final String email;
  final String? role;

  /// DTO -> Domain mapping. Backend field names (snake_case, alternate
  /// keys) are isolated here so a backend change means editing this one
  /// factory, not every call site.
  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      name: (json['name'] ?? json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: json['role']?.toString(),
    );
  }

  @override
  String toString() =>
      'AuthUserModel(id: $id, name: $name, email: $email, role: $role)';
}
