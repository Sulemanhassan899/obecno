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

  /// True when the value looks like an enabled/allowed toggle
  /// (e.g. "Allowed / On", "true", "1", "yes").
  bool get isEnabled {
    final v = value?.trim().toLowerCase();
    if (v == null || v.isEmpty) return false;
    if (v == '1' || v == 'true' || v == 'yes' || v == 'on') return true;
    if (v.contains('not allowed') || v.contains('/ off') || v == 'false') {
      return false;
    }
    return v.contains('allowed') || v.contains('/ on') || v == 'enabled';
  }

  factory PermissionItemModel.fromJson(Map<String, dynamic> json) {
    return PermissionItemModel(
      section: (json['section'] ?? '').toString(),
      sectionLabel: (json['section_label'] ?? '').toString(),
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      value: json['value']?.toString(),
      sourceLevel: json['source_level']?.toString(),
      isOverride:
          json['is_override'] == true ||
          json['is_override'] == 1 ||
          json['is_override']?.toString() == '1',
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

  /// Parses any known permissions envelope shape without throwing:
  /// - flat `permission_items` list
  /// - `sections` / list of `{key,label,items:[...]}`
  /// - nested login map `{attendance:{check_in_time:"..."}, ...}`
  /// - single section / item maps
  ///
  /// Unknown / future keys are preserved as dynamic items — never crash.
  static List<PermissionItemModel> listFromEnvelope(dynamic raw) {
    if (raw == null) return const [];

    // Prefer structured lists when present on a wrapper object.
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);

      final permissionItems = map['permission_items'];
      if (permissionItems is List && permissionItems.isNotEmpty) {
        final parsed = listFrom(permissionItems);
        if (parsed.isNotEmpty) return parsed;
      }

      final sections = map['sections'];
      if (sections is List && sections.isNotEmpty) {
        final parsed = _fromSectionsList(sections);
        if (parsed.isNotEmpty) return parsed;
      }

      final nested = map['permissions'];
      if (nested != null) {
        final parsed = listFromEnvelope(nested);
        if (parsed.isNotEmpty) return parsed;
      }

      // Nested policy map: { attendance: { check_in_time: "09:00 AM" }, ... }
      final fromNested = _fromNestedPolicyMap(map);
      if (fromNested.isNotEmpty) return fromNested;

      // Single section object with items, or a flat item.
      return _fromSectionsList([map]);
    }

    if (raw is List) {
      if (raw.isEmpty) return const [];
      // Flat permission_items style (objects with key + section).
      final first = raw.first;
      if (first is Map) {
        final firstMap = Map<String, dynamic>.from(first);
        if (firstMap.containsKey('items')) {
          return _fromSectionsList(raw);
        }
        if (firstMap.containsKey('key')) {
          return listFrom(raw);
        }
      }
      return _fromSectionsList(raw);
    }

    return const [];
  }

  static List<PermissionItemModel> _fromSectionsList(List<dynamic> sections) {
    final result = <PermissionItemModel>[];
    for (final section in sections) {
      if (section is! Map) continue;
      final sectionMap = Map<String, dynamic>.from(section);
      final items = sectionMap['items'];

      if (items is List) {
        final sectionKey = (sectionMap['key'] ?? '').toString();
        final sectionLabel = (sectionMap['label'] ?? humanizeKey(sectionKey))
            .toString();
        for (final item in items) {
          if (item is! Map) continue;
          final itemMap = Map<String, dynamic>.from(item);
          itemMap.putIfAbsent('section', () => sectionKey);
          itemMap.putIfAbsent('section_label', () => sectionLabel);
          if ((itemMap['label'] == null ||
                  itemMap['label'].toString().trim().isEmpty) &&
              itemMap['key'] != null) {
            itemMap['label'] = humanizeKey(itemMap['key'].toString());
          }
          result.add(PermissionItemModel.fromJson(itemMap));
        }
      } else if (sectionMap['key'] != null) {
        // Already a flat item.
        if ((sectionMap['label'] == null ||
                sectionMap['label'].toString().trim().isEmpty) &&
            sectionMap['key'] != null) {
          sectionMap['label'] = humanizeKey(sectionMap['key'].toString());
        }
        if ((sectionMap['section_label'] == null ||
                sectionMap['section_label'].toString().trim().isEmpty) &&
            sectionMap['section'] != null) {
          sectionMap['section_label'] = humanizeKey(
            sectionMap['section'].toString(),
          );
        }
        result.add(PermissionItemModel.fromJson(sectionMap));
      }
    }
    return result;
  }

  /// Converts login-style nested maps into permission items.
  ///
  /// Example input:
  /// `{ "attendance": { "check_in_time": "09:00 AM", ... }, ... }`
  static List<PermissionItemModel> _fromNestedPolicyMap(
    Map<String, dynamic> map,
  ) {
    // Skip wrappers that are clearly not section→policy maps.
    const skipKeys = {
      'company',
      'location',
      'overridden_keys',
      'location_overridden_keys',
      'employee_overridden_keys',
      'sections',
      'permission_items',
      'success',
      'message',
      'data',
    };

    final result = <PermissionItemModel>[];
    for (final entry in map.entries) {
      final sectionKey = entry.key.toString();
      if (skipKeys.contains(sectionKey)) continue;
      final sectionVal = entry.value;
      if (sectionVal is! Map) continue;

      final sectionMap = Map<String, dynamic>.from(sectionVal);
      // Structured section already handled elsewhere.
      if (sectionMap.containsKey('items') || sectionMap.containsKey('key')) {
        continue;
      }

      // Only treat as a policy map if values are scalars (String/num/bool/null).
      final looksLikePolicy = sectionMap.values.every(
        (v) => v == null || v is String || v is num || v is bool,
      );
      if (!looksLikePolicy) continue;

      final sectionLabel = humanizeKey(sectionKey);
      for (final item in sectionMap.entries) {
        final key = item.key.toString();
        result.add(
          PermissionItemModel(
            section: sectionKey,
            sectionLabel: sectionLabel,
            key: key,
            label: humanizeKey(key),
            value: item.value?.toString(),
            sourceLevel: 'company',
            isOverride: false,
          ),
        );
      }
    }
    return result;
  }

  /// True when this row is an employee-level override (not company/location).
  bool get hasEmployeeLevel {
    if (_isEmployeeSource(sourceLevel) || _isEmployeeSource(source)) {
      return true;
    }
    final value = employeeValue?.trim();
    return value != null && value.isNotEmpty;
  }

  static bool _isEmployeeSource(String? raw) {
    final value = raw?.trim().toLowerCase();
    return value == 'employee' || value == 'user';
  }

  /// True when any item is already stored as an employee-level permission.
  static bool hasEmployeeLevelPermissions(List<PermissionItemModel> items) {
    for (final item in items) {
      if (item.hasEmployeeLevel) return true;
    }
    return false;
  }

  /// Employee setting writes are partial (timing, break, days, grace).
  static String writeMethod({bool hasEmployeeLevel = true}) {
    return 'PATCH';
  }

  /// "check_in_time" → "Check in time", "leave_policies" → "Leave policies".
  static String humanizeKey(String key) {
    final cleaned = key.trim().replaceAll(RegExp(r'[_-]+'), ' ');
    if (cleaned.isEmpty) return key;
    return cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static Map<String, List<PermissionItemModel>> groupBySection(
    List<PermissionItemModel> items,
  ) {
    final grouped = <String, List<PermissionItemModel>>{};
    for (final item in items) {
      final sectionKey = item.section.isNotEmpty ? item.section : 'general';
      grouped.putIfAbsent(sectionKey, () => []).add(item);
    }
    return grouped;
  }
}
