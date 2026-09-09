import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AttendanceDb {
  AttendanceDb._();

  static final AttendanceDb instance = AttendanceDb._();

  static const String daysTable = 'attendance_days';
  static const String eventsTable = 'attendance_events';
  static const String monthMetaTable = 'attendance_month_meta';
  static const String reminderSettingsTable = 'reminder_settings';
  static const String reminderLogsTable = 'reminder_logs';
  static const String reminderPunchesTable = 'reminder_punches';
  static const String reminderDayStateTable = 'reminder_day_state';
  static const String reminderDeliveriesTable = 'reminder_deliveries';

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
  // v4: personal reminder toggles + fired-reminder log (device-local only).
  // v5: optional earlier remind-at time per reminder type.
  // v6: persist leave/holiday flags so On Leave rows survive cache restore.
  // v7: reminder punches, clock status, and delivery rows for later API sync.
  static const int _dbVersion = 7;

  Future<Database> _open() async {
    final dbDir = await getDatabasesPath();
    final path = join(dbDir, 'attendance_offline.db');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createV2Schema(db);
        await db.execute('ALTER TABLE $eventsTable ADD COLUMN location TEXT');
        await _createReminderTables(db);
        await _addLeaveColumns(db);
        await _createReminderSyncTables(db);
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
        if (oldVersion < 4) {
          await _createReminderTables(db);
        }
        if (oldVersion < 5) {
          await _addRemindMinutesColumn(db);
        }
        if (oldVersion < 6) {
          await _addLeaveColumns(db);
        }
        if (oldVersion < 7) {
          await _createReminderSyncTables(db);
        }
      },
    );
  }

  Future<void> _createReminderTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $reminderSettingsTable (
        user_id TEXT NOT NULL,
        reminder_type TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 0,
        remind_minutes INTEGER,
        updated_at TEXT,
        PRIMARY KEY (user_id, reminder_type)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminder_settings_user '
      'ON $reminderSettingsTable(user_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $reminderLogsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        date TEXT NOT NULL,
        reminder_type TEXT NOT NULL,
        fired_at TEXT NOT NULL,
        title TEXT,
        message TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminder_logs_user_date '
      'ON $reminderLogsTable(user_id, date)',
    );
  }

  Future<void> _addLeaveColumns(Database db) async {
    Future<void> add(String name, String spec) async {
      final info = await db.rawQuery('PRAGMA table_info($daysTable)');
      if (info.any((row) => row['name'] == name)) return;
      await db.execute('ALTER TABLE $daysTable ADD COLUMN $name $spec');
    }

    await add('is_leave', 'INTEGER NOT NULL DEFAULT 0');
    await add('is_holiday', 'INTEGER NOT NULL DEFAULT 0');
    await add('holiday_name', 'TEXT');
  }

  Future<void> _createReminderSyncTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $reminderPunchesTable (
        user_id TEXT NOT NULL,
        date TEXT NOT NULL,
        kind TEXT NOT NULL,
        punched_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_id, date, kind, punched_at)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminder_punches_user_date '
      'ON $reminderPunchesTable(user_id, date)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $reminderDayStateTable (
        user_id TEXT NOT NULL,
        date TEXT NOT NULL,
        clock_status TEXT NOT NULL,
        first_check_in TEXT,
        last_check_out TEXT,
        break_start TEXT,
        break_end TEXT,
        check_in_remind_at TEXT,
        check_out_remind_at TEXT,
        break_remind_at TEXT,
        break_end_remind_at TEXT,
        policy_check_in TEXT,
        policy_check_out TEXT,
        grace_minutes INTEGER,
        break_minutes INTEGER,
        long_attendance_hours INTEGER,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_id, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $reminderDeliveriesTable (
        user_id TEXT NOT NULL,
        date TEXT NOT NULL,
        reminder_type TEXT NOT NULL,
        scheduled_at TEXT NOT NULL,
        delivered_at TEXT NOT NULL,
        clock_status TEXT,
        title TEXT,
        message TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_id, date, reminder_type)
      )
    ''');

    Future<void> addColumn(
      String table,
      String name,
      String spec,
    ) async {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      if (info.any((row) => row['name'] == name)) return;
      await db.execute('ALTER TABLE $table ADD COLUMN $name $spec');
    }

    await addColumn(reminderLogsTable, 'clock_status', 'TEXT');
    await addColumn(reminderLogsTable, 'delivered_at', 'TEXT');
    await addColumn(reminderLogsTable, 'synced', 'INTEGER NOT NULL DEFAULT 0');
    await addColumn(reminderSettingsTable, 'synced', 'INTEGER NOT NULL DEFAULT 0');
  }

  Future<void> _addRemindMinutesColumn(Database db) async {
    final info = await db.rawQuery(
      'PRAGMA table_info($reminderSettingsTable)',
    );
    final hasColumn = info.any((row) => row['name'] == 'remind_minutes');
    if (hasColumn) return;
    await db.execute(
      'ALTER TABLE $reminderSettingsTable ADD COLUMN remind_minutes INTEGER',
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
        is_leave INTEGER NOT NULL DEFAULT 0,
        is_holiday INTEGER NOT NULL DEFAULT 0,
        holiday_name TEXT,
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
      await txn.delete(reminderSettingsTable);
      await txn.delete(reminderLogsTable);
      await txn.delete(reminderPunchesTable);
      await txn.delete(reminderDayStateTable);
      await txn.delete(reminderDeliveriesTable);
    });
  }
}
