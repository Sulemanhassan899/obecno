class DeviceModel {
  final String id;
  final String deviceId;
  final String name;
  final String model;
  final String manufacturer;
  final String os;
  final String osVersion;
  final String appVersion;
  final String ipAddress;
  final String timezone;
  final String platform;
  final DateTime? lastActive;
  final DateTime? requestedAt;
  final String status;
  final bool isCurrent;
  final bool approvedFlag;

  /// Approver / rejector / blocker name when the API provides one.
  final String? actionedBy;

  /// Numeric user id from `actioned_by` when the API omits the name.
  final String? actionedById;

  DeviceModel({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.model,
    required this.manufacturer,
    required this.os,
    required this.osVersion,
    required this.appVersion,
    required this.ipAddress,
    required this.timezone,
    required this.platform,
    this.lastActive,
    this.requestedAt,
    this.status = '',
    this.isCurrent = false,
    this.approvedFlag = false,
    this.actionedBy,
    this.actionedById,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    // The approval state lives in `approval_status` (a string like
    // "approved"/"pending"/"blocked"). `status` is a *separate*,
    // numeric device-active flag (0/1) the backend also sends -- it must
    // never be treated as the approval string, or a plain "1" masks the
    // real "approved"/"pending"/"blocked" value.
    final nestedDevice = json['device'];
    final nestedName = nestedDevice is Map
        ? (nestedDevice['name'] ?? nestedDevice['device_name'])
        : nestedDevice is String
        ? nestedDevice
        : null;

    final approvalStatus = json['approval_status']?.toString().trim();
    final deviceStatus = json['device_status']?.toString().trim();
    final state = json['state']?.toString().trim();
    final rawStatus = json['status'];
    final rawStatusStr = rawStatus?.toString().trim();
    final rawStatusIsNumeric =
        rawStatusStr != null && int.tryParse(rawStatusStr) != null;

    final resolvedStatus = (approvalStatus?.isNotEmpty ?? false)
        ? approvalStatus!
        : (deviceStatus?.isNotEmpty ?? false)
        ? deviceStatus!
        : (state?.isNotEmpty ?? false)
        ? state!
        : (!rawStatusIsNumeric && (rawStatusStr?.isNotEmpty ?? false))
        ? rawStatusStr!
        : '';

    DateTime? parseDt(dynamic raw) => parseDateTime(raw);

    final actionedBy = _actionedByName(json);
    final actionedById = _actionedById(json);

    final id = _string(json['id'] ?? json['device_pk']);
    final deviceId = _string(
      json['device_id'] ?? json['mac_address'] ?? json['uuid'],
    );
    var name = _string(json['name'] ?? json['device_name'] ?? nestedName);
    if (name.isEmpty) {
      final details = _string(json['device_details'] ?? json['deviceDetails']);
      if (details.contains('|')) {
        name = details.split('|').first.trim();
      } else if (details.isNotEmpty) {
        name = details;
      }
    }

    return DeviceModel(
      id: id.isNotEmpty ? id : deviceId,
      // The backend doesn't always echo `device_id` -- it stores what we
      // sent as our device identifier under `mac_address` instead. Try
      // both so a device is still recognized as "this device".
      deviceId: deviceId.isNotEmpty ? deviceId : id,
      name: name,
      model: _string(json['model']),
      manufacturer: _string(json['manufacturer']),
      os: _string(json['os']),
      osVersion: _string(json['os_version']),
      appVersion: _string(json['app_version']),
      ipAddress: _string(json['ip_address']),
      timezone: _string(json['timezone']),
      platform: _string(json['platform'] ?? json['os']),
      lastActive: parseDt(
        json['last_active'] ??
            json['last_used'] ??
            json['updated_at'] ??
            json['updatedAt'],
      ),
      requestedAt: parseDt(
        json['requested_at'] ??
            json['request_date'] ??
            json['request_created_at'] ??
            json['created_at'] ??
            json['createdAt'] ??
            json['registered_at'] ??
            json['date'] ??
            json['timestamp'] ??
            json['created_on'] ??
            (nestedDevice is Map
                ? (nestedDevice['created_at'] ?? nestedDevice['createdAt'])
                : null),
      ),
      status: resolvedStatus,
      isCurrent: _asBool(json['is_current'] ?? json['current']),
      approvedFlag: _asBool(json['is_approved'] ?? json['approved']),
      actionedBy: (actionedBy?.isNotEmpty ?? false) ? actionedBy : null,
      actionedById: actionedById,
    );
  }

  static String? _actionedByName(Map<String, dynamic> json) {
    const keys = [
      'actioned_by_name',
      'approved_by_name',
      'rejected_by_name',
      'reviewed_by_name',
      'blocked_by_name',
      'approver_name',
      'reviewer_name',
      'actionedByName',
      'approvedByName',
      'actioned_by',
      'approved_by',
      'rejected_by',
      'reviewed_by',
      'blocked_by',
      'approver',
      'reviewer',
      'actioned_by_user',
      'approved_by_user',
    ];
    for (final key in keys) {
      final name = _personName(json[key]);
      if (name != null) return name;
    }
    return null;
  }

  static String? _actionedById(Map<String, dynamic> json) {
    const keys = [
      'actioned_by_id',
      'approved_by_id',
      'rejected_by_id',
      'reviewed_by_id',
      'blocked_by_id',
      'actioned_by',
      'approved_by',
      'rejected_by',
      'reviewed_by',
      'blocked_by',
      'approver',
      'reviewer',
    ];
    for (final key in keys) {
      final id = _personId(json[key]);
      if (id != null) return id;
    }
    return null;
  }

  static String? _personId(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return _personId(raw['id'] ?? raw['user_id'] ?? raw['userId']);
    }
    if (raw is num) return raw.toInt().toString();
    final value = raw.toString().trim();
    if (value.isEmpty) return null;
    return int.tryParse(value)?.toString();
  }

  static String? _personName(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return _personName(
        raw['name'] ??
            raw['full_name'] ??
            raw['fullName'] ??
            raw['display_name'] ??
            raw['username'] ??
            raw['email'] ??
            raw['title'],
      );
    }
    if (raw is num) return null;
    final value = raw.toString().trim();
    if (value.isEmpty || value.startsWith('{')) return null;
    if (int.tryParse(value) != null) return null;
    return value;
  }

  /// Collects device objects from any documented/legacy envelope, including
  /// nested `pending` / `approved` / `current_device` groups.
  static List<DeviceModel> listFromEnvelope(dynamic json) {
    final collected = <DeviceModel>[];
    final seen = <String>{};

    void add(DeviceModel device) {
      final key = [
        device.id,
        device.deviceId,
        device.name,
      ].where((value) => value.isNotEmpty).join('|');
      if (key.isEmpty) return;
      if (seen.add(key)) collected.add(device);
    }

    void walk(dynamic node, int depth) {
      if (node == null || depth > 8) return;
      if (node is List) {
        for (final item in node) {
          walk(item, depth + 1);
        }
        return;
      }
      if (node is! Map) return;
      final map = Map<String, dynamic>.from(node);
      if (_looksLikeDevice(map)) {
        add(DeviceModel.fromJson(map));
      }
      for (final value in map.values) {
        if (value is Map || value is List) walk(value, depth + 1);
      }
    }

    walk(json, 0);

    final namesById = _peopleById(json);
    if (namesById.isNotEmpty) {
      for (var i = 0; i < collected.length; i++) {
        final device = collected[i];
        if (device.actionedBy != null) continue;
        final id = device.actionedById;
        if (id == null) continue;
        final name = namesById[id];
        if (name != null) collected[i] = device.withActionedBy(name);
      }
    }

    return currentFirst(collected);
  }

  static Map<String, String> _peopleById(dynamic json) {
    final names = <String, String>{};

    void remember(dynamic raw) {
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final id = _personId(map) ?? _personId(map['user']);
        final name = _personName(map) ?? _personName(map['user']);
        if (id != null && name != null) names[id] = name;
        return;
      }
      if (raw is List) {
        for (final item in raw) {
          remember(item);
        }
      }
    }

    void walk(dynamic node, int depth) {
      if (node == null || depth > 6) return;
      if (node is List) {
        for (final item in node) {
          walk(item, depth + 1);
        }
        return;
      }
      if (node is! Map) return;
      final map = Map<String, dynamic>.from(node);
      for (final entry in map.entries) {
        final key = entry.key.toLowerCase();
        if (key == 'users' ||
            key == 'approvers' ||
            key == 'reviewers' ||
            key.contains('actioned_by') ||
            key.contains('approved_by')) {
          remember(entry.value);
        }
        if (entry.value is Map || entry.value is List) {
          walk(entry.value, depth + 1);
        }
      }
    }

    walk(json, 0);
    return names;
  }

  /// Current device first so Linked Devices always pins this phone at the top.
  static List<DeviceModel> currentFirst(List<DeviceModel> devices) {
    if (devices.length < 2) return devices;
    final current = <DeviceModel>[];
    final rest = <DeviceModel>[];
    for (final device in devices) {
      if (device.isCurrent) {
        current.add(device);
      } else {
        rest.add(device);
      }
    }
    if (current.isEmpty) return devices;
    return [...current, ...rest];
  }

  /// Pending requests first so a new device request is not buried under Active.
  static List<DeviceModel> pendingFirst(List<DeviceModel> devices) {
    if (devices.length < 2) return devices;
    final pending = <DeviceModel>[];
    final rest = <DeviceModel>[];
    for (final device in devices) {
      if (device.isPending) {
        pending.add(device);
      } else {
        rest.add(device);
      }
    }
    if (pending.isEmpty) return devices;
    return [...pending, ...rest];
  }

  static String _string(dynamic raw) => raw?.toString().trim() ?? '';

  static bool _asBool(dynamic raw) {
    if (raw == true || raw == 1) return true;
    if (raw == false || raw == 0 || raw == null) return false;
    final value = raw.toString().trim().toLowerCase();
    return value == '1' ||
        value == 'true' ||
        value == 'yes' ||
        value == 'approved';
  }

  static bool _looksLikeDevice(Map<String, dynamic> map) {
    if (map['devices'] is List ||
        map['permission_items'] is List ||
        map['members'] is List ||
        map['employees'] is List ||
        map['pending'] is List ||
        map['approved'] is List ||
        map['blocked'] is List ||
        map['rejected'] is List) {
      return false;
    }
    if (map.containsKey('mac_address') ||
        map.containsKey('device_id') ||
        map.containsKey('device_name') ||
        map.containsKey('approval_status') ||
        map.containsKey('is_approved') ||
        map.containsKey('is_current')) {
      return _string(map['name']).isNotEmpty ||
          _string(map['device_name']).isNotEmpty ||
          _string(map['device_id']).isNotEmpty ||
          _string(map['mac_address']).isNotEmpty ||
          _string(map['model']).isNotEmpty ||
          _string(map['id']).isNotEmpty ||
          _string(map['device_pk']).isNotEmpty ||
          (map['device'] is String && _string(map['device']).isNotEmpty) ||
          map['device'] is Map;
    }
    final approval = _string(map['approval_status']).toLowerCase();
    final status = _string(map['status']).toLowerCase();
    if ((_string(map['id']).isNotEmpty ||
            _string(map['device_pk']).isNotEmpty) &&
        (approval.contains('pending') ||
            approval.contains('requested') ||
            status.contains('pending') ||
            status.contains('requested') ||
            status == 'not approved' ||
            status == 'unapproved')) {
      return true;
    }
    if (map['device'] is String && _string(map['device']).isNotEmpty) {
      return true;
    }
    if (map['device'] is Map) {
      return true;
    }
    if (_string(map['name']).isEmpty) return false;
    return map.containsKey('platform') ||
        map.containsKey('os') ||
        map.containsKey('model') ||
        map.containsKey('manufacturer') ||
        map.containsKey('last_active') ||
        map.containsKey('last_used');
  }

  Map<String, dynamic> toJson() {
    return {
      "device_id": deviceId,
      "name": name,
      "model": model,
      "manufacturer": manufacturer,
      "os": os,
      "os_version": osVersion,
      "app_version": appVersion,
      "ip_address": ipAddress,
      "timezone": timezone,
      "platform": platform,
      'status': status,
      if (actionedBy != null) 'actioned_by': actionedBy,
      if (actionedById != null) 'actioned_by_id': actionedById,
      if (lastActive != null) 'last_active': lastActive!.toIso8601String(),
      if (requestedAt != null) 'requested_at': requestedAt!.toIso8601String(),
    };
  }

  /// Returns a copy with [isCurrent] recomputed against the device id of the
  /// device this app instance is running on. Used by DeviceProvider so the
  /// "current device" highlight in the Linked Devices screen works even if
  /// the backend doesn't echo an `is_current` flag.
  DeviceModel withTimestamps({DateTime? requestedAt, DateTime? lastActive}) {
    return DeviceModel(
      id: id,
      deviceId: deviceId,
      name: name,
      model: model,
      manufacturer: manufacturer,
      os: os,
      osVersion: osVersion,
      appVersion: appVersion,
      ipAddress: ipAddress,
      timezone: timezone,
      platform: platform,
      lastActive: lastActive ?? this.lastActive,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status,
      isCurrent: isCurrent,
      approvedFlag: approvedFlag,
      actionedBy: actionedBy,
      actionedById: actionedById,
    );
  }

  DeviceModel withCurrentFlag(bool value) {
    if (isCurrent == value) return this;
    return DeviceModel(
      id: id,
      deviceId: deviceId,
      name: name,
      model: model,
      manufacturer: manufacturer,
      os: os,
      osVersion: osVersion,
      appVersion: appVersion,
      ipAddress: ipAddress,
      timezone: timezone,
      platform: platform,
      lastActive: lastActive,
      requestedAt: requestedAt,
      status: status,
      isCurrent: value,
      approvedFlag: approvedFlag,
      actionedBy: actionedBy,
      actionedById: actionedById,
    );
  }

  /// True when [currentDeviceId] matches this row's `device_id` or server `id`.
  bool matchesDeviceId(String currentDeviceId) {
    final current = currentDeviceId.trim().toLowerCase();
    if (current.isEmpty) return false;
    if (deviceId.trim().toLowerCase() == current) return true;
    if (id.trim().toLowerCase() == current) return true;
    return false;
  }

  /// Same physical phone: stable id, or the same hardware when the backend
  /// doesn't echo our `device_id` (so login would otherwise POST a duplicate).
  bool matchesPhysicalDevice({
    required String currentDeviceId,
    String model = '',
    String manufacturer = '',
    String platform = '',
    String name = '',
  }) {
    if (matchesDeviceId(currentDeviceId)) return true;
    return _hardwareMatches(
      model: model,
      manufacturer: manufacturer,
      platform: platform,
      name: name,
    );
  }

  bool _hardwareMatches({
    required String model,
    required String manufacturer,
    required String platform,
    required String name,
  }) {
    if (!_platformCompatible(platform)) return false;

    final thisDisplay = displayName.trim().toLowerCase();
    final otherDisplay = DeviceDisplayName.resolve(
      name: name,
      model: model,
      manufacturer: manufacturer,
      platform: platform,
      os: platform,
    ).trim().toLowerCase();

    if (thisDisplay.isEmpty || otherDisplay.isEmpty) return false;
    if (thisDisplay == 'device' || otherDisplay == 'device') return false;
    if (thisDisplay == otherDisplay) return true;

    final thisModel = this.model.trim().toLowerCase();
    final otherModel = model.trim().toLowerCase();
    if (thisModel.isNotEmpty &&
        otherModel.isNotEmpty &&
        thisModel == otherModel) {
      return true;
    }
    return false;
  }

  bool _platformCompatible(String otherPlatform) {
    final a = _normalizePlatform(platform.isNotEmpty ? platform : os);
    final b = _normalizePlatform(otherPlatform);
    if (a.isEmpty || b.isEmpty) return true;
    return a == b;
  }

  static String _normalizePlatform(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return '';
    if (value.contains('android')) return 'android';
    if (value.contains('ios') ||
        value.contains('iphone') ||
        value.contains('ipad')) {
      return 'ios';
    }
    return value;
  }

  /// Pick this phone's row: exact id first, then an approved hardware match
  /// (so a new pending request is not treated as current over an Active A36).
  static DeviceModel? pickCurrent(
    List<DeviceModel> devices, {
    required String currentDeviceId,
    String model = '',
    String manufacturer = '',
    String platform = '',
    String name = '',
  }) {
    final matches = devices
        .where(
          (d) => d.matchesPhysicalDevice(
            currentDeviceId: currentDeviceId,
            model: model,
            manufacturer: manufacturer,
            platform: platform,
            name: name,
          ),
        )
        .toList();
    if (matches.isEmpty) return null;

    int rank(DeviceModel d) {
      final idMatch = d.matchesDeviceId(currentDeviceId);
      // Approved wins even over a newer pending row for the same phone,
      // so login does not keep treating an Active device as a new request.
      if (idMatch && d.isApproved) return 0;
      if (d.isApproved) return 1;
      if (idMatch && d.isPending) return 2;
      if (idMatch) return 3;
      if (d.isPending) return 4;
      return 5;
    }

    matches.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final aTime = a.lastActive ?? a.requestedAt;
      final bTime = b.lastActive ?? b.requestedAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return matches.first;
  }

  /// Marks exactly one row as current. Used after GET so an already-approved
  /// phone is recognized even when `device_id` on the server doesn't match.
  static List<DeviceModel> markCurrentDevice(
    List<DeviceModel> devices, {
    required String currentDeviceId,
    String model = '',
    String manufacturer = '',
    String platform = '',
    String name = '',
  }) {
    if (devices.isEmpty) return devices;
    final current = pickCurrent(
      devices,
      currentDeviceId: currentDeviceId,
      model: model,
      manufacturer: manufacturer,
      platform: platform,
      name: name,
    );
    if (current == null) {
      return devices
          .map((d) => d.isCurrent ? d.withCurrentFlag(false) : d)
          .toList(growable: false);
    }
    return [
      for (final d in devices)
        _isSameRow(d, current)
            ? d.withCurrentFlag(true)
            : d.withCurrentFlag(false),
    ];
  }

  static bool _isSameRow(DeviceModel a, DeviceModel b) {
    if (identical(a, b)) return true;
    if (a.id.isNotEmpty && a.id == b.id) return true;
    if (a.deviceId.isNotEmpty &&
        b.deviceId.isNotEmpty &&
        a.deviceId == b.deviceId &&
        (a.id == b.id || a.id.isEmpty || b.id.isEmpty)) {
      return true;
    }
    return false;
  }

  /// Already on the user's list — login must not POST another request.
  bool get hasExistingRegistration =>
      isApproved || isPending || isBlocked || isRejected;

  /// Returns a copy with [isCurrent] recomputed against the device id of the
  /// device this app instance is running on. Used by DeviceProvider so the
  /// "current device" highlight in the Linked Devices screen works even if
  /// the backend doesn't echo an `is_current` flag.
  DeviceModel markCurrent(String currentDeviceId) {
    if (!matchesDeviceId(currentDeviceId)) return this;
    if (isCurrent) return this;
    return withCurrentFlag(true);
  }

  DeviceModel withActionedBy(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return this;
    if (actionedBy == trimmed) return this;
    return DeviceModel(
      id: id,
      deviceId: deviceId,
      name: this.name,
      model: model,
      manufacturer: manufacturer,
      os: os,
      osVersion: osVersion,
      appVersion: appVersion,
      ipAddress: ipAddress,
      timezone: timezone,
      platform: platform,
      lastActive: lastActive,
      requestedAt: requestedAt,
      status: status,
      isCurrent: isCurrent,
      approvedFlag: approvedFlag,
      actionedBy: trimmed,
      actionedById: actionedById,
    );
  }

  String get normalizedStatus => status.toLowerCase().trim();

  String get displayName => DeviceDisplayName.resolve(
    name: name,
    model: model,
    manufacturer: manufacturer,
    platform: platform,
    os: os,
  );

  /// Date/time shown on the card. Pending uses the request time; otherwise
  /// last activity. Never null so the UI can always print a stamp.
  DateTime get cardTimestamp => requestedAt ?? lastActive ?? DateTime.now();

  /// Scenario 6: ONLY an explicit approved status counts.
  /// Pending / empty / "active" / request-already-sent must NOT be approved.
  bool get isApproved {
    if (normalizedStatus.contains('not approved') ||
        normalizedStatus.contains('not_approved') ||
        normalizedStatus == 'unapproved') {
      return false;
    }
    return approvedFlag || normalizedStatus == 'approved';
  }

  bool get isRejected =>
      !isApproved &&
      (normalizedStatus == 'rejected' || normalizedStatus.contains('rejected'));

  bool get isBlocked =>
      !isApproved &&
      !isRejected &&
      (normalizedStatus == 'blocked' ||
          normalizedStatus.contains('suspicious'));

  bool get isPending =>
      !isApproved &&
      !isBlocked &&
      !isRejected &&
      (normalizedStatus == 'pending' ||
          normalizedStatus.contains('pending') ||
          normalizedStatus.contains('awaiting') ||
          normalizedStatus.contains('not approved') ||
          normalizedStatus.contains('not_approved') ||
          normalizedStatus == 'unapproved' ||
          normalizedStatus.isEmpty ||
          normalizedStatus == 'registered' ||
          normalizedStatus == 'requested' ||
          normalizedStatus == 'request' ||
          normalizedStatus == 'active');

  /// UI badge label: Active | Pending | Blocked | Rejected
  String get statusLabel {
    if (isApproved) return 'Active';
    if (isPending) return 'Pending';
    if (isRejected) return 'Rejected';
    if (isBlocked) return 'Blocked';
    return 'Pending';
  }

  /// Cancel-request button: pending only, never Active.
  bool get showDeleteRequest => isPending;

  /// "Approved by: X" / "Rejected by: X" — never for pending, never an id.
  String? get actionedByLabel {
    if (isPending) return null;
    final by = actionedBy?.trim();
    if (by == null || by.isEmpty) return null;
    if (int.tryParse(by) != null) return null;
    if (isApproved) return 'Approved by: $by';
    if (isRejected) return 'Rejected by: $by';
    if (isBlocked) return 'Blocked by: $by';
    return null;
  }
}

