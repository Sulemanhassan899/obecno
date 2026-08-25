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

    DateTime? parseDt(dynamic raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    final actionedBy =
        (json['actioned_by'] ??
                json['approved_by'] ??
                json['rejected_by'] ??
                json['reviewed_by'] ??
                json['blocked_by'])
            ?.toString()
            .trim();

    final id = _string(json['id'] ?? json['device_pk']);
    final deviceId = _string(
      json['device_id'] ?? json['mac_address'] ?? json['uuid'],
    );
    final name = _string(
      json['name'] ?? json['device_name'] ?? nestedName,
    );

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
      lastActive: parseDt(json['last_active'] ?? json['last_used']),
      requestedAt: parseDt(
        json['requested_at'] ?? json['created_at'] ?? json['request_date'],
      ),
      status: resolvedStatus,
      isCurrent: _asBool(json['is_current'] ?? json['current']),
      approvedFlag: _asBool(json['is_approved'] ?? json['approved']),
      actionedBy: (actionedBy?.isNotEmpty ?? false) ? actionedBy : null,
    );
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
    return collected;
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
        map['employees'] is List) {
      return false;
    }
    if (map.containsKey('mac_address') ||
        map.containsKey('device_id') ||
        map.containsKey('device_name') ||
        map.containsKey('approval_status') ||
        map.containsKey('is_approved') ||
        map.containsKey('is_current')) {
      return true;
    }
    if (map['device'] is String && _string(map['device']).isNotEmpty) {
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
      if (lastActive != null) 'last_active': lastActive!.toIso8601String(),
      if (requestedAt != null) 'requested_at': requestedAt!.toIso8601String(),
    };
  }

  /// Returns a copy with [isCurrent] recomputed against the device id of the
  /// device this app instance is running on. Used by DeviceProvider so the
  /// "current device" highlight in the Linked Devices screen works even if
  /// the backend doesn't echo an `is_current` flag.
  DeviceModel markCurrent(String currentDeviceId) {
    if (deviceId.isEmpty || currentDeviceId.isEmpty) return this;
    if (deviceId != currentDeviceId) return this;
    if (isCurrent) return this;
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
      isCurrent: true,
      approvedFlag: approvedFlag,
      actionedBy: actionedBy,
    );
  }

  String get normalizedStatus => status.toLowerCase().trim();

  String get displayName => name.isNotEmpty ? name : model;

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
      (normalizedStatus == 'rejected' ||
          normalizedStatus.contains('rejected'));

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
          normalizedStatus == 'active');

  /// UI badge label: Active | Pending | Blocked | Rejected
  String get statusLabel {
    if (isApproved) return 'Active';
    if (isPending) return 'Pending';
    if (isRejected) return 'Rejected';
    if (isBlocked) return 'Blocked';
    return 'Pending';
  }

  /// "Approved by: X" / "Rejected by: X" — never for pending.
  String? get actionedByLabel {
    if (isPending) return null;
    final by = actionedBy?.trim();
    if (by == null || by.isEmpty) return null;
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
    if (raw is List) {
      return DeviceListResponse(
        raw
            .whereType<Map<String, dynamic>>()
            .map(DeviceModel.fromJson)
            .toList(growable: false),
      );
    }

    if (raw is Map<String, dynamic>) {
      final list = raw['devices'] ?? raw['data'];
      if (list is List) {
        return DeviceListResponse(
          list
              .whereType<Map<String, dynamic>>()
              .map(DeviceModel.fromJson)
              .toList(growable: false),
        );
      }
    }

    return const DeviceListResponse(<DeviceModel>[]);
  }
}
