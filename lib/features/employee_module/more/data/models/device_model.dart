class DeviceModel {
  final int id;
  final String name;
  final String type;
  final String status; // Active | Pending | Blocked
  final String? lastUsedAt;
  final String? requestedAt;
  final bool isCurrent;

  DeviceModel({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.lastUsedAt,
    this.requestedAt,
    this.isCurrent = false,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    final details = (json['device_details'] ?? '').toString();
    final rawType = (json['device_type'] ?? '').toString().trim();

    return DeviceModel(
      id: _parseId(json['id']),
      name: (json['device_name'] ?? json['name'] ?? '').toString(),
      type: rawType.isNotEmpty ? rawType : _inferTypeFromDetails(details),
      status: _titleCase((json['status'] ?? 'Pending').toString()),
      lastUsedAt: json['last_used_at']?.toString(),
      requestedAt: (json['requested_at'] ?? json['created_at'])?.toString(),
      isCurrent: json['is_current'] == true,
    );
  }

  static int _parseId(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static String _inferTypeFromDetails(String details) {
    final lower = details.toLowerCase();
    if (lower.contains('ios') ||
        lower.contains('iphone') ||
        lower.contains('ipad')) {
      return 'ios';
    }
    if (lower.contains('android')) return 'android';
    if (lower.contains('windows') ||
        lower.contains('macos') ||
        lower.contains('mac os') ||
        lower.contains('linux')) {
      return 'desktop';
    }
    return 'android';
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}
