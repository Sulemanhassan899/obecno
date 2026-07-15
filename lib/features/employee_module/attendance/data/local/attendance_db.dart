import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Opens (and lazily creates) the local sqflite database used for
/// offline-first attendance caching.
///
/// This is purely additive infrastructure — it does not touch the
/// Attendance Engine, the API layer, or any existing model.
///
/// Schema:
///  - `attendance_days`   : one row per calendar day (first check-in,
///                          last check-out, computed work/break totals).
///  - `attendance_events` : flattened check_in / check_out / break_start /
///                          break_end instants for a day, so multiple
///                          check-ins/outs and breaks can be reconstructed
///                          exactly on read (not just first/last).
///  - `attendance_month_meta` : one row per month once it has been synced
///                              from the API — tracks whether that month
///                              was empty (so we don't re-fetch it forever)
///                              and when it was last synced.
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

  Future<Database> _open() async {
    final dbDir = await getDatabasesPath();
    final path = join(dbDir, 'attendance_offline.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $daysTable (
            date TEXT PRIMARY KEY,
            month TEXT NOT NULL,
            record_id INTEGER,
            first_check_in TEXT,
            last_check_out TEXT,
            total_work_duration INTEGER NOT NULL DEFAULT 0,
            total_break_duration INTEGER NOT NULL DEFAULT 0,
            is_edited INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_attendance_days_month ON $daysTable(month)',
        );

        await db.execute('''
          CREATE TABLE $eventsTable (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            type TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_attendance_events_date ON $eventsTable(date)',
        );

        await db.execute('''
          CREATE TABLE $monthMetaTable (
            month TEXT PRIMARY KEY,
            is_empty INTEGER NOT NULL DEFAULT 0,
            synced_at TEXT
          )
        ''');
      },
    );
  }

  /// Mainly for tests / logout flows. Not wired into any UI action today.
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
