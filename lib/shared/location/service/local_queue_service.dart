

import 'package:Obecno/core/services/logger.dart';
import 'package:Obecno/shared/location/data/queue_model.dart';
import 'package:Obecno/shared/location/service/attendance_payload_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

abstract class LocalQueueService {
  Future<bool> insert(AttendancePayloadModel payload);
  Future<List<QueueModel>> getPending();
  Future<void> markSynced(int id);

  Future<int> recordFailure(int id);

  Future<void> resetFailure(int id);

  Future<void> markDeadLetter(int id);

  Future<void> clearAll();

  // Fix (Issue 5): dead-lettered items were previously invisible once
  // quarantined -- these give callers a count to surface in the UI and a
  // way to explicitly retry a specific item, both scoped to whoever is
  // currently signed in.
  Future<int> getDeadLetterCount();

  Future<bool> retryDeadLetter(int id);
}

class LocalQueueServiceImpl implements LocalQueueService {
  /// [userIdProvider] must always return the id of whoever is *currently*
  /// signed in (or null if signed out). It's read fresh on every insert /
  /// getPending call rather than captured once, since this service is
  /// constructed a single time at app startup and lives across login/logout
  /// cycles for potentially different users on the same device.
  LocalQueueServiceImpl({required String? Function() userIdProvider})
    : _userIdProvider = userIdProvider;

  final String? Function() _userIdProvider;

  static const _dbName = 'obecno_attendance_queue.db';
  static const _table = 'attendance_queue';
  // Bumped to add user_id scoping: a queued offline action recorded by
  // User A must never be picked up and synced under User B's session.
  static const _dbVersion = 4;

  Database? _db;

  @override
  Future<int> recordFailure(int id) async {
    try {
      final db = await _database;
      await db.rawUpdate(
        'UPDATE $_table SET retry_count = retry_count + 1 WHERE id = ?',
        [id],
      );
      final rows = await db.query(
        _table,
        columns: ['retry_count'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return 1;
      return (rows.first['retry_count'] as int?) ?? 1;
    } catch (e) {
      _logError('recordFailure', e);
      return 1;
    }
  }

  @override
  Future<void> resetFailure(int id) async {
    try {
      final db = await _database;
      await db.update(
        _table,
        {'retry_count': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      _logError('resetFailure', e);
    }
  }

  @override
  Future<void> markDeadLetter(int id) async {
    try {
      final db = await _database;
      await db.update(
        _table,
        {'is_dead_letter': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      _logError('markDeadLetter', e);
    }
  }

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,
            date TEXT NOT NULL,
            time TEXT NOT NULL,
            lat REAL,
            lon REAL,
            created_at TEXT NOT NULL,
            is_synced INTEGER NOT NULL DEFAULT 0,
            request_id TEXT,
            device_details TEXT,
            retry_count INTEGER NOT NULL DEFAULT 0,
            is_dead_letter INTEGER NOT NULL DEFAULT 0,
            user_id TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_table ADD COLUMN request_id TEXT');
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN device_details TEXT',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN is_dead_letter INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE $_table ADD COLUMN user_id TEXT');
          // Existing rows predate user scoping and have no known owner.
          // Rather than guessing (and risking a sync under the wrong
          // account), quarantine them as dead letters: they stay in the
          // table for diagnostics but will never be auto-synced.
          await db.execute(
            'UPDATE $_table SET is_dead_letter = 1 WHERE user_id IS NULL AND is_synced = 0',
          );
        }
      },
    );
    return _db!;
  }

  @override
  Future<bool> insert(AttendancePayloadModel payload) async {
    try {
      final db = await _database;
      final userId = _userIdProvider();
      final rowId = await db.insert(_table, {
        ...payload.toQueueMap(),
        'user_id': userId,
      });
      return rowId > 0;
    } catch (e) {
      _logError('insert', e);
      return false;
    }
  }

  @override
  Future<List<QueueModel>> getPending() async {
    try {
      final db = await _database;
      final userId = _userIdProvider();
      if (userId == null || userId.isEmpty) {
        // Nobody signed in -- there is no "current user" to sync on behalf
        // of. Returning nothing here (rather than every unscoped row) is
        // what prevents User A's queued action from being synced under
        // User B's session.
        return const [];
      }
      final rows = await db.query(
        _table,
        // FIXED (audit: dead-letter handling): permanently-failed items
        // must stop being refetched every pass -- they're quarantined,
        // not lost (still present in the table for diagnostics).
        // FIXED (cross-user sync leakage): only ever sync items queued by
        // the user who is currently signed in.
        where: 'is_synced = ? AND is_dead_letter = ? AND user_id = ?',
        whereArgs: [0, 0, userId],
        orderBy: 'created_at ASC',
      );
      return rows.map(QueueModel.fromMap).toList();
    } catch (e) {
      _logError('getPending', e);
      return const [];
    }
  }

  @override
  Future<void> markSynced(int id) async {
    try {
      final db = await _database;
      await db.update(
        _table,
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      _logError('markSynced', e);
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      final db = await _database;
      await db.delete(_table);
    } catch (e) {
      _logError('clearAll', e);
    }
  }

  @override
  Future<int> getDeadLetterCount() async {
    try {
      final db = await _database;
      final userId = _userIdProvider();
      // Fix (Issue 5): no signed-in user means no count to show, same
      // reasoning as getPending() -- never fall back to a global count.
      if (userId == null || userId.isEmpty) return 0;
      final rows = await db.query(
        _table,
        columns: ['COUNT(*) AS cnt'],
        where: 'is_dead_letter = ? AND user_id = ?',
        whereArgs: [1, userId],
      );
      return Sqflite.firstIntValue(rows) ?? 0;
    } catch (e) {
      _logError('getDeadLetterCount', e);
      return 0;
    }
  }

  @override
  Future<bool> retryDeadLetter(int id) async {
    try {
      final db = await _database;
      final userId = _userIdProvider();
      if (userId == null || userId.isEmpty) return false;
      // Fix (Issue 5): only clears the dead-letter flag for the row if it
      // still belongs to the user who is currently signed in and is still
      // actually dead-lettered -- otherwise this is a no-op.
      final updated = await db.update(
        _table,
        {'is_dead_letter': 0, 'retry_count': 0},
        where: 'id = ? AND user_id = ? AND is_dead_letter = 1',
        whereArgs: [id, userId],
      );
      return updated > 0;
    } catch (e) {
      _logError('retryDeadLetter', e);
      return false;
    }
  }

  void _logError(String method, Object error) {
    AppLogger.info('LocalQueueService.$method failed: $error');
  }
}