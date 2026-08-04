class PermissionItemModel {
  const PermissionItemModel({
    required this.section,
    required this.sectionLabel,
    required this.key,
    required this.label,
    this.value,
    this.sourceLevel,
    this.isOverride = false,
    this.source,
    this.companyValue,
    this.locationValue,
    this.employeeValue,
    this.inheritedValue,
    this.locationName,
  });

  final String section;
  final String sectionLabel;
  final String key;
  final String label;
  final String? value;
  final String? sourceLevel;
  final bool isOverride;

  final String? source;
  final String? companyValue;
  final String? locationValue;
  final String? employeeValue;
  final String? inheritedValue;
  final String? locationName;

  factory PermissionItemModel.fromJson(Map<String, dynamic> json) {
    return PermissionItemModel(
      section: (json['section'] ?? '').toString(),
      sectionLabel: (json['section_label'] ?? '').toString(),
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      value: json['value']?.toString(),
      sourceLevel: json['source_level']?.toString(),
      isOverride: json['is_override'] == true,
      source: json['source']?.toString(),
      companyValue: json['company_value']?.toString(),
      locationValue: json['location_value']?.toString(),
      employeeValue: json['employee_value']?.toString(),
      inheritedValue: json['inherited_value']?.toString(),
      locationName: json['location_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'section': section,
    'section_label': sectionLabel,
    'key': key,
    'label': label,
    'value': value,
    'source_level': sourceLevel,
    'is_override': isOverride,
    'source': source,
    'company_value': companyValue,
    'location_value': locationValue,
    'employee_value': employeeValue,
    'inherited_value': inheritedValue,
    'location_name': locationName,
  };

  static List<PermissionItemModel> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => PermissionItemModel.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  static List<PermissionItemModel> listFromEnvelope(dynamic raw) {
    final sections = <dynamic>[];
    if (raw is Map) {
      sections.addAll(raw.values);
    } else if (raw is List) {
      sections.addAll(raw);
    } else {
      return const [];
    }

    final result = <PermissionItemModel>[];
    for (final section in sections) {
      if (section is! Map) continue;
      final sectionMap = Map<String, dynamic>.from(section);
      final items = sectionMap['items'];

      if (items is List) {
        final sectionKey = (sectionMap['key'] ?? '').toString();
        final sectionLabel = (sectionMap['label'] ?? '').toString();
        for (final item in items) {
          if (item is! Map) continue;
          final itemMap = Map<String, dynamic>.from(item);
          itemMap.putIfAbsent('section', () => sectionKey);
          itemMap.putIfAbsent('section_label', () => sectionLabel);
          result.add(PermissionItemModel.fromJson(itemMap));
        }
      } else if (sectionMap['key'] != null) {
        // No nested `items` -- this element is already a flat item.
        result.add(PermissionItemModel.fromJson(sectionMap));
      }
    }
    return result;
  }

  static Map<String, List<PermissionItemModel>> groupBySection(
    List<PermissionItemModel> items,
  ) {
    final grouped = <String, List<PermissionItemModel>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.section, () => []).add(item);
    }
    return grouped;
  }
}
