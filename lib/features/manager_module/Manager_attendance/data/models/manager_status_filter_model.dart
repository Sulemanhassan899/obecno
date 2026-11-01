class ManagerStatusFilter {
  const ManagerStatusFilter({
    required this.key,
    required this.label,
    this.description,
    this.iconKey,
  });

  final String key;
  final String label;
  final String? description;
  final String? iconKey;

  factory ManagerStatusFilter.fromJson(Map<String, dynamic> json) {
    return ManagerStatusFilter(
      key: (json['key'] ?? json['id'] ?? json['value'] ?? '').toString().trim(),
      label:
          (json['label'] ?? json['title'] ?? json['name'] ?? json['key'] ?? '')
              .toString()
              .trim(),
      description: (json['description'] as String?)?.trim(),
      iconKey: (json['icon_key'] ?? json['iconKey'] ?? json['icon'])
          ?.toString()
          .trim(),
    );
  }

  static List<ManagerStatusFilter> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ManagerStatusFilter.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.key.isNotEmpty)
        .toList(growable: false);
  }
}
