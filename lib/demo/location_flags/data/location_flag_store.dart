import 'package:obecno/demo/location_flags/domain/location_flag_models.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

abstract class LocationFlagStore {
  Future<void> upsertFlag(LocationFlagRecord record);
  Future<void> insertAlert(FlagAlert alert);
  Future<List<LocationFlagRecord>> flagsFor({
    required String employeeId,
    required String date,
  });
  Future<List<FlagAlert>> alertsFor(String employeeId);
  Future<void> replaceStatusIntervals({
    required String employeeId,
    required String date,
    required List<StatusInterval> intervals,
  });
  Future<List<StatusInterval>> statusIntervalsFor({
    required String employeeId,
    required String date,
  });
  Future<void> replaceIssueHours({
    required String employeeId,
    required String date,
    required List<MissingOutsideHour> hours,
  });
  Future<List<MissingOutsideHour>> issueHoursFor({
    required String employeeId,
    required String date,
  });
  Future<void> saveSession(FlagSessionState session);
  Future<FlagSessionState?> sessionFor(String employeeId);
  Future<void> saveSmartSettings(
    String employeeId,
    SmartAttendanceSettings settings,
  );
  Future<SmartAttendanceSettings> smartSettingsFor(String employeeId);
  Future<void> upsertAutoPunch(AutoPunchRecord punch);
  Future<List<AutoPunchRecord>> autoPunchesFor(String employeeId);
  Future<List<AutoPunchRecord>> queuedAutoPunches(String employeeId);
  Future<void> clearEmployee(String employeeId);
  Future<void> clearFlagsForDate({
    required String employeeId,
    required String date,
  });
}

class MemoryFlagStore implements LocationFlagStore {
  final Map<String, LocationFlagRecord> _flags = {};
  final List<FlagAlert> _alerts = [];
  final Map<String, List<StatusInterval>> _intervals = {};
  final Map<String, List<MissingOutsideHour>> _issueHours = {};
  final Map<String, FlagSessionState> _sessions = {};
  final Map<String, SmartAttendanceSettings> _settings = {};
  final Map<String, AutoPunchRecord> _autoPunches = {};

  String _dayKey(String employeeId, String date) => '$employeeId|$date';

  @override
  Future<void> upsertFlag(LocationFlagRecord record) async {
    _flags[record.slotKey] = record;
  }

  @override
  Future<void> insertAlert(FlagAlert alert) async {
    final exists = _alerts.any(
      (row) => row.flagEventId == alert.flagEventId && row.type == alert.type,
    );
    if (!exists) _alerts.add(alert);
  }

