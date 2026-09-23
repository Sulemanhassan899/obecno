enum LocationFlagSyncStatus { local, pending, syncing, synced, failed }

enum LocationCaptureStatus {
  available,
  unavailable,
  permissionDenied,
  serviceDisabled,
  accuracyTooLow,
  mockDetected,
  timeout,
}

enum LocationFlagUiStatus {
  notCheckedIn,
  inOffice,
  locationIssue,
  locationUnavailable,
}

class LocationFlagRecord {
  const LocationFlagRecord({
    required this.id,
    required this.employeeId,
    required this.date,
    this.latitude,
    this.longitude,
    required this.timestamp,
    this.locationAccuracy,
    this.assignedLocationId,
    this.officeLatitude,
    this.officeLongitude,
    this.allowedRadius,
    this.distance,
    required this.checkInStatus,
    required this.breakStatus,
    required this.checkOutStatus,
    required this.locationStatus,
    this.insideRadius,
    required this.flagNumber,
    required this.cycleId,
    this.hourFlags = const <bool?>[],
    required this.requiresServerSync,
    required this.syncStatus,
    this.syncAttemptCount = 0,
    this.lastSyncAttempt,
    this.serverSyncedAt,
    required this.createdTimestamp,
  });

  final String id;
  final String employeeId;
  final String date;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;
  final double? locationAccuracy;
  final String? assignedLocationId;
  final double? officeLatitude;
  final double? officeLongitude;
  final double? allowedRadius;
  final double? distance;
  final bool checkInStatus;
  final bool breakStatus;
  final bool checkOutStatus;
  final LocationCaptureStatus locationStatus;
  final bool? insideRadius;
  final int flagNumber;
  final String cycleId;
  final List<bool?> hourFlags;
  final bool requiresServerSync;
  final LocationFlagSyncStatus syncStatus;
  final int syncAttemptCount;
  final DateTime? lastSyncAttempt;
  final DateTime? serverSyncedAt;
  final DateTime createdTimestamp;

  bool get isWorkingTime =>
      checkInStatus && !breakStatus && !checkOutStatus;