/// Wraps the list payload returned by `GET /employee/devices`.
class DeviceListResponse {
  const DeviceListResponse(this.devices);

  final List<DeviceModel> devices;

  factory DeviceListResponse.fromJson(dynamic raw) {
    return DeviceListResponse(DeviceModel.listFromEnvelope(raw));
  }
}

/// Parses API timestamps: ISO, Laravel "YYYY-MM-DD HH:mm:ss", unix seconds
/// / milliseconds, and nested `{ date: ... }` objects.
DateTime? parseDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is num) return _dateTimeFromEpoch(raw);
  if (raw is Map) {
    return parseDateTime(
      raw['date'] ?? raw['datetime'] ?? raw['value'] ?? raw['timestamp'],
    );
  }

  final value = raw.toString().trim();
  if (value.isEmpty ||
      value == '—' ||
      value == '-' ||
      value == 'null' ||
      value == '0') {
    return null;
  }

  final iso =
      DateTime.tryParse(value) ??
      DateTime.tryParse(value.replaceFirst(' ', 'T'));
  if (iso != null) return iso;

  final asNum = num.tryParse(value);
  if (asNum != null) return _dateTimeFromEpoch(asNum);

  final dmy = RegExp(
    r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?',
  ).firstMatch(value);
  if (dmy != null) {
    final a = int.parse(dmy.group(1)!);
    final b = int.parse(dmy.group(2)!);
    final year = int.parse(dmy.group(3)!);
    final day = a > 12 ? a : b;
    final month = a > 12 ? b : a;
    return DateTime(
      year,
      month,
      day,
      int.tryParse(dmy.group(4) ?? '') ?? 0,
      int.tryParse(dmy.group(5) ?? '') ?? 0,
      int.tryParse(dmy.group(6) ?? '') ?? 0,
    );
  }
  return null;
}

