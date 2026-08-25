
import 'package:sqflite/sqflite.dart';

import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'attendance_db.dart';

class AttendanceDao {
  AttendanceDao({AttendanceDb? db}) : _db = db ?? AttendanceDb.instance;

  final AttendanceDb _db;
  Future<void> upsertMonth(
    String userId,
    DateTime month,
    List<AttendanceDay> days,
  ) async {
    final db = await _db.database;
    final monthKey = _monthKey(month);

    await db.transaction((txn) async {
      // Wipe the previous fetch for this month before storing the new one.
      final staleDates = await txn.query(
        AttendanceDb.daysTable,
        columns: ['date'],
        where: 'month = ? AND user_id = ?',
        whereArgs: [monthKey, userId],
      );
      for (final row in staleDates) {
        await txn.delete(
          AttendanceDb.eventsTable,
          where: 'date = ? AND user_id = ?',
          whereArgs: [row['date'], userId],
        );
      }
      await txn.delete(
        AttendanceDb.daysTable,
        where: 'month = ? AND user_id = ?',
        whereArgs: [monthKey, userId],
      );

      for (final day in days) {
        await _upsertDay(txn, userId, day);
      }

      await txn.insert(AttendanceDb.monthMetaTable, {
        'month': monthKey,
        'user_id': userId,
        'is_empty': days.isEmpty ? 1 : 0,
        'synced_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> _upsertDay(
    Transaction txn,
    String userId,
    AttendanceDay day,
  ) async {
    final dateKey = _dateKey(day.date);
    final monthKey = _monthKey(day.date);

    final totalBreak = day.breaks.fold<Duration>(
      Duration.zero,
      // BreakSession: breakOut = start, breakIn = end (API naming).
      (sum, b) => sum + _diff(day.date, from: b.breakOut, to: b.breakIn),
    );

    // Session-aware work duration: sum each check-in→check-out segment,
    // then subtract breaks (matches AttendanceEngine behaviour).
    final totalWork = _computeWorkDuration(day) - totalBreak;

    await txn.insert(AttendanceDb.daysTable, {
      'date': dateKey,
      'user_id': userId,
      'month': monthKey,
      'record_id': day.recordId,
      'first_check_in': day.firstCheckIn,
      'last_check_out': day.lastCheckOut,
      'total_work_duration': totalWork.isNegative ? 0 : totalWork.inSeconds,
      'total_break_duration': totalBreak.inSeconds,
      'is_edited': day.isEdited ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await txn.delete(
      AttendanceDb.eventsTable,
      where: 'date = ? AND user_id = ?',
      whereArgs: [dateKey, userId],
    );

    var index = 0;
    Future<void> insertEvent(String type, String time, String? location) {
      final id = '${dateKey}_${type}_${index++}';
      return txn.insert(AttendanceDb.eventsTable, {
        'id': id,
        'user_id': userId,
        'date': dateKey,
        'type': type,
        'timestamp': _combine(day.date, time).toIso8601String(),
        'location': location,
      });
    }

    for (var i = 0; i < day.checkIns.length; i++) {
      final loc = i < day.checkInLocations.length
          ? day.checkInLocations[i]
          : null;
      await insertEvent('check_in', day.checkIns[i], loc);
    }
    for (final b in day.breaks) {
      // Stored with swapped start/end labels intentionally so the existing
      // read path can rebuild BreakSession with API naming
      // (breakOut = start, breakIn = end). Do not "fix" without a
      // matching read-side migration.
      await insertEvent('break_start', b.breakIn, b.breakInLocation);
      await insertEvent('break_end', b.breakOut, b.breakOutLocation);
    }
    for (var i = 0; i < day.checkOuts.length; i++) {
      final loc = i < day.checkOutLocations.length
          ? day.checkOutLocations[i]
          : null;
      await insertEvent('check_out', day.checkOuts[i], loc);
    }
  }

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  Future<bool> isMonthSynced(String userId, DateTime month) async {
    final db = await _db.database;
    final rows = await db.query(
      AttendanceDb.monthMetaTable,
      where: 'month = ? AND user_id = ?',
      whereArgs: [_monthKey(month), userId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> isMonthEmpty(String userId, DateTime month) async {
    final db = await _db.database;
    final rows = await db.query(
      AttendanceDb.monthMetaTable,
      where: 'month = ? AND user_id = ?',
      whereArgs: [_monthKey(month), userId],
      limit: 1,
    );
    if (rows.isEmpty) return true;
    return (rows.first['is_empty'] as int? ?? 0) == 1;
  }

  Future<bool> hasAnyData(String userId) async {
    final db = await _db.database;
    final rows = await db.query(
      AttendanceDb.monthMetaTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<String>> getLoadedMonths(String userId) async {
    final db = await _db.database;
    final rows = await db.query(
      AttendanceDb.monthMetaTable,
      columns: ['month'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'month DESC',
    );
    return rows.map((r) => r['month'] as String).toList();
  }

  Future<List<AttendanceDay>> getDaysForMonth(
    String userId,
    DateTime month,
  ) async {
    final db = await _db.database;

    final dayRows = await db.query(
      AttendanceDb.daysTable,
      where: 'month = ? AND user_id = ?',
      whereArgs: [_monthKey(month), userId],
      orderBy: 'date DESC',
    );

    final days = <AttendanceDay>[];

    for (final row in dayRows) {
      final dateKey = row['date'] as String;
      final date = DateTime.parse(dateKey);

      final eventRows = await db.query(
        AttendanceDb.eventsTable,
        where: 'date = ? AND user_id = ?',
        whereArgs: [dateKey, userId],
        orderBy: 'timestamp ASC',
      );

      final checkIns = <String>[];
      final checkInLocations = <String?>[];
      final checkOuts = <String>[];
      final checkOutLocations = <String?>[];
      final breakStarts = <String>[];
      final breakStartLocations = <String?>[];
      final breakEnds = <String>[];
      final breakEndLocations = <String?>[];

      for (final e in eventRows) {
        final time = _timeOnly(e['timestamp'] as String);
        final location = e['location'] as String?;
        switch (e['type'] as String) {
          case 'check_in':
            checkIns.add(time);
            checkInLocations.add(location);
            break;
          case 'check_out':
            checkOuts.add(time);
            checkOutLocations.add(location);
            break;
          case 'break_start':
            breakStarts.add(time);
            breakStartLocations.add(location);
            break;
          case 'break_end':
            breakEnds.add(time);
            breakEndLocations.add(location);
            break;
        }
      }

      final breaks = <BreakSession>[
        for (var i = 0; i < breakStarts.length && i < breakEnds.length; i++)
          BreakSession(
            breakIn: breakStarts[i],
            breakOut: breakEnds[i],
            breakInLocation: breakStartLocations[i],
            breakOutLocation: breakEndLocations[i],
          ),
      ];

      days.add(
        AttendanceDay(
          date: DateTime(date.year, date.month, date.day),
          recordId: row['record_id'] as int?,
          checkIns: checkIns,
          checkOuts: checkOuts,
          checkInLocations: checkInLocations,
          checkOutLocations: checkOutLocations,
          breaks: breaks,
          isEdited: (row['is_edited'] as int? ?? 0) == 1,
        ),
      );
    }

    return days;
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Parses "HH:mm[:ss]" against [date] into an absolute DateTime.
  DateTime _combine(DateTime date, String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts.elementAt(0)) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final s = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, h, m, s);
  }

  Duration _diff(DateTime date, {required String from, required String to}) {
    return _combine(date, to).difference(_combine(date, from));
  }

  /// Sums closed check-in → check-out segments for [day], ignoring open
  /// sessions and the time between sessions (when the user is checked out).
  Duration _computeWorkDuration(AttendanceDay day) {
    final stamps = <({DateTime time, bool isIn})>[
      for (final t in day.checkIns) (time: _combine(day.date, t), isIn: true),
      for (final t in day.checkOuts) (time: _combine(day.date, t), isIn: false),
    ]..sort((a, b) => a.time.compareTo(b.time));

    Duration working = Duration.zero;
    DateTime? openStart;
    for (final stamp in stamps) {
      if (stamp.isIn) {
        openStart = stamp.time;
      } else if (openStart != null) {
        working += stamp.time.difference(openStart);
        openStart = null;
      }
    }
    return working.isNegative ? Duration.zero : working;
  }

  String _timeOnly(String isoTimestamp) {
    final dt = DateTime.parse(isoTimestamp);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}