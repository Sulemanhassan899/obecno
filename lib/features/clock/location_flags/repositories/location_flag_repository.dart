import 'dart:math';

import 'package:obecno/features/clock/location_flags/data/local/location_flag_dao.dart';
import 'package:obecno/features/clock/location_flags/data/models/location_flag_record.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_evaluator.dart';

class LocationFlagRepository {
  LocationFlagRepository({LocationFlagDao? dao})
    : _dao = dao ?? LocationFlagDao();

  final LocationFlagDao _dao;
  static final Random _random = Random();

  static String newEventId(DateTime at) {
    final rand = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '${at.microsecondsSinceEpoch}-locflag-$rand';
  }

  Future<LocationFlagRecord?> existingSlot({
    required String employeeId,
    required DateTime at,
  }) {
    return _dao.findSlot(
      employeeId: employeeId,
      cycleId: LocationFlagEvaluator.cycleIdFor(
        employeeId: employeeId,
        at: at,
      ),
      flagNumber: LocationFlagEvaluator.flagNumberFor(at),
    );
  }

  Future<LocationFlagRecord> saveCheck(LocationFlagRecord record) async {
    await _dao.upsert(record);
    final cycle = await _dao.forCycle(
      employeeId: record.employeeId,
      cycleId: record.cycleId,
    );
    final snapshot = _flagsFrom(cycle);
    final withFlags = record.copyWith(hourFlags: snapshot);
    await _dao.upsert(withFlags);

    final observations = cycle
        .map(
          (row) => LocationFlagObservation(
            at: row.timestamp,
            inside: row.insideRadius,
            checkInStatus: row.checkInStatus,
            breakStatus: row.breakStatus,
            checkOutStatus: row.checkOutStatus,
            locationStatus: row.locationStatus,
          ),
        )
        .toList();
    final verdict = LocationFlagEvaluator.evaluate(
      checkInStatus: record.checkInStatus,
      observations: observations,
    );
    if (verdict.requiresServerSync) {
      await _dao.markCycleNeedsSync(
        employeeId: record.employeeId,
        cycleId: record.cycleId,
        requiresServerSync: true,
      );
      return withFlags.copyWith(
        requiresServerSync: true,
        syncStatus: LocationFlagSyncStatus.pending,
      );
    }
    return withFlags;
  }

  Future<List<LocationFlagRecord>> recordsForDate({
    required String employeeId,
    required DateTime day,
  }) {
    return _dao.forDate(
      employeeId: employeeId,
      date: LocationFlagEvaluator.calendarDate(day),
    );
  }

  Future<List<LocationFlagRecord>> pending(String employeeId) {
    return _dao.pendingForEmployee(employeeId);
  }

  Future<void> markSyncing(LocationFlagRecord record) {
    return _dao.updateSync(
      id: record.id,
      employeeId: record.employeeId,
      status: LocationFlagSyncStatus.syncing,
      lastSyncAttempt: DateTime.now(),
    );
  }

  Future<void> markSynced(LocationFlagRecord record) {
    return _dao.updateSync(
      id: record.id,
      employeeId: record.employeeId,
      status: LocationFlagSyncStatus.synced,
      lastSyncAttempt: DateTime.now(),
      serverSyncedAt: DateTime.now(),
    );
  }

  Future<void> markFailed(LocationFlagRecord record) {
    return _dao.updateSync(
      id: record.id,
      employeeId: record.employeeId,
      status: LocationFlagSyncStatus.failed,
      syncAttemptCount: record.syncAttemptCount + 1,
      lastSyncAttempt: DateTime.now(),
    );
  }

  static List<bool?> _flagsFrom(List<LocationFlagRecord> cycle) {
    final flags = List<bool?>.filled(
      LocationFlagEvaluator.flagsPerCycle,
      null,
    );
    for (final row in cycle) {
      final index = row.flagNumber - 1;
      if (index < 0 || index >= flags.length) continue;
      flags[index] = row.insideRadius;
    }
    return flags;
  }
}
