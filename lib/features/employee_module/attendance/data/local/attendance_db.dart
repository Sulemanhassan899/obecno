
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AttendanceDb {
  AttendanceDb._();

  static final AttendanceDb instance = AttendanceDb._();

  static const String daysTable = 'attendance_days';
  static const String eventsTable = 'attendance_events';
  static const String monthMetaTable = 'attendance_month_meta';

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final opened = await _open();
    _db = opened;
    return opened;
  }

  // v3: added a `location` column ("lat,lon") on $eventsTable so each cached
  // check-in/out/break event can carry its own reverse-geocodable location.
  static const int _dbVersion = 3;

  Future<Database> _open() async {
    final dbDir = await getDatabasesPath();
    final path = join(dbDir, 'attendance_offline.db');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createV2Schema(db);
        await db.execute('ALTER TABLE $eventsTable ADD COLUMN location TEXT');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // The pre-v2 schema had no user_id column at all, meaning every
          // row already on disk is unattributed and cannot be safely
          // assigned to "the current user" (that's the exact bug being
          // fixed). This is purely a read-through cache of server data, so
          // the safe migration is to drop and rebuild it -- nothing is
          // lost; it simply re-syncs from the server on next load.
          await db.execute('DROP TABLE IF EXISTS $daysTable');
          await db.execute('DROP TABLE IF EXISTS $eventsTable');
          await db.execute('DROP TABLE IF EXISTS $monthMetaTable');
          await _createV2Schema(db);
          await db.execute('ALTER TABLE $eventsTable ADD COLUMN location TEXT');
        } else if (oldVersion < 3) {
          await db.execute('ALTER TABLE $eventsTable ADD COLUMN location TEXT');
        }
      },
    );
  }

  Future<void> _createV2Schema(Database db) async {
    await db.execute('''
      CREATE TABLE $daysTable (
        date TEXT NOT NULL,
        user_id TEXT NOT NULL,
        month TEXT NOT NULL,
        record_id INTEGER,
        first_check_in TEXT,
        last_check_out TEXT,
        total_work_duration INTEGER NOT NULL DEFAULT 0,
        total_break_duration INTEGER NOT NULL DEFAULT 0,
        is_edited INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (date, user_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_attendance_days_month ON $daysTable(user_id, month)',
    );

    await db.execute('''
      CREATE TABLE $eventsTable (
        id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        PRIMARY KEY (id, user_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_attendance_events_date ON $eventsTable(user_id, date)',
    );

    await db.execute('''
      CREATE TABLE $monthMetaTable (
        month TEXT NOT NULL,
        user_id TEXT NOT NULL,
        is_empty INTEGER NOT NULL DEFAULT 0,
        synced_at TEXT,
        PRIMARY KEY (month, user_id)
      )
    ''');
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(eventsTable);
      await txn.delete(daysTable);
      await txn.delete(monthMetaTable);
    });
  }
}