DateTime? _dateTimeFromEpoch(num raw) {
  final n = raw.toInt();
  if (n <= 0) return null;
  if (n > 999999999999) {
    return DateTime.fromMillisecondsSinceEpoch(n, isUtc: true);
  }
  if (n > 999999999) {
    return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true);
  }
  return null;
}

/// Turns backend/OS device labels into a short name for Linked Devices.
///
/// Examples: `a36xq` / `SM-A366B` → `A36`, emulator codes → `Emulator`.
class DeviceDisplayName {
  DeviceDisplayName._();

  static String resolve({
    required String name,
    String model = '',
    String manufacturer = '',
    String platform = '',
    String os = '',
    bool? isEmulator,
  }) {
    if (isEmulator == true ||
        looksLikeEmulator(name) ||
        looksLikeEmulator(model)) {
      return 'Emulator';
    }

    final samsung = _samsungASeries(model) ?? _samsungASeries(name);
    if (samsung != null) return samsung;

    final strippedModel = _stripManufacturer(model, manufacturer);
    final strippedName = _stripManufacturer(name, manufacturer);

    if (_looksLikeCodename(name) && strippedModel.isNotEmpty) {
      return _samsungASeries(strippedModel) ?? strippedModel;
    }
    if (strippedName.isNotEmpty && !_looksLikeCodename(strippedName)) {
      return strippedName;
    }
    if (strippedModel.isNotEmpty) {
      return _samsungASeries(strippedModel) ?? strippedModel;
    }
    if (strippedName.isNotEmpty) return strippedName;
    if (name.trim().isNotEmpty) return name.trim();
    if (model.trim().isNotEmpty) return model.trim();
    return 'Device';
  }