  LocationFlagRecord copyWith({
    bool? requiresServerSync,
    LocationFlagSyncStatus? syncStatus,
    int? syncAttemptCount,
    DateTime? lastSyncAttempt,
    DateTime? serverSyncedAt,
    List<bool?>? hourFlags,
  }) {
    return LocationFlagRecord(
      id: id,
      employeeId: employeeId,
      date: date,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      locationAccuracy: locationAccuracy,
      assignedLocationId: assignedLocationId,
      officeLatitude: officeLatitude,
      officeLongitude: officeLongitude,
      allowedRadius: allowedRadius,
      distance: distance,
      checkInStatus: checkInStatus,
      breakStatus: breakStatus,
      checkOutStatus: checkOutStatus,
      locationStatus: locationStatus,
      insideRadius: insideRadius,
      flagNumber: flagNumber,
      cycleId: cycleId,
      hourFlags: hourFlags ?? this.hourFlags,
      requiresServerSync: requiresServerSync ?? this.requiresServerSync,
      syncStatus: syncStatus ?? this.syncStatus,
      syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      serverSyncedAt: serverSyncedAt ?? this.serverSyncedAt,
      createdTimestamp: createdTimestamp,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'employee_id': employeeId,
    'date': date,
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toIso8601String(),
    'location_accuracy': locationAccuracy,
    'assigned_location_id': assignedLocationId,
    'office_latitude': officeLatitude,
    'office_longitude': officeLongitude,
    'allowed_radius': allowedRadius,
    'distance': distance,
    'check_in_status': checkInStatus ? 1 : 0,
    'break_status': breakStatus ? 1 : 0,
    'check_out_status': checkOutStatus ? 1 : 0,
    'location_status': locationStatus.name,
    'inside_radius': _boolToSql(insideRadius),
    'flag_number': flagNumber,
    'cycle_id': cycleId,
    for (var i = 0; i < _hourFlagColumns; i++)
      'flag_${i + 1}': _boolToSql(i < hourFlags.length ? hourFlags[i] : null),
    'requires_server_sync': requiresServerSync ? 1 : 0,
    'sync_status': syncStatus.name,
    'sync_attempt_count': syncAttemptCount,
    'last_sync_attempt': lastSyncAttempt?.toIso8601String(),
    'server_synced_at': serverSyncedAt?.toIso8601String(),
    'created_timestamp': createdTimestamp.toIso8601String(),
  };

  factory LocationFlagRecord.fromMap(Map<String, dynamic> map) {
    return LocationFlagRecord(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      date: map['date'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      locationAccuracy: (map['location_accuracy'] as num?)?.toDouble(),
      assignedLocationId: map['assigned_location_id'] as String?,
      officeLatitude: (map['office_latitude'] as num?)?.toDouble(),
      officeLongitude: (map['office_longitude'] as num?)?.toDouble(),
      allowedRadius: (map['allowed_radius'] as num?)?.toDouble(),
      distance: (map['distance'] as num?)?.toDouble(),
      checkInStatus: (map['check_in_status'] as int? ?? 0) == 1,
      breakStatus: (map['break_status'] as int? ?? 0) == 1,
      checkOutStatus: (map['check_out_status'] as int? ?? 0) == 1,
      locationStatus: LocationCaptureStatus.values.firstWhere(
        (e) => e.name == map['location_status'],
        orElse: () => LocationCaptureStatus.unavailable,
      ),
      insideRadius: _sqlToBool(map['inside_radius']),
      flagNumber: map['flag_number'] as int,
      cycleId: map['cycle_id'] as String,
      hourFlags: [
        for (var i = 0; i < _hourFlagColumns; i++)
          _sqlToBool(map['flag_${i + 1}']),
      ],
      requiresServerSync: (map['requires_server_sync'] as int? ?? 0) == 1,
      syncStatus: LocationFlagSyncStatus.values.firstWhere(
        (e) => e.name == map['sync_status'],
        orElse: () => LocationFlagSyncStatus.local,
      ),
      syncAttemptCount: map['sync_attempt_count'] as int? ?? 0,
      lastSyncAttempt: _parseDate(map['last_sync_attempt']),
      serverSyncedAt: _parseDate(map['server_synced_at']),
      createdTimestamp: DateTime.parse(map['created_timestamp'] as String),
    );
  }

  Map<String, dynamic> toSyncPayload() => {
    'event_id': id,
    'employee_id': employeeId,
    'date': date,
    'timestamp': timestamp.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'location_accuracy': locationAccuracy,
    'assigned_location_id': assignedLocationId,
    'office_latitude': officeLatitude,
    'office_longitude': officeLongitude,
    'allowed_radius': allowedRadius,
    'distance': distance,
    'check_in_status': checkInStatus,
    'break_status': breakStatus,
    'check_out_status': checkOutStatus,
    'location_status': locationStatus.name,
    'inside_radius': insideRadius,
    'flag_number': flagNumber,
    'cycle_id': cycleId,
    for (var i = 0; i < _hourFlagColumns; i++)
      'flag_${i + 1}': i < hourFlags.length ? hourFlags[i] : null,
  };

  static const int _hourFlagColumns = 12;

  static int? _boolToSql(bool? value) {
    if (value == null) return null;
    return value ? 1 : 0;
  }

  static bool? _sqlToBool(Object? value) {
    if (value == null) return null;
    if (value is int) return value == 1;
    if (value is bool) return value;
    return null;
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }
}

class LocationFlagObservation {
  const LocationFlagObservation({
    required this.at,
    required this.inside,
    required this.checkInStatus,
    required this.breakStatus,
    required this.checkOutStatus,
    this.locationStatus = LocationCaptureStatus.available,
  });

  final DateTime at;
  final bool? inside;
  final bool checkInStatus;
  final bool breakStatus;
  final bool checkOutStatus;
  final LocationCaptureStatus locationStatus;

  bool get isWorkingTime =>
      checkInStatus && !breakStatus && !checkOutStatus;
}
