import 'package:Obecno/shared/location/data/queue_model.dart';
import 'package:Obecno/shared/location/service/attendance_payload_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

abstract class LocalQueueService {
  Future<void> insert(AttendancePayloadModel payload);
  Future<List<QueueModel>> getPending();
  Future<void> markSynced(int id);
}

/// SQLite-backed offline queue for attendance actions taken while
/// offline (or when an online submit fails). Table: `attendance_queue`
/// (id, action, date, time, lat, lon, created_at, is_synced).
///
/// Per spec: SQLite failures are logged, never thrown -- every method
/// degrades gracefully instead of crashing the attendance flow.
class LocalQueueServiceImpl implements LocalQueueService {
  static const _dbName = 'obecno_attendance_queue.db';
  static const _table = 'attendance_queue';
  static const _dbVersion = 1;

  Database? _db;

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
            is_synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    return _db!;
  }

  @override
  Future<void> insert(AttendancePayloadModel payload) async {
    try {
      final db = await _database;
      await db.insert(_table, payload.toQueueMap());
    } catch (e) {
      _logError('insert', e);
    }
  }

  @override
  Future<List<QueueModel>> getPending() async {
    try {
      final db = await _database;
      final rows = await db.query(
        _table,
        where: 'is_synced = ?',
        whereArgs: [0],
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

  void _logError(String method, Object error) {
    // ignore: avoid_print
    print('LocalQueueService.$method failed: $error');
  }
}
