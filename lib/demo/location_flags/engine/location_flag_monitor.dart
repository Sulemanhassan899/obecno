import 'package:obecno/demo/location_flags/data/location_flag_store.dart';
import 'package:obecno/demo/location_flags/domain/location_flag_models.dart';

/// Demo-only monitor. It never writes the production attendance database.
class LocationFlagMonitor {
  LocationFlagMonitor({
    required LocationFlagStore store,
    required this.employeeId,
    required this.offices,
    required this.policy,
    DateTime? now,
  }) : _store = store,
       _now = now ?? DateTime.now() {
    _sessionId = 'sess_${employeeId}_${dateKey(_now)}';
  }

  final LocationFlagStore _store;
  List<AssignedOffice> offices;
  PolicyWindow policy;

  String employeeId;
  late String _sessionId;
  DateTime _now;
  AttendancePhase phase = AttendancePhase.notCheckedIn;
  DateTime? checkedInAt;
  DateTime? checkedOutAt;
  bool offline = false;
  bool failNextSync = false;
  GpsSample? latestSample;

  DateTime get now => _now;
  String get sessionId => _sessionId;
  String get today => dateKey(_now);

  void setClock(DateTime time) {
    _now = time;
  }

  void adoptEmployee(String nextEmployeeId) {
    employeeId = nextEmployeeId;
    _sessionId = 'sess_${employeeId}_${dateKey(_now)}';
    phase = AttendancePhase.notCheckedIn;
    checkedInAt = null;
    checkedOutAt = null;
  }

  void checkIn() {
    if (phase == AttendancePhase.checkedOut) return;
    phase = AttendancePhase.working;
    checkedInAt ??= _now;
    checkedOutAt = null;
  }

  void breakIn() {
    if (phase != AttendancePhase.working) return;
    phase = AttendancePhase.onBreak;
  }

  void breakOut() {
    if (phase != AttendancePhase.onBreak) return;
    phase = AttendancePhase.working;
  }

  void checkOut() {
    if (phase == AttendancePhase.notCheckedIn) return;
    phase = AttendancePhase.checkedOut;
    checkedOutAt = _now;
  }

  bool get monitoringActive =>
      phase == AttendancePhase.working || phase == AttendancePhase.onBreak;

  Future<LocationFlagRecord?> capture(GpsSample sample) async {
    latestSample = sample;
    if (phase == AttendancePhase.checkedOut) return null;

    final slot = slotStart(_now);
    // Flag window = policy check-in/out ± 1 hour grace (e.g. 8am–7pm for 9–6).
    final monitorStart = policy.onDay(slot, policy.visualStartMinutes);
    final monitorEnd = policy.onDay(slot, policy.visualEndMinutes);
    final policyCheckOut = policy.onDay(slot, policy.checkOutMinutes);
    final inFlagWindow =
        !slot.isBefore(monitorStart) && slot.isBefore(monitorEnd);

    if (!inFlagWindow) return null;

    final existing = await _store.flagsFor(employeeId: employeeId, date: today);
    final slotKey = slot.millisecondsSinceEpoch;
    LocationFlagRecord? prior;
    for (final row in existing) {
      if (slotStart(row.scheduledAt).millisecondsSinceEpoch == slotKey &&
          row.employeeId == employeeId) {
        prior = row;
        break;
      }
    }
    // Keep a real GPS result. Only placeholders (missing) may be replaced.
    if (prior != null && prior.kind != SlotKind.missing) {
      return prior;
    }

    final match = matchOffices(sample, offices);
    final decision = decideAlert(
      value: match.value,
      phase: phase,
      officeName: match.value == FlagValue.outside ? null : match.matched?.name,
      checkoutTimeReached: !slot.isBefore(
        policyCheckOut.subtract(const Duration(minutes: kFlagIntervalMinutes)),
      ),
    );

    final kind = kindFor(phase: phase, value: match.value, missed: false);
    final record = _build(
      slot: slot,
      capturedAt: sample.timestamp,
      value: match.value,
      kind: kind,
      match: match,
      failure: sample.failure == GpsFailure.none ? null : sample.failure,
      violation: decision.violation,
      missed: false,
    );
    await _store.upsertFlag(record);
    if (decision.send) {
      await _store.insertAlert(
        FlagAlert(
          id: 'al_${record.eventId}_${decision.type!.name}',
          employeeId: employeeId,
          attendanceSessionId: _sessionId,
          flagEventId: record.eventId,
          cycleId: record.cycleId,
          timestamp: sample.timestamp,
          type: decision.type!,
          locationStatus: match.value,
          matchedLocationId: match.matched?.id,
          message: decision.message!,
        ),
      );
    }
    return record;
  }

