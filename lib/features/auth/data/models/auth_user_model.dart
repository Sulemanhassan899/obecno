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

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    // 🔥 FIX: handle nested "user"
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;

    // 🔥 FIX: extract role from roles array 
    String? role;
    if (json['roles'] is List && (json['roles'] as List).isNotEmpty) {
      role = (json['roles'] as List).first.toString();
    } else if (json['role'] != null) {
      role = json['role'].toString();
    }

    return AuthUserModel(
      id: (user['id'] ?? user['user_id'] ?? '').toString(),
      name: (user['name'] ?? user['full_name'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      role: role,
    );
  }

  @override
  String toString() =>
      'AuthUserModel(id: $id, name: $name, email: $email, role: $role)';
}