  static bool looksLikeEmulator(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return false;
    return value.contains('emulator') ||
        value.contains('sdk_gphone') ||
        value.contains('sdk gphone') ||
        value.contains('google_sdk') ||
        value.contains('goldfish') ||
        value.contains('ranchu') ||
        value.contains('android sdk') ||
        value.startsWith('generic') ||
        value.startsWith('emu') ||
        value.contains('emulator64') ||
        RegExp(r'^emu\d').hasMatch(value);
  }

  static String? _samsungASeries(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final sm = RegExp(r'SM-A(\d{2})', caseSensitive: false).firstMatch(value);
    if (sm != null) return 'A${sm.group(1)}';
    final code = RegExp(
      r'^a(\d{2})[a-z0-9]*$',
      caseSensitive: false,
    ).firstMatch(value);
    if (code != null) return 'A${code.group(1)}';
    return null;
  }

  static bool _looksLikeCodename(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.contains(' ')) return false;
    return RegExp(r'^[a-z][a-z0-9]{2,}$').hasMatch(value);
  }

  static String _stripManufacturer(String raw, String manufacturer) {
    var value = raw.trim();
    final mfg = manufacturer.trim();
    if (value.isEmpty) return '';
    if (mfg.isNotEmpty && value.toLowerCase().startsWith(mfg.toLowerCase())) {
      value = value.substring(mfg.length).trim();
    }
    return value;
  }
}
