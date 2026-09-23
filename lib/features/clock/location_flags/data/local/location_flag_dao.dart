import 'package:obecno/features/clock/location_flags/data/models/location_flag_record.dart';
import 'package:obecno/features/employee_module/attendance/data/local/attendance_db.dart';
import 'package:sqflite/sqflite.dart';

class LocationFlagDao {
  LocationFlagDao({AttendanceDb? db}) : _db = db ?? AttendanceDb.instance;

  final AttendanceDb _db;

  Future<Database> get _database => _db.database;

  Future<void> upsert(LocationFlagRecord record) async {
    final db = await _database;
    await db.insert(
      AttendanceDb.locationFlagChecksTable,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<LocationFlagRecord?> findSlot({
    required String employeeId,
    required String cycleId,
    required int flagNumber,
  }) async {
    final db = await _database;
    final rows = await db.query(
      AttendanceDb.locationFlagChecksTable,
      where: 'employee_id = ? AND cycle_id = ? AND flag_number = ?',
      whereArgs: [employeeId, cycleId, flagNumber],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LocationFlagRecord.fromMap(rows.first);
  }

  Future<List<LocationFlagRecord>> forCycle({
    required String employeeId,
    required String cycleId,
  }) async {
    final db = await _database;
    final rows = await db.query(
      AttendanceDb.locationFlagChecksTable,
      where: 'employee_id = ? AND cycle_id = ?',
      whereArgs: [employeeId, cycleId],
      orderBy: 'flag_number ASC',
    );
    return rows.map(LocationFlagRecord.fromMap).toList();
  }

  Future<List<LocationFlagRecord>> forDate({
    required String employeeId,
    required String date,
  }) async {
    final db = await _database;
    final rows = await db.query(
      AttendanceDb.locationFlagChecksTable,
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
      orderBy: 'timestamp ASC',
    );
    return rows.map(LocationFlagRecord.fromMap).toList();
  }

  Future<List<LocationFlagRecord>> pendingForEmployee(String employeeId) async {
    final db = await _database;
    final rows = await db.query(
      AttendanceDb.locationFlagChecksTable,
      where:
          'employee_id = ? AND requires_server_sync = 1 AND sync_status IN (?, ?)',
      whereArgs: [
        employeeId,
        LocationFlagSyncStatus.pending.name,
        LocationFlagSyncStatus.failed.name,
      ],
      orderBy: 'timestamp ASC',
    );
    return rows.map(LocationFlagRecord.fromMap).toList();
  }

  Future<void> updateSync({
    required String id,
    required String employeeId,
    required LocationFlagSyncStatus status,
    int? syncAttemptCount,
    DateTime? lastSyncAttempt,
    DateTime? serverSyncedAt,
  }) async {
    final db = await _database;
    await db.update(
      AttendanceDb.locationFlagChecksTable,
      {
        'sync_status': status.name,
        if (syncAttemptCount != null) 'sync_attempt_count': syncAttemptCount,
        if (lastSyncAttempt != null)
          'last_sync_attempt': lastSyncAttempt.toIso8601String(),
        if (serverSyncedAt != null)
          'server_synced_at': serverSyncedAt.toIso8601String(),
      },
      where: 'id = ? AND employee_id = ?',
      whereArgs: [id, employeeId],
    );
  }

  Future<void> markCycleNeedsSync({
    required String employeeId,
    required String cycleId,
    required bool requiresServerSync,
  }) async {
    final db = await _database;
    await db.update(
      AttendanceDb.locationFlagChecksTable,
      {
        'requires_server_sync': requiresServerSync ? 1 : 0,
        if (requiresServerSync)
          'sync_status': LocationFlagSyncStatus.pending.name,
      },
      where: 'employee_id = ? AND cycle_id = ?',
      whereArgs: [employeeId, cycleId],
    );
  }
}