  @override
  Future<List<LocationFlagRecord>> flagsFor({
    required String employeeId,
    required String date,
  }) async {
    return _flags.values
        .where((row) => row.employeeId == employeeId && row.date == date)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  @override
  Future<List<FlagAlert>> alertsFor(String employeeId) async {
    return _alerts.where((row) => row.employeeId == employeeId).toList();
  }

  @override
  Future<void> replaceStatusIntervals({
    required String employeeId,
    required String date,
    required List<StatusInterval> intervals,
  }) async {
    _intervals[_dayKey(employeeId, date)] = List.of(intervals);
  }

  @override
  Future<List<StatusInterval>> statusIntervalsFor({
    required String employeeId,
    required String date,
  }) async {
    return List.of(_intervals[_dayKey(employeeId, date)] ?? const []);
  }

  @override
  Future<void> replaceIssueHours({
    required String employeeId,
    required String date,
    required List<MissingOutsideHour> hours,
  }) async {
    _issueHours[_dayKey(employeeId, date)] = List.of(hours);
  }

  @override
  Future<List<MissingOutsideHour>> issueHoursFor({
    required String employeeId,
    required String date,
  }) async {
    return List.of(_issueHours[_dayKey(employeeId, date)] ?? const []);
  }

  @override
  Future<void> saveSession(FlagSessionState session) async {
    _sessions[session.employeeId] = session;
  }

  @override
  Future<FlagSessionState?> sessionFor(String employeeId) async {
    return _sessions[employeeId];
  }

  @override
  Future<void> saveSmartSettings(
    String employeeId,
    SmartAttendanceSettings settings,
  ) async {
    _settings[employeeId] = settings;
  }

  @override
  Future<SmartAttendanceSettings> smartSettingsFor(String employeeId) async {
    return _settings[employeeId] ?? const SmartAttendanceSettings();
  }

  @override
  Future<void> upsertAutoPunch(AutoPunchRecord punch) async {
    _autoPunches[punch.id] = punch;
  }

  @override
  Future<List<AutoPunchRecord>> autoPunchesFor(String employeeId) async {
    return _autoPunches.values
        .where((row) => row.employeeId == employeeId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<List<AutoPunchRecord>> queuedAutoPunches(String employeeId) async {
    return _autoPunches.values
        .where((row) => row.employeeId == employeeId && !row.applied)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Future<void> clearEmployee(String employeeId) async {
    _flags.removeWhere((_, row) => row.employeeId == employeeId);
    _alerts.removeWhere((row) => row.employeeId == employeeId);
    _intervals.removeWhere((key, _) => key.startsWith('$employeeId|'));
    _issueHours.removeWhere((key, _) => key.startsWith('$employeeId|'));
    _sessions.remove(employeeId);
    _settings.remove(employeeId);
    _autoPunches.removeWhere((_, row) => row.employeeId == employeeId);
  }

  @override
  Future<void> clearFlagsForDate({
    required String employeeId,
    required String date,
  }) async {
    _flags.removeWhere(
      (_, row) => row.employeeId == employeeId && row.date == date,
    );
    _intervals.remove(_dayKey(employeeId, date));
    _issueHours.remove(_dayKey(employeeId, date));
  }
}

class SqliteFlagStore implements LocationFlagStore {
  SqliteFlagStore(this._db);

  final Database _db;

  static const _dbName = 'location_flag_demo.db';
  static const _version = 3;

  static Future<SqliteFlagStore> open() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), _dbName),
      version: _version,
      onCreate: (db, version) async {
        await _createV1(db);
        await _createV2(db);
        await _createV3(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createV2(db);
        if (oldVersion < 3) await _createV3(db);
      },
    );
    return SqliteFlagStore(db);
  }

  static Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS demo_location_flags (
        slot_key TEXT PRIMARY KEY,
        event_id TEXT NOT NULL,
        employee_id TEXT NOT NULL,
        attendance_session_id TEXT NOT NULL,
        date TEXT NOT NULL,
        scheduled_at TEXT NOT NULL,
        captured_at TEXT NOT NULL,
        flag_number INTEGER NOT NULL,
        cycle_id TEXT NOT NULL,
        cycle_start TEXT NOT NULL,
        cycle_end TEXT NOT NULL,
        location_status TEXT,
        slot_kind TEXT NOT NULL,
        phase TEXT NOT NULL,
        check_in_status INTEGER NOT NULL,
        break_status INTEGER NOT NULL,
        check_out_status INTEGER NOT NULL,
        violation INTEGER NOT NULL,
        sync_status TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        accuracy REAL,
        matched_location_id TEXT,
        matched_location_name TEXT,
        office_latitude REAL,
        office_longitude REAL,
        allowed_radius REAL,
        distance REAL,
        failure TEXT,
        requires_server_sync INTEGER NOT NULL,
        sync_attempt_count INTEGER NOT NULL,
        last_sync_attempt TEXT,
        server_synced_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS demo_location_flag_alerts (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        attendance_session_id TEXT NOT NULL,
        flag_event_id TEXT NOT NULL,
        cycle_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        notification_type TEXT NOT NULL,
        location_status TEXT,
        matched_location_id TEXT,
        message TEXT NOT NULL,
        delivered INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS demo_status_intervals (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        date TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT NOT NULL,
        slot_kind TEXT NOT NULL,
        back_in_office INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS demo_issue_hours (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        date TEXT NOT NULL,
        hour_start TEXT NOT NULL,
        saved_at TEXT NOT NULL,
        summary_kind TEXT NOT NULL,
        flags_json TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS demo_flag_sessions (
        employee_id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        phase TEXT NOT NULL,
        checked_in_at TEXT,
        checked_out_at TEXT
      )
    ''');
  }

  static Future<void> _createV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS demo_smart_settings (
        employee_id TEXT PRIMARY KEY,
        premises_notifications INTEGER NOT NULL,
        smart_attendance INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS demo_auto_punches (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        applied INTEGER NOT NULL,
        office_id TEXT,
        office_name TEXT,
        queued_at TEXT
      )
    ''');
  }

  @override
  Future<void> upsertFlag(LocationFlagRecord record) async {
    final map = record.toMap()..['slot_key'] = record.slotKey;
    await _db.insert(
      'demo_location_flags',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertAlert(FlagAlert alert) async {
    await _db.insert(
      'demo_location_flag_alerts',
      alert.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<List<LocationFlagRecord>> flagsFor({
    required String employeeId,
    required String date,
  }) async {
    final rows = await _db.query(
      'demo_location_flags',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
      orderBy: 'scheduled_at ASC',
    );
    return rows.map(LocationFlagRecord.fromMap).toList();
  }

  @override
  Future<List<FlagAlert>> alertsFor(String employeeId) async {
    final rows = await _db.query(
      'demo_location_flag_alerts',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(FlagAlert.fromMap).toList();
  }

  @override
  Future<void> replaceStatusIntervals({
    required String employeeId,
    required String date,
    required List<StatusInterval> intervals,
  }) async {
    await _db.delete(
      'demo_status_intervals',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
    );
    for (final interval in intervals) {
      await _db.insert(
        'demo_status_intervals',
        interval.toMap(employeeId: employeeId, date: date),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  @override
  Future<List<StatusInterval>> statusIntervalsFor({
    required String employeeId,
    required String date,
  }) async {
    final rows = await _db.query(
      'demo_status_intervals',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
      orderBy: 'started_at ASC',
    );
    return rows.map(StatusInterval.fromMap).toList();
  }

  @override
  Future<void> replaceIssueHours({
    required String employeeId,
    required String date,
    required List<MissingOutsideHour> hours,
  }) async {
    await _db.delete(
      'demo_issue_hours',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
    );
    for (final hour in hours) {
      await _db.insert(
        'demo_issue_hours',
        hour.toMap(employeeId: employeeId, date: date),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  @override
  Future<List<MissingOutsideHour>> issueHoursFor({
    required String employeeId,
    required String date,
  }) async {
    final rows = await _db.query(
      'demo_issue_hours',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
      orderBy: 'hour_start DESC',
    );
    return rows.map(MissingOutsideHour.fromMap).toList();
  }

  @override
  Future<void> saveSession(FlagSessionState session) async {
    await _db.insert(
      'demo_flag_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<FlagSessionState?> sessionFor(String employeeId) async {
    final rows = await _db.query(
      'demo_flag_sessions',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FlagSessionState.fromMap(rows.first);
  }

  @override
  Future<void> saveSmartSettings(
    String employeeId,
    SmartAttendanceSettings settings,
  ) async {
    await _db.insert(
      'demo_smart_settings',
      settings.toMap(employeeId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<SmartAttendanceSettings> smartSettingsFor(String employeeId) async {
    final rows = await _db.query(
      'demo_smart_settings',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      limit: 1,
    );
    if (rows.isEmpty) return const SmartAttendanceSettings();
    return SmartAttendanceSettings.fromMap(rows.first);
  }

  @override
  Future<void> upsertAutoPunch(AutoPunchRecord punch) async {
    await _db.insert(
      'demo_auto_punches',
      punch.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<AutoPunchRecord>> autoPunchesFor(String employeeId) async {
    final rows = await _db.query(
      'demo_auto_punches',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(AutoPunchRecord.fromMap).toList();
  }

  @override
  Future<List<AutoPunchRecord>> queuedAutoPunches(String employeeId) async {
    final rows = await _db.query(
      'demo_auto_punches',
      where: 'employee_id = ? AND applied = 0',
      whereArgs: [employeeId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(AutoPunchRecord.fromMap).toList();
  }

  @override
  Future<void> clearEmployee(String employeeId) async {
    await _db.delete(
      'demo_location_flags',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
    await _db.delete(
      'demo_location_flag_alerts',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
    await _db.delete(
      'demo_status_intervals',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
    await _db.delete(
      'demo_issue_hours',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
    await _db.delete(
      'demo_flag_sessions',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
    await _db.delete(
      'demo_smart_settings',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
    await _db.delete(
      'demo_auto_punches',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
  }

  @override
  Future<void> clearFlagsForDate({
    required String employeeId,
    required String date,
  }) async {
    await _db.delete(
      'demo_location_flags',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
    );
    await _db.delete(
      'demo_status_intervals',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
    );
    await _db.delete(
      'demo_issue_hours',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
    );
  }
}
