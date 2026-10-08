import 'dart:math' as math;

/// Five-minute attendance location flag. Isolated to the demo module.
enum FlagValue { inside, outside, unavailable }

enum SlotKind { inside, outside, missing, onBreak, notReached }

enum SyncState { local, pending, syncing, synced, failed }

enum AttendancePhase { notCheckedIn, working, onBreak, checkedOut }

enum GpsFailure { none, unavailable, permissionDenied, timeout, poorAccuracy, mock }

enum AlertType {
  checkInRange,
  checkOutOutside,
  locationUnavailable,
  premisesCheckIn,
  premisesCheckOut,
  autoCheckIn,
  autoCheckOut,
}

class AssignedOffice {
  const AssignedOffice({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
}

class GpsSample {
  const GpsSample({
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.failure = GpsFailure.none,
  });

  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final GpsFailure failure;

  bool get hasFix =>
      failure == GpsFailure.none && latitude != null && longitude != null;
}

class OfficeComparison {
  const OfficeComparison({
    required this.office,
    required this.distanceMeters,
    required this.inside,
  });

  final AssignedOffice office;
  final double distanceMeters;
  final bool inside;
}

class MatchResult {
  const MatchResult({
    required this.value,
    required this.comparisons,
    this.matched,
    this.distanceMeters,
  });

  final FlagValue value;
  final List<OfficeComparison> comparisons;
  final AssignedOffice? matched;
  final double? distanceMeters;
}

class PolicyWindow {
  const PolicyWindow({
    required this.checkInMinutes,
    required this.checkOutMinutes,
    this.graceMinutes = 5,
  });

  /// Minutes from local midnight. Comes from permission policy, never hardcoded
  /// as the only legal window — callers pass the policy values.
  final int checkInMinutes;
  final int checkOutMinutes;

  /// Minutes after scheduled checkout before premises checkout reminders fire.
  final int graceMinutes;

  /// One-hour grace before policy check-in / after policy check-out.
  /// Clamped to the calendar day so early/late shifts (e.g. 1am–11pm) still work.
  int get visualStartMinutes {
    final raw = checkInMinutes - 60;
    return raw < 0 ? 0 : raw;
  }

  int get visualEndMinutes {
    final raw = checkOutMinutes + 60;
    const dayEnd = 24 * 60;
    return raw > dayEnd ? dayEnd : raw;
  }

  DateTime onDay(DateTime day, int minutes) {
    final local = DateTime(day.year, day.month, day.day);
    return local.add(Duration(minutes: minutes));
  }

  /// True once checkout time plus grace has elapsed.
  bool pastCheckoutWithGrace(DateTime time) {
    final checkout = onDay(time, checkOutMinutes);
    final afterGrace = checkout.add(Duration(minutes: graceMinutes));
    return !time.isBefore(afterGrace);
  }
}

class LocationFlagRecord {
  LocationFlagRecord({
    required this.eventId,
    required this.employeeId,
    required this.attendanceSessionId,
    required this.date,
    required this.scheduledAt,
    required this.capturedAt,
    required this.flagNumber,
    required this.cycleId,
    required this.cycleStart,
    required this.cycleEnd,
    required this.value,
    required this.kind,
    required this.phase,
    required this.checkInStatus,
    required this.breakStatus,
    required this.checkOutStatus,
    required this.violation,
    required this.syncState,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.matchedLocationId,
    this.matchedLocationName,
    this.officeLatitude,
    this.officeLongitude,
    this.allowedRadius,
    this.distanceMeters,
    this.failure,
    this.requiresServerSync = false,
    this.syncAttemptCount = 0,
    this.lastSyncAttempt,
    this.serverSyncedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String eventId;
  final String employeeId;
  final String attendanceSessionId;
  final String date;
  final DateTime scheduledAt;
  final DateTime capturedAt;
  final int flagNumber;
  final String cycleId;
  final DateTime cycleStart;
  final DateTime cycleEnd;
  final FlagValue? value;
  final SlotKind kind;
  final AttendancePhase phase;
  final bool checkInStatus;
  final bool breakStatus;
  final bool checkOutStatus;
  final bool violation;
  final SyncState syncState;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? matchedLocationId;
  final String? matchedLocationName;
  final double? officeLatitude;
  final double? officeLongitude;
  final double? allowedRadius;
  final double? distanceMeters;
  final GpsFailure? failure;
  final bool requiresServerSync;
  final int syncAttemptCount;
  final DateTime? lastSyncAttempt;
  final DateTime? serverSyncedAt;
  final DateTime createdAt;
  DateTime updatedAt;

  String get slotKey =>
      '$employeeId|$attendanceSessionId|$cycleId|${scheduledAt.millisecondsSinceEpoch}';

  LocationFlagRecord copyWith({
    SyncState? syncState,
    int? syncAttemptCount,
    DateTime? lastSyncAttempt,
    DateTime? serverSyncedAt,
    bool? requiresServerSync,
  }) {
    return LocationFlagRecord(
      eventId: eventId,
      employeeId: employeeId,
      attendanceSessionId: attendanceSessionId,
      date: date,
      scheduledAt: scheduledAt,
      capturedAt: capturedAt,
      flagNumber: flagNumber,
      cycleId: cycleId,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      value: value,
      kind: kind,
      phase: phase,
      checkInStatus: checkInStatus,
      breakStatus: breakStatus,
      checkOutStatus: checkOutStatus,
      violation: violation,
      syncState: syncState ?? this.syncState,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      matchedLocationId: matchedLocationId,
      matchedLocationName: matchedLocationName,
      officeLatitude: officeLatitude,
      officeLongitude: officeLongitude,
      allowedRadius: allowedRadius,
      distanceMeters: distanceMeters,
      failure: failure,
      requiresServerSync: requiresServerSync ?? this.requiresServerSync,
      syncAttemptCount: syncAttemptCount ?? this.syncAttemptCount,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      serverSyncedAt: serverSyncedAt ?? this.serverSyncedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, Object?> toMap() => {
    'event_id': eventId,
    'employee_id': employeeId,
    'attendance_session_id': attendanceSessionId,
    'date': date,
    'scheduled_at': scheduledAt.toIso8601String(),
    'captured_at': capturedAt.toIso8601String(),
    'flag_number': flagNumber,
    'cycle_id': cycleId,
    'cycle_start': cycleStart.toIso8601String(),
    'cycle_end': cycleEnd.toIso8601String(),
    'location_status': value?.name,
    'slot_kind': kind.name,
    'phase': phase.name,
    'check_in_status': checkInStatus ? 1 : 0,
    'break_status': breakStatus ? 1 : 0,
    'check_out_status': checkOutStatus ? 1 : 0,
    'violation': violation ? 1 : 0,
    'sync_status': syncState.name,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracyMeters,
    'matched_location_id': matchedLocationId,
    'matched_location_name': matchedLocationName,
    'office_latitude': officeLatitude,
    'office_longitude': officeLongitude,
    'allowed_radius': allowedRadius,
    'distance': distanceMeters,
    'failure': failure?.name,
    'requires_server_sync': requiresServerSync ? 1 : 0,
    'sync_attempt_count': syncAttemptCount,
    'last_sync_attempt': lastSyncAttempt?.toIso8601String(),
    'server_synced_at': serverSyncedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory LocationFlagRecord.fromMap(Map<String, Object?> map) {
    return LocationFlagRecord(
      eventId: map['event_id']! as String,
      employeeId: map['employee_id']! as String,
      attendanceSessionId: map['attendance_session_id']! as String,
      date: map['date']! as String,
      scheduledAt: slotStart(DateTime.parse(map['scheduled_at']! as String)),
      capturedAt: DateTime.parse(map['captured_at']! as String),
      flagNumber: map['flag_number']! as int,
      cycleId: map['cycle_id']! as String,
      cycleStart: DateTime.parse(map['cycle_start']! as String),
      cycleEnd: DateTime.parse(map['cycle_end']! as String),
      value: _enumOrNull(FlagValue.values, map['location_status'] as String?),
      kind: SlotKind.values.byName(map['slot_kind']! as String),
      phase: AttendancePhase.values.byName(map['phase']! as String),
      checkInStatus: map['check_in_status'] == 1,
      breakStatus: map['break_status'] == 1,
      checkOutStatus: map['check_out_status'] == 1,
      violation: map['violation'] == 1,
      syncState: SyncState.values.byName(map['sync_status']! as String),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      accuracyMeters: (map['accuracy'] as num?)?.toDouble(),
      matchedLocationId: map['matched_location_id'] as String?,
      matchedLocationName: map['matched_location_name'] as String?,
      officeLatitude: (map['office_latitude'] as num?)?.toDouble(),
      officeLongitude: (map['office_longitude'] as num?)?.toDouble(),
      allowedRadius: (map['allowed_radius'] as num?)?.toDouble(),
      distanceMeters: (map['distance'] as num?)?.toDouble(),
      failure: _enumOrNull(GpsFailure.values, map['failure'] as String?),
      requiresServerSync: map['requires_server_sync'] == 1,
      syncAttemptCount: (map['sync_attempt_count'] as int?) ?? 0,
      lastSyncAttempt: _dateOrNull(map['last_sync_attempt'] as String?),
      serverSyncedAt: _dateOrNull(map['server_synced_at'] as String?),
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }
}

class FlagAlert {
  FlagAlert({
    required this.id,
    required this.employeeId,
    required this.attendanceSessionId,
    required this.flagEventId,
    required this.cycleId,
    required this.timestamp,
    required this.type,
    required this.locationStatus,
    required this.message,
    this.matchedLocationId,
    this.delivered = true,
  });

  final String id;
  final String employeeId;
  final String attendanceSessionId;
  final String flagEventId;
  final String cycleId;
  final DateTime timestamp;
  final AlertType type;
  final FlagValue? locationStatus;
  final String message;
  final String? matchedLocationId;
  final bool delivered;

  Map<String, Object?> toMap() => {
    'id': id,
    'employee_id': employeeId,
    'attendance_session_id': attendanceSessionId,
    'flag_event_id': flagEventId,
    'cycle_id': cycleId,
    'timestamp': timestamp.toIso8601String(),
    'notification_type': type.name,
    'location_status': locationStatus?.name,
    'matched_location_id': matchedLocationId,
    'message': message,
    'delivered': delivered ? 1 : 0,
  };

  factory FlagAlert.fromMap(Map<String, Object?> map) {
    return FlagAlert(
      id: map['id']! as String,
      employeeId: map['employee_id']! as String,
      attendanceSessionId: map['attendance_session_id']! as String,
      flagEventId: map['flag_event_id']! as String,
      cycleId: map['cycle_id']! as String,
      timestamp: DateTime.parse(map['timestamp']! as String),
      type: AlertType.values.byName(map['notification_type']! as String),
      locationStatus: _enumOrNull(
        FlagValue.values,
        map['location_status'] as String?,
      ),
      matchedLocationId: map['matched_location_id'] as String?,
      message: map['message']! as String,
      delivered: map['delivered'] == 1,
    );
  }
}

class OutsideInterval {
  const OutsideInterval({required this.started, this.returned});

  final DateTime started;
  final DateTime? returned;
}

/// Continuous run of the same location status across 5-minute slots.
class StatusInterval {
  const StatusInterval({
    required this.started,
    required this.ended,
    required this.kind,
    this.backInOffice = false,
  });

  final DateTime started;
  final DateTime ended;
  final SlotKind kind;
  final bool backInOffice;

  String get label {
    if (backInOffice) return 'back in office';
    switch (kind) {
      case SlotKind.inside:
        return 'in office';
      case SlotKind.outside:
        return 'outside';
      case SlotKind.missing:
        return 'missing';
      case SlotKind.onBreak:
        return 'on break';
      case SlotKind.notReached:
        return 'upcoming';
    }
  }

  Map<String, Object?> toMap({
    required String employeeId,
    required String date,
  }) => {
    'id': '$employeeId|$date|${started.millisecondsSinceEpoch}|${kind.name}',
    'employee_id': employeeId,
    'date': date,
    'started_at': started.toIso8601String(),
    'ended_at': ended.toIso8601String(),
    'slot_kind': kind.name,
    'back_in_office': backInOffice ? 1 : 0,
  };

  factory StatusInterval.fromMap(Map<String, Object?> map) {
    return StatusInterval(
      started: DateTime.parse(map['started_at']! as String),
      ended: DateTime.parse(map['ended_at']! as String),
      kind: SlotKind.values.byName(map['slot_kind']! as String),
      backInOffice: map['back_in_office'] == 1,
    );
  }
}

/// One missing or outside flag slot (includes elapsed slots with no stored record).
class FlagIssueEntry {
  const FlagIssueEntry({
    required this.scheduledAt,
    required this.kind,
    this.record,
  });

  final DateTime scheduledAt;
  final SlotKind kind;
  final LocationFlagRecord? record;

  Map<String, Object?> toMap() => {
    'scheduled_at': scheduledAt.toIso8601String(),
    'slot_kind': kind.name,
  };

  factory FlagIssueEntry.fromMap(Map<String, Object?> map) {
    return FlagIssueEntry(
      scheduledAt: DateTime.parse(map['scheduled_at']! as String),
      kind: SlotKind.values.byName(map['slot_kind']! as String),
    );
  }
}

/// Hour snapshot of missing/outside flags for the dedicated UI card.
class MissingOutsideHour {
  const MissingOutsideHour({
    required this.hourStart,
    required this.savedAt,
    required this.flags,
  });

  final DateTime hourStart;
  final DateTime savedAt;
  final List<FlagIssueEntry> flags;

  DateTime get hourEnd => hourStart.add(const Duration(hours: 1));

  SlotKind get summaryKind => flags.any((f) => f.kind == SlotKind.outside)
      ? SlotKind.outside
      : SlotKind.missing;

  String get summaryLabel =>
      summaryKind == SlotKind.outside ? 'outside' : 'missing';

  Map<String, Object?> toMap({
    required String employeeId,
    required String date,
  }) => {
    'id': '$employeeId|$date|${hourStart.millisecondsSinceEpoch}',
    'employee_id': employeeId,
    'date': date,
    'hour_start': hourStart.toIso8601String(),
    'saved_at': savedAt.toIso8601String(),
    'summary_kind': summaryKind.name,
    'flags_json': flags
        .map((f) => '${f.scheduledAt.toIso8601String()}|${f.kind.name}')
        .join(';'),
  };

  factory MissingOutsideHour.fromMap(Map<String, Object?> map) {
    final raw = (map['flags_json'] as String?) ?? '';
    final flags = <FlagIssueEntry>[];
    if (raw.isNotEmpty) {
      for (final part in raw.split(';')) {
        final bits = part.split('|');
        if (bits.length != 2) continue;
        flags.add(
          FlagIssueEntry(
            scheduledAt: DateTime.parse(bits[0]),
            kind: SlotKind.values.byName(bits[1]),
          ),
        );
      }
    }
    return MissingOutsideHour(
      hourStart: DateTime.parse(map['hour_start']! as String),
      savedAt: DateTime.parse(map['saved_at']! as String),
      flags: List.unmodifiable(flags),
    );
  }
}

class FlagSessionState {
  const FlagSessionState({
    required this.employeeId,
    required this.date,
    required this.phase,
    this.checkedInAt,
    this.checkedOutAt,
  });

  final String employeeId;
  final String date;
  final AttendancePhase phase;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;

  Map<String, Object?> toMap() => {
    'employee_id': employeeId,
    'date': date,
    'phase': phase.name,
    'checked_in_at': checkedInAt?.toIso8601String(),
    'checked_out_at': checkedOutAt?.toIso8601String(),
  };

  factory FlagSessionState.fromMap(Map<String, Object?> map) {
    return FlagSessionState(
      employeeId: map['employee_id']! as String,
      date: map['date']! as String,
      phase: AttendancePhase.values.byName(map['phase']! as String),
      checkedInAt: _dateOrNull(map['checked_in_at'] as String?),
      checkedOutAt: _dateOrNull(map['checked_out_at'] as String?),
    );
  }
}

class SmartAttendanceSettings {
  const SmartAttendanceSettings({
    this.premisesNotifications = false,
    this.smartAttendance = false,
  });

  final bool premisesNotifications;
  final bool smartAttendance;

  SmartAttendanceSettings copyWith({
    bool? premisesNotifications,
    bool? smartAttendance,
  }) {
    return SmartAttendanceSettings(
      premisesNotifications:
          premisesNotifications ?? this.premisesNotifications,
      smartAttendance: smartAttendance ?? this.smartAttendance,
    );
  }

  Map<String, Object?> toMap(String employeeId) => {
    'employee_id': employeeId,
    'premises_notifications': premisesNotifications ? 1 : 0,
    'smart_attendance': smartAttendance ? 1 : 0,
  };

  factory SmartAttendanceSettings.fromMap(Map<String, Object?> map) {
    return SmartAttendanceSettings(
      premisesNotifications: map['premises_notifications'] == 1,
      smartAttendance: map['smart_attendance'] == 1,
    );
  }
}

enum AutoPunchKind { checkIn, checkOut }

class AutoPunchRecord {
  const AutoPunchRecord({
    required this.id,
    required this.employeeId,
    required this.kind,
    required this.timestamp,
    required this.applied,
    this.officeId,
    this.officeName,
    this.queuedAt,
  });

  final String id;
  final String employeeId;
  final AutoPunchKind kind;
  final DateTime timestamp;
  final bool applied;
  final String? officeId;
  final String? officeName;
  final DateTime? queuedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'employee_id': employeeId,
    'kind': kind.name,
    'timestamp': timestamp.toIso8601String(),
    'applied': applied ? 1 : 0,
    'office_id': officeId,
    'office_name': officeName,
    'queued_at': queuedAt?.toIso8601String(),
  };

  factory AutoPunchRecord.fromMap(Map<String, Object?> map) {
    return AutoPunchRecord(
      id: map['id']! as String,
      employeeId: map['employee_id']! as String,
      kind: AutoPunchKind.values.byName(map['kind']! as String),
      timestamp: DateTime.parse(map['timestamp']! as String),
      applied: map['applied'] == 1,
      officeId: map['office_id'] as String?,
      officeName: map['office_name'] as String?,
      queuedAt: _dateOrNull(map['queued_at'] as String?),
    );
  }
}

/// Presence for geofence transitions (inside / outside only; unavailable ignored).
enum PresenceZone { inside, outside }

class CycleVerdict {
  const CycleVerdict({
    required this.label,
    required this.requiresServerSync,
    required this.partiallyUnavailable,
  });

  final String label;
  final bool requiresServerSync;
  final bool partiallyUnavailable;
}

T? _enumOrNull<T extends Enum>(List<T> values, String? name) {
  if (name == null || name.isEmpty) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

DateTime? _dateOrNull(String? raw) =>
    raw == null || raw.isEmpty ? null : DateTime.parse(raw);

double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earth = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * math.pi / 180;

bool withinRadius(double distance, double radius) => distance <= radius;

const int kFlagIntervalMinutes = 5;
const int kFlagsPerHour = 12;
/// Soft hint only — a coarse fix still counts as location available.
/// Missing is reserved for no GPS fix at all.
const double kMaxTrustedAccuracyMeters = 200;

String dateKey(DateTime time) {
  final local = time.toLocal();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$d';
}

DateTime slotStart(DateTime time) {
  final local = time.toLocal();
  final minute = (local.minute ~/ kFlagIntervalMinutes) * kFlagIntervalMinutes;
  return DateTime(local.year, local.month, local.day, local.hour, minute);
}

int flagNumberFor(DateTime slot) => slot.toLocal().minute ~/ kFlagIntervalMinutes + 1;

String cycleIdFor(DateTime slot) {
  final local = slot.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  return '${dateKey(local)}T$hour';
}

DateTime cycleStartFor(DateTime slot) {
  final local = slot.toLocal();
  return DateTime(local.year, local.month, local.day, local.hour);
}

DateTime cycleEndFor(DateTime slot) =>
    cycleStartFor(slot).add(const Duration(hours: 1));

List<DateTime> slotsInHour(DateTime hourStart) {
  final start = DateTime(
    hourStart.year,
    hourStart.month,
    hourStart.day,
    hourStart.hour,
  );
  return List.generate(
    kFlagsPerHour,
    (index) => start.add(Duration(minutes: index * kFlagIntervalMinutes)),
  );
}

String stableEventId({
  required String employeeId,
  required String sessionId,
  required DateTime scheduledAt,
}) {
  return 'lf_${employeeId}_${sessionId}_${scheduledAt.millisecondsSinceEpoch}';
}

MatchResult matchOffices(GpsSample sample, List<AssignedOffice> offices) {
  // Missing / unavailable only when there is no usable fix. A coarse GPS
  // reading still classifies inside vs outside — never invent "missing"
  // just because accuracy is soft or the app was backgrounded.
  if (!sample.hasFix) {
    return MatchResult(value: FlagValue.unavailable, comparisons: const []);
  }
  if (offices.isEmpty) {
    return const MatchResult(value: FlagValue.outside, comparisons: []);
  }

  final comparisons = <OfficeComparison>[];
  OfficeComparison? best;
  for (final office in offices) {
    final distance = distanceMeters(
      sample.latitude!,
      sample.longitude!,
      office.latitude,
      office.longitude,
    );
    final inside = withinRadius(distance, office.radiusMeters);
    final row = OfficeComparison(
      office: office,
      distanceMeters: distance,
      inside: inside,
    );
    comparisons.add(row);
    if (inside && (best == null || distance < best.distanceMeters)) {
      best = row;
    }
  }

  if (best != null) {
    return MatchResult(
      value: FlagValue.inside,
      comparisons: comparisons,
      matched: best.office,
      distanceMeters: best.distanceMeters,
    );
  }
  return MatchResult(value: FlagValue.outside, comparisons: comparisons);
}

class AlertDecision {
  const AlertDecision({
    required this.violation,
    this.type,
    this.message,
  });

  final bool violation;
  final AlertType? type;
  final String? message;

  bool get send => type != null && message != null;
}

AlertDecision decideAlert({
  required FlagValue? value,
  required AttendancePhase phase,
  String? officeName,
  bool checkoutTimeReached = false,
}) {
  if (value == null || value == FlagValue.unavailable) {
    if (phase == AttendancePhase.working) {
      return const AlertDecision(
        violation: false,
        type: AlertType.locationUnavailable,
        message: 'Location could not be verified.',
      );
    }
    return const AlertDecision(violation: false);
  }

  if (phase == AttendancePhase.notCheckedIn && value == FlagValue.inside) {
    final name = (officeName == null || officeName.isEmpty)
        ? 'assigned office'
        : officeName;
    return AlertDecision(
      violation: false,
      type: AlertType.checkInRange,
      message: 'Please check in, you are in the $name range.',
    );
  }

  if (phase == AttendancePhase.notCheckedIn) {
    return const AlertDecision(violation: false);
  }

  if (phase == AttendancePhase.onBreak || phase == AttendancePhase.checkedOut) {
    return const AlertDecision(violation: false);
  }

  if (value == FlagValue.inside) {
    if (checkoutTimeReached) {
      return const AlertDecision(violation: false);
    }
    return const AlertDecision(violation: false);
  }

  final message = (officeName == null || officeName.isEmpty)
      ? 'Please check out, you are outside all assigned office ranges.'
      : 'Please check out, you are not in the assigned office range.';
  return AlertDecision(
    violation: true,
    type: AlertType.checkOutOutside,
    message: message,
  );
}

SlotKind kindFor({
  required AttendancePhase phase,
  required FlagValue? value,
  required bool missed,
}) {
  if (phase == AttendancePhase.onBreak &&
      (value == FlagValue.inside || value == FlagValue.outside)) {
    return SlotKind.onBreak;
  }
  if (missed || value == null || value == FlagValue.unavailable) {
    return SlotKind.missing;
  }
  if (value == FlagValue.inside) return SlotKind.inside;
  return SlotKind.outside;
}

CycleVerdict evaluateCycle(List<LocationFlagRecord> records) {
  final working = records.where((r) => r.phase == AttendancePhase.working);
  final decided = working.where((r) => r.value != null && !r.kind.name.contains('missing') && r.value != FlagValue.unavailable);
  final flags = working.map((r) => r.value).whereType<FlagValue>().toList();
  final confirmed = flags.where((v) => v != FlagValue.unavailable).toList();
  final anyFalse = confirmed.contains(FlagValue.outside);
  final anyNull = flags.contains(FlagValue.unavailable) ||
      records.any((r) => r.kind == SlotKind.missing && r.phase == AttendancePhase.working);
  final allFalse = confirmed.isNotEmpty && confirmed.every((v) => v == FlagValue.outside);
  final allTrue = decided.isNotEmpty &&
      decided.every((r) => r.value == FlagValue.inside) &&
      !anyFalse;

  if (allFalse) {
    return const CycleVerdict(
      label: 'LOCATION ISSUE',
      requiresServerSync: true,
      partiallyUnavailable: false,
    );
  }
  if (anyFalse) {
    return CycleVerdict(
      label: 'LOCATION ISSUE',
      requiresServerSync: true,
      partiallyUnavailable: anyNull,
    );
  }
  if (anyNull && confirmed.isEmpty) {
    return const CycleVerdict(
      label: 'LOCATION UNAVAILABLE',
      requiresServerSync: false,
      partiallyUnavailable: true,
    );
  }
  if (anyNull) {
    return const CycleVerdict(
      label: 'Location partially unavailable',
      requiresServerSync: false,
      partiallyUnavailable: true,
    );
  }
  if (allTrue) {
    return const CycleVerdict(
      label: 'IN OFFICE',
      requiresServerSync: false,
      partiallyUnavailable: false,
    );
  }
  return const CycleVerdict(
    label: 'NOT REACHED',
    requiresServerSync: false,
    partiallyUnavailable: false,
  );
}

List<OutsideInterval> outsideIntervals(List<LocationFlagRecord> records) {
  final working = records.where((r) {
    return r.phase == AttendancePhase.working &&
        (r.value == FlagValue.inside || r.value == FlagValue.outside);
  }).toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  final intervals = <OutsideInterval>[];
  DateTime? open;
  for (final record in working) {
    if (record.value == FlagValue.outside) {
      open ??= record.scheduledAt;
    } else if (record.value == FlagValue.inside && open != null) {
      intervals.add(OutsideInterval(started: open, returned: record.scheduledAt));
      open = null;
    }
  }
  if (open != null) {
    intervals.add(OutsideInterval(started: open));
  }
  return intervals;
}

/// Resolves each elapsed 5-minute slot that has a stored flag.
///
/// Unchecked slots are omitted — they are not "missing". Missing is only a
/// stored [SlotKind.missing] from a failed GPS capture (location unavailable).
List<FlagIssueEntry> resolvedSlots(
  List<LocationFlagRecord> records, {
  required DateTime checkIn,
  required DateTime checkOut,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final last = clock.isBefore(checkOut)
      ? clock
      : checkOut.subtract(const Duration(minutes: 1));
  if (last.isBefore(checkIn)) return const [];

  final bySlot = {
    for (final row in records)
      slotStart(row.scheduledAt).millisecondsSinceEpoch: row,
  };

  final slots = <FlagIssueEntry>[];
  var cursor = slotStart(checkIn);
  if (cursor.isBefore(checkIn)) {
    cursor = cursor.add(const Duration(minutes: kFlagIntervalMinutes));
  }
  while (!cursor.isAfter(last) && cursor.isBefore(checkOut)) {
    final record = bySlot[cursor.millisecondsSinceEpoch];
    if (cursor.isAfter(clock)) {
      // Future slots are not listed.
    } else if (record != null) {
      slots.add(
        FlagIssueEntry(
          scheduledAt: cursor,
          kind: record.kind,
          record: record,
        ),
      );
    }
    cursor = cursor.add(const Duration(minutes: kFlagIntervalMinutes));
  }
  return slots;
}

/// Merges contiguous same-kind slots into intervals (in office / outside / missing).
/// An inside run that follows outside is labeled "back in office".
/// Non-adjacent slots (gaps with no check) stay separate — gaps are not missing.
List<StatusInterval> statusIntervals(
  List<LocationFlagRecord> records, {
  required DateTime checkIn,
  required DateTime checkOut,
  DateTime? now,
}) {
  final slots = resolvedSlots(
    records,
    checkIn: checkIn,
    checkOut: checkOut,
    now: now,
  );
  if (slots.isEmpty) return const [];

  final intervals = <StatusInterval>[];
  var runStart = slots.first.scheduledAt;
  var runKind = slots.first.kind;
  var prevKind = SlotKind.notReached;

  for (var i = 1; i <= slots.length; i++) {
    final atEnd = i == slots.length;
    final next = atEnd ? null : slots[i];
    final prevEnded = slots[i - 1].scheduledAt.add(
      const Duration(minutes: kFlagIntervalMinutes),
    );
    final contiguous =
        !atEnd &&
        next!.kind == runKind &&
        next.scheduledAt.isAtSameMomentAs(prevEnded);
    if (contiguous) continue;

    intervals.add(
      StatusInterval(
        started: runStart,
        ended: prevEnded,
        kind: runKind,
        backInOffice:
            runKind == SlotKind.inside && prevKind == SlotKind.outside,
      ),
    );
    if (!atEnd) {
      prevKind = runKind;
      runStart = next!.scheduledAt;
      runKind = next.kind;
    }
  }

  return intervals;
}

/// Collects missing and outside flags for the dedicated UI card.
///
/// Only **stored** missing (GPS unavailable) and outside flags are included —
/// unchecked slots are never invented as missing.
List<MissingOutsideHour> missingOutsideHours(
  List<LocationFlagRecord> records, {
  required DateTime checkIn,
  required DateTime checkOut,
  DateTime? now,
}) {
  final slots = resolvedSlots(
    records,
    checkIn: checkIn,
    checkOut: checkOut,
    now: now,
  );
  final byHour = <int, List<FlagIssueEntry>>{};
  for (final slot in slots) {
    if (slot.kind != SlotKind.missing && slot.kind != SlotKind.outside) {
      continue;
    }
    final at = slotStart(slot.scheduledAt);
    final hour = DateTime(at.year, at.month, at.day, at.hour);
    byHour.putIfAbsent(hour.millisecondsSinceEpoch, () => []).add(slot);
  }

  final snapshots = <MissingOutsideHour>[];
  for (final entry in byHour.entries) {
    final flags = List<FlagIssueEntry>.from(entry.value)
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    snapshots.add(
      MissingOutsideHour(
        hourStart: DateTime.fromMillisecondsSinceEpoch(entry.key),
        savedAt: flags.first.scheduledAt,
        flags: List.unmodifiable(flags),
      ),
    );
  }

  snapshots.sort((a, b) => b.hourStart.compareTo(a.hourStart));
  return snapshots;
}

String currentStatusLabel({
  required AttendancePhase phase,
  LocationFlagRecord? latest,
}) {
  switch (phase) {
    case AttendancePhase.notCheckedIn:
      return 'NOT CHECKED IN';
    case AttendancePhase.checkedOut:
      return 'CHECKED OUT';
    case AttendancePhase.onBreak:
      return 'ON BREAK';
    case AttendancePhase.working:
      break;
  }
  if (latest == null || latest.value == null || latest.value == FlagValue.unavailable) {
    return 'LOCATION UNAVAILABLE';
  }
  if (latest.value == FlagValue.outside) return 'LOCATION ISSUE';
  return 'IN OFFICE';
}

List<DateTime> visualSlots(DateTime day, PolicyWindow policy) {
  final start = policy.onDay(day, policy.visualStartMinutes);
  final end = policy.onDay(day, policy.visualEndMinutes);
  final slots = <DateTime>[];
  var cursor = slotStart(start);
  if (cursor.isBefore(start)) {
    cursor = cursor.add(const Duration(minutes: kFlagIntervalMinutes));
  }
  while (cursor.isBefore(end)) {
    slots.add(cursor);
    cursor = cursor.add(const Duration(minutes: kFlagIntervalMinutes));
  }
  return slots;
}

List<DateTime> hourStarts(DateTime day, PolicyWindow policy) {
  final start = policy.onDay(day, policy.visualStartMinutes);
  final end = policy.onDay(day, policy.visualEndMinutes);
  final hours = <DateTime>[];
  var cursor = DateTime(start.year, start.month, start.day, start.hour);
  if (cursor.isBefore(start) && start.minute > 0) {
    // include the hour that contains the visual start
  }
  while (cursor.isBefore(end)) {
    hours.add(cursor);
    cursor = cursor.add(const Duration(hours: 1));
  }
  return hours;
}
