import 'package:sqflite/sqflite.dart';

import 'package:Obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'attendance_db.dart';

/// Data-access layer over [AttendanceDb]. Knows nothing about the API or
/// UI models — only [AttendanceDay] in, [AttendanceDay] out.
///
/// One month is written in a single transaction (`upsertMonth`) so a
/// crash/kill mid-write can never leave a month half-cached.
class AttendanceDao {
  AttendanceDao({AttendanceDb? db}) : _db = db ?? AttendanceDb.instance;

  final AttendanceDb _db;

  // ---------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------

  /// UPSERTs every day of [days] plus the month's synced/empty flag.
  /// Safe to call repeatedly for the same month — never duplicates rows,
  /// never clears unrelated months.
  Future<void> upsertMonth(DateTime month, List<AttendanceDay> days) async {
    final db = await _db.database;
    final monthKey = _monthKey(month);

    await db.transaction((txn) async {
      for (final day in days) {
        await _upsertDay(txn, day);
      }

      await txn.insert(
        AttendanceDb.monthMetaTable,
        {
          'month': monthKey,
          'is_empty': days.isEmpty ? 1 : 0,
          'synced_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> _upsertDay(Transaction txn, AttendanceDay day) async {
    final dateKey = _dateKey(day.date);
    final monthKey = _monthKey(day.date);

    final totalBreak = day.breaks.fold<Duration>(
      Duration.zero,
      (sum, b) => sum + _diff(day.date, from: b.breakIn, to: b.breakOut),
    );
    final totalWork = (day.firstCheckIn != null && day.lastCheckOut != null)
        ? _diff(day.date, from: day.firstCheckIn!, to: day.lastCheckOut!) -
              totalBreak
        : Duration.zero;

    await txn.insert(
      AttendanceDb.daysTable,
      {
        'date': dateKey,
        'month': monthKey,
        'record_id': day.recordId,
        'first_check_in': day.firstCheckIn,
        'last_check_out': day.lastCheckOut,
        'total_work_duration': totalWork.isNegative ? 0 : totalWork.inSeconds,
        'total_break_duration': totalBreak.inSeconds,
        'is_edited': day.isEdited ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Replace this day's events wholesale — simplest way to guarantee no
    // stale/duplicate events survive a re-sync of the same day.
    await txn.delete(AttendanceDb.eventsTable, where: 'date = ?', whereArgs: [dateKey]);

    var index = 0;
    Future<void> insertEvent(String type, String time) {
      final id = '${dateKey}_${type}_${index++}';
      return txn.insert(AttendanceDb.eventsTable, {
        'id': id,
        'date': dateKey,
        'type': type,
        'timestamp': _combine(day.date, time).toIso8601String(),
      });
    }

    for (final t in day.checkIns) {
      await insertEvent('check_in', t);
    }
    for (final b in day.breaks) {
      await insertEvent('break_start', b.breakIn);
      await insertEvent('break_end', b.breakOut);
    }
    for (final t in day.checkOuts) {
      await insertEvent('check_out', t);
    }
  }

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  Future<bool> isMonthSynced(DateTime month) async {
    final db = await _db.database;
    final rows = await db.query(
      AttendanceDb.monthMetaTable,
      where: 'month = ?',
      whereArgs: [_monthKey(month)],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> isMonthEmpty(DateTime month) async {
    final db = await _db.database;
    final rows = await db.query(
      AttendanceDb.monthMetaTable,
      where: 'month = ?',
      whereArgs: [_monthKey(month)],
      limit: 1,
    );
    if (rows.isEmpty) return true;
    return (rows.first['is_empty'] as int? ?? 0) == 1;
  }

  Future<bool> hasAnyData() async {
    final db = await _db.database;
    final rows = await db.query(AttendanceDb.monthMetaTable, limit: 1);
    return rows.isNotEmpty;
  }

  Future<List<String>> getLoadedMonths() async {
    final db = await _db.database;
    final rows = await db.query(
      AttendanceDb.monthMetaTable,
      columns: ['month'],
      orderBy: 'month DESC',
    );
    return rows.map((r) => r['month'] as String).toList();
  }

  Future<List<AttendanceDay>> getDaysForMonth(DateTime month) async {
    final db = await _db.database;

    final dayRows = await db.query(
      AttendanceDb.daysTable,
      where: 'month = ?',
      whereArgs: [_monthKey(month)],
      orderBy: 'date DESC',
    );

    final days = <AttendanceDay>[];

    for (final row in dayRows) {
      final dateKey = row['date'] as String;
      final date = DateTime.parse(dateKey);

      final eventRows = await db.query(
        AttendanceDb.eventsTable,
        where: 'date = ?',
        whereArgs: [dateKey],
        orderBy: 'timestamp ASC',
      );

      final checkIns = <String>[];
      final checkOuts = <String>[];
      final breakStarts = <String>[];
      final breakEnds = <String>[];

      for (final e in eventRows) {
        final time = _timeOnly(e['timestamp'] as String);
        switch (e['type'] as String) {
          case 'check_in':
            checkIns.add(time);
            break;
          case 'check_out':
            checkOuts.add(time);
            break;
          case 'break_start':
            breakStarts.add(time);
            break;
          case 'break_end':
            breakEnds.add(time);
            break;
        }
      }

      final breaks = <BreakSession>[
        for (var i = 0; i < breakStarts.length && i < breakEnds.length; i++)
          BreakSession(breakIn: breakStarts[i], breakOut: breakEnds[i]),
      ];

      days.add(
        AttendanceDay(
          date: DateTime(date.year, date.month, date.day),
          recordId: row['record_id'] as int?,
          checkIns: checkIns,
          checkOuts: checkOuts,
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

  String _timeOnly(String isoTimestamp) {
    final dt = DateTime.parse(isoTimestamp);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