  /// Writes the current slot and backfills recent empty slots with this GPS
  /// sample.
  ///
  /// Emulators / locked phones often miss the exact 5-minute timer. A later
  /// successful fix fills those gaps as inside/outside instead of leaving
  /// "No check". Failed GPS only writes [SlotKind.missing] for the *current*
  /// slot — never invents missing for older gaps.
  Future<LocationFlagRecord?> captureThroughNow(GpsSample sample) async {
    latestSample = sample;
    if (phase == AttendancePhase.checkedOut) return null;

    final end = slotStart(_now);
    final monitorStart = policy.onDay(end, policy.visualStartMinutes);
    final monitorEnd = policy.onDay(end, policy.visualEndMinutes);
    if (end.isBefore(monitorStart) || !end.isBefore(monitorEnd)) {
      return capture(sample);
    }

    final existing = await _store.flagsFor(employeeId: employeeId, date: today);
    final bySlot = <int, LocationFlagRecord>{
      for (final row in existing)
        slotStart(row.scheduledAt).millisecondsSinceEpoch: row,
    };

    // Catch up at most the last 2 hours so one wake does not stamp the whole day.
    var cursor = end.subtract(const Duration(hours: 2));
    if (cursor.isBefore(monitorStart)) cursor = monitorStart;
    cursor = slotStart(cursor);
    if (cursor.isBefore(monitorStart)) {
      cursor = cursor.add(const Duration(minutes: kFlagIntervalMinutes));
    }

    final restored = _now;
    LocationFlagRecord? last;
    while (!cursor.isAfter(end) && cursor.isBefore(monitorEnd)) {
      final prior = bySlot[cursor.millisecondsSinceEpoch];
      if (prior != null && prior.kind != SlotKind.missing) {
        last = prior;
        cursor = cursor.add(const Duration(minutes: kFlagIntervalMinutes));
        continue;
      }

      final isCurrent =
          cursor.millisecondsSinceEpoch == end.millisecondsSinceEpoch;
      // Only stamp older empty slots when we have a real fix (inside/outside).
      if (!sample.hasFix && !isCurrent) {
        cursor = cursor.add(const Duration(minutes: kFlagIntervalMinutes));
        continue;
      }

      setClock(cursor);
      last = await capture(sample);
      if (last != null) {
        bySlot[cursor.millisecondsSinceEpoch] = last;
      }
      cursor = cursor.add(const Duration(minutes: kFlagIntervalMinutes));
    }
    setClock(restored);
    return last;
  }

  /// No-op: unchecked slots are not "missing". Missing is only written when a
  /// live GPS capture fails ([FlagValue.unavailable]).
  Future<void> markMissedSlots() async {}

  /// No-op: do not invent missing placeholders for gaps while the app was
  /// closed. Background ticks write real inside/outside/unavailable flags.
  Future<void> persistResolvedGaps() async {}

  void restoreSession(FlagSessionState session) {
    if (session.date != today) return;
    phase = session.phase;
    checkedInAt = session.checkedInAt;
    checkedOutAt = session.checkedOutAt;
  }

  Future<void> persistSession() {
    return _store.saveSession(
      FlagSessionState(
        employeeId: employeeId,
        date: today,
        phase: phase,
        checkedInAt: checkedInAt,
        checkedOutAt: checkedOutAt,
      ),
    );
  }

  Future<List<LocationFlagRecord>> syncPending() async {
    final rows = await _store.flagsFor(employeeId: employeeId, date: today);
    final updated = <LocationFlagRecord>[];
    for (final row in rows) {
      if (row.syncState != SyncState.pending &&
          row.syncState != SyncState.failed) {
        continue;
      }
      if (offline || failNextSync) {
        final failed = row.copyWith(
          syncState: SyncState.failed,
          syncAttemptCount: row.syncAttemptCount + 1,
          lastSyncAttempt: _now,
        );
        await _store.upsertFlag(failed);
        updated.add(failed);
        continue;
      }
      final syncing = row.copyWith(
        syncState: SyncState.syncing,
        lastSyncAttempt: _now,
      );
      await _store.upsertFlag(syncing);
      final synced = syncing.copyWith(
        syncState: SyncState.synced,
        serverSyncedAt: _now,
        syncAttemptCount: row.syncAttemptCount + 1,
      );
      await _store.upsertFlag(synced);
      updated.add(synced);
    }
    failNextSync = false;
    return updated;
  }

  LocationFlagRecord _build({
    required DateTime slot,
    required DateTime capturedAt,
    required FlagValue? value,
    required SlotKind kind,
    required MatchResult? match,
    required GpsFailure? failure,
    required bool violation,
    required bool missed,
  }) {
    final cycleRecordsHint =
        value == FlagValue.outside && phase == AttendancePhase.working;
    return LocationFlagRecord(
      eventId: stableEventId(
        employeeId: employeeId,
        sessionId: _sessionId,
        scheduledAt: slot,
      ),
      employeeId: employeeId,
      attendanceSessionId: _sessionId,
      date: dateKey(slot),
      scheduledAt: slot,
      capturedAt: capturedAt,
      flagNumber: flagNumberFor(slot),
      cycleId: cycleIdFor(slot),
      cycleStart: cycleStartFor(slot),
      cycleEnd: cycleEndFor(slot),
      value: missed ? null : value,
      kind: kind,
      phase: phase,
      checkInStatus: phase != AttendancePhase.notCheckedIn,
      breakStatus: phase == AttendancePhase.onBreak,
      checkOutStatus: phase == AttendancePhase.checkedOut,
      violation: violation,
      syncState: (cycleRecordsHint || violation)
          ? SyncState.pending
          : SyncState.local,
      latitude: match == null ? null : latestSample?.latitude,
      longitude: match == null ? null : latestSample?.longitude,
      accuracyMeters: latestSample?.accuracyMeters,
      matchedLocationId: match?.matched?.id,
      matchedLocationName: match?.matched?.name,
      officeLatitude: match?.matched?.latitude,
      officeLongitude: match?.matched?.longitude,
      allowedRadius: match?.matched?.radiusMeters,
      distanceMeters: match?.distanceMeters,
      failure: failure,
      requiresServerSync: violation,
    );
  }
}

List<AssignedOffice> demoOffices() {
  const baseLat = 24.8607;
  const baseLon = 67.0011;
  return List.generate(10, (index) {
    final letter = String.fromCharCode(65 + index);
    return AssignedOffice(
      id: 'office_$letter',
      name: 'Office $letter',
      latitude: baseLat + (index * 0.004),
      longitude: baseLon,
      radiusMeters: 100 + (index * 10),
    );
  });
}

GpsSample sampleInside(AssignedOffice office, DateTime time) {
  return GpsSample(
    timestamp: time,
    latitude: office.latitude,
    longitude: office.longitude,
    accuracyMeters: 8,
  );
}

GpsSample sampleOutside(DateTime time) {
  return GpsSample(
    timestamp: time,
    latitude: 0,
    longitude: 0,
    accuracyMeters: 8,
  );
}

GpsSample sampleFailed(DateTime time, GpsFailure failure) {
  return GpsSample(timestamp: time, failure: failure, accuracyMeters: null);
}
