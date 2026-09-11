import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'package:obecno/features/employee_module/attendance/data/local/attendance_db.dart';
import 'package:obecno/features/more/data/models/reminder_log.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';

class ReminderDao {
  ReminderDao({AttendanceDb? db}) : _db = db ?? AttendanceDb.instance;

  final AttendanceDb _db;

  static const _onByDefault = {
    ReminderType.checkIn,
    ReminderType.checkInMissed,
    ReminderType.checkOut,
    ReminderType.checkOutMissed,
    ReminderType.breakTime,
    ReminderType.breakTimeEnded,
    ReminderType.longerBreak,
    ReminderType.veryLongAttendance,
  };

  Future<Map<ReminderType, bool>> loadSettings(String userId) async {
    final enabled = <ReminderType, bool>{
      for (final type in ReminderType.values) type: _onByDefault.contains(type),
    };
    if (userId.isEmpty) return enabled;

    final db = await _db.database;
    final rows = await db.query(
      AttendanceDb.reminderSettingsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    for (final row in rows) {
      final type = ReminderType.fromStorageKey(
        row['reminder_type']?.toString() ?? '',
      );
      if (type == null) continue;
      enabled[type] = (row['enabled'] as int? ?? 0) == 1;
    }
    return enabled;
  }

  Future<Map<ReminderType, int>> loadRemindMinutes(String userId) async {
    final minutes = <ReminderType, int>{};
    if (userId.isEmpty) return minutes;
    final db = await _db.database;
    final rows = await db.query(
      AttendanceDb.reminderSettingsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    for (final row in rows) {
      final type = ReminderType.fromStorageKey(
        row['reminder_type']?.toString() ?? '',
      );
      final value = row['remind_minutes'] as int?;
      if (type == null || value == null) continue;
      minutes[type] = value;
    }
    return minutes;
  }

  Future<void> setEnabled({
    required String userId,
    required ReminderType type,
    required bool enabled,
  }) async {
    if (userId.isEmpty) return;
    final db = await _db.database;
    final existing = await db.query(
      AttendanceDb.reminderSettingsTable,
      columns: ['remind_minutes'],
      where: 'user_id = ? AND reminder_type = ?',
      whereArgs: [userId, type.storageKey],
      limit: 1,
    );
    await db.insert(
      AttendanceDb.reminderSettingsTable,
      {
        'user_id': userId,
        'reminder_type': type.storageKey,
        'enabled': enabled ? 1 : 0,
        'remind_minutes': existing.isEmpty
            ? null
            : existing.first['remind_minutes'],
        'updated_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setRemindMinutes({
    required String userId,
    required ReminderType type,
    required int minutes,
  }) async {
    if (userId.isEmpty) return;
    final db = await _db.database;
    final existing = await db.query(
      AttendanceDb.reminderSettingsTable,
      columns: ['enabled'],
      where: 'user_id = ? AND reminder_type = ?',
      whereArgs: [userId, type.storageKey],
      limit: 1,
    );
    final enabled = existing.isEmpty
        ? (_onByDefault.contains(type) ? 1 : 0)
        : (existing.first['enabled'] as int? ?? 0);
    await db.insert(
      AttendanceDb.reminderSettingsTable,
      {
        'user_id': userId,
        'reminder_type': type.storageKey,
        'enabled': enabled,
        'remind_minutes': minutes,
        'updated_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearRemindMinutes({
    required String userId,
    required ReminderType type,
  }) async {
    if (userId.isEmpty) return;
    final db = await _db.database;
    final existing = await db.query(
      AttendanceDb.reminderSettingsTable,
      columns: ['enabled'],
      where: 'user_id = ? AND reminder_type = ?',
      whereArgs: [userId, type.storageKey],
      limit: 1,
    );
    final enabled = existing.isEmpty
        ? (_onByDefault.contains(type) ? 1 : 0)
        : (existing.first['enabled'] as int? ?? 0);
    await db.insert(
      AttendanceDb.reminderSettingsTable,
      {
        'user_id': userId,
        'reminder_type': type.storageKey,
        'enabled': enabled,
        'remind_minutes': null,
        'updated_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> insertLogIfAbsent({
    required String userId,
    required DateTime date,
    required ReminderLog log,
  }) async {
    if (userId.isEmpty) return;
    final db = await _db.database;
    final existing = await db.query(
      AttendanceDb.reminderLogsTable,
      columns: ['id'],
      where: 'user_id = ? AND date = ? AND reminder_type = ?',
      whereArgs: [userId, _dateKey(date), log.type.storageKey],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        AttendanceDb.reminderLogsTable,
        {
          'fired_at': log.firedAt.toIso8601String(),
          'title': log.title,
          'message': log.message,
          'clock_status': log.clockStatus,
          'synced': 0,
        },
        where: 'user_id = ? AND date = ? AND reminder_type = ?',
        whereArgs: [userId, _dateKey(date), log.type.storageKey],
      );
      return;
    }

    await db.insert(AttendanceDb.reminderLogsTable, {
      'user_id': userId,
      'date': _dateKey(date),
      'reminder_type': log.type.storageKey,
      'fired_at': log.firedAt.toIso8601String(),
      'title': log.title,
      'message': log.message,
      'clock_status': log.clockStatus,
      'delivered_at': log.deliveredAt?.toIso8601String(),
      'synced': log.synced ? 1 : 0,
    });
  }

  Future<void> deleteLogsOfTypes({
    required String userId,
    required DateTime date,
    required Set<ReminderType> types,
  }) async {
    if (userId.isEmpty || types.isEmpty) return;
    final db = await _db.database;
    final placeholders = List.filled(types.length, '?').join(',');
    await db.delete(
      AttendanceDb.reminderLogsTable,
      where: 'user_id = ? AND date = ? AND reminder_type IN ($placeholders)',
      whereArgs: [
        userId,
        _dateKey(date),
        ...types.map((type) => type.storageKey),
      ],
    );
  }

  Future<List<ReminderLog>> loadLogs({
    required String userId,
    required DateTime date,
  }) async {
    if (userId.isEmpty) return const [];
    final db = await _db.database;
    final rows = await db.query(
      AttendanceDb.reminderLogsTable,
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, _dateKey(date)],
      orderBy: 'fired_at DESC',
    );

    final logs = <ReminderLog>[];
    for (final row in rows) {
      final type = ReminderType.fromStorageKey(
        row['reminder_type']?.toString() ?? '',
      );
      if (type == null) continue;
      final firedAt = DateTime.tryParse(row['fired_at']?.toString() ?? '');
      if (firedAt == null) continue;
      logs.add(
        ReminderLog(
          type: type,
          firedAt: firedAt,
          title: row['title']?.toString() ?? '',
          message: row['message']?.toString() ?? '',
          clockStatus: row['clock_status']?.toString(),
          deliveredAt: DateTime.tryParse(row['delivered_at']?.toString() ?? ''),
          synced: (row['synced'] as int? ?? 0) == 1,
        ),
      );
    }
    return logs;
  }

  Future<List<ReminderPunch>> loadPunches({
    required String userId,
    required DateTime date,
  }) async {
    if (userId.isEmpty) return const [];
    final db = await _db.database;
    final rows = await db.query(
      AttendanceDb.eventsTable,
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, _dateKey(date)],
      orderBy: 'timestamp ASC',
    );

    final punches = <ReminderPunch>[];
    for (final row in rows) {
      final kind = switch (row['type']?.toString()) {
        'check_in' => ReminderPunchKind.checkIn,
        'check_out' => ReminderPunchKind.checkOut,
        'break_start' => ReminderPunchKind.breakStart,
        'break_end' => ReminderPunchKind.breakEnd,
        _ => null,
      };
      if (kind == null) continue;
      final time = DateTime.tryParse(row['timestamp']?.toString() ?? '');
      if (time == null) continue;
      punches.add(ReminderPunch(kind: kind, time: time));
    }
    return punches;
  }

  Future<List<ReminderPunch>?> loadSavedPunches({
    required String userId,
    required DateTime date,
  }) async {
    if (userId.isEmpty) return null;
    final db = await _db.database;
    final state = await db.query(
      AttendanceDb.reminderDayStateTable,
      columns: ['user_id'],
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, _dateKey(date)],
      limit: 1,
    );
    if (state.isEmpty) return null;

    final rows = await db.query(
      AttendanceDb.reminderPunchesTable,
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, _dateKey(date)],
      orderBy: 'punched_at ASC',
    );
    final punches = <ReminderPunch>[];
    for (final row in rows) {
      final kind = ReminderPunchKind.fromName(row['kind']?.toString() ?? '');
      final time = DateTime.tryParse(row['punched_at']?.toString() ?? '');
      if (kind == null || time == null) continue;
      punches.add(ReminderPunch(kind: kind, time: time));
    }
    return punches;
  }

  Future<void> replacePunches({
    required String userId,
    required DateTime date,
    required List<ReminderPunch> punches,
  }) async {
    if (userId.isEmpty) return;
    final db = await _db.database;
    final key = _dateKey(date);
    await db.delete(
      AttendanceDb.reminderPunchesTable,
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, key],
    );
    for (final punch in punches) {
      await db.insert(AttendanceDb.reminderPunchesTable, {
        'user_id': userId,
        'date': key,
        'kind': punch.kind.name,
        'punched_at': punch.time.toIso8601String(),
        'synced': 0,
      });
    }
  }

  Future<void> saveDayState({
    required String userId,
    required DateTime date,
    required ReminderClockStatus status,
    required TimeOfDay checkInTime,
    required TimeOfDay checkOutTime,
    required TimeOfDay breakReminderTime,
    required TimeOfDay breakEndedReminderTime,
    required TimeOfDay policyCheckInTime,
    required TimeOfDay policyCheckOutTime,
    required int graceMinutes,
    required int breakMinutes,
    required int longAttendanceHours,
  }) async {
    if (userId.isEmpty) return;
    final db = await _db.database;
    String hhmm(TimeOfDay time) =>
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    await db.insert(
      AttendanceDb.reminderDayStateTable,
      {
        'user_id': userId,
        'date': _dateKey(date),
        'clock_status': status.storageValue,
        'first_check_in': status.firstCheckIn?.toIso8601String(),
        'last_check_out': status.lastCheckOut?.toIso8601String(),
        'break_start': status.breakStart?.toIso8601String(),
        'break_end': status.breakEnd?.toIso8601String(),
        'check_in_remind_at': hhmm(checkInTime),
        'check_out_remind_at': hhmm(checkOutTime),
        'break_remind_at': hhmm(breakReminderTime),
        'break_end_remind_at': hhmm(breakEndedReminderTime),
        'policy_check_in': hhmm(policyCheckInTime),
        'policy_check_out': hhmm(policyCheckOutTime),
        'grace_minutes': graceMinutes,
        'break_minutes': breakMinutes,
        'long_attendance_hours': longAttendanceHours,
        'updated_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Set<ReminderType>> loadDeliveredTypes({
    required String userId,
    required DateTime date,
  }) async {
    if (userId.isEmpty) return {};
    final db = await _db.database;
    final rows = await db.query(
      AttendanceDb.reminderDeliveriesTable,
      columns: ['reminder_type'],
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, _dateKey(date)],
    );
    return {
      for (final row in rows)
        if (ReminderType.fromStorageKey(
              row['reminder_type']?.toString() ?? '',
            ) !=
            null)
          ReminderType.fromStorageKey(row['reminder_type']!.toString())!,
    };
  }

  Future<List<ReminderLog>> loadDeliveredLogs({
    required String userId,
    required DateTime date,
  }) async {
    if (userId.isEmpty) return const [];
    final db = await _db.database;
    final rows = await db.query(
      AttendanceDb.reminderDeliveriesTable,
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, _dateKey(date)],
    );
    final logs = <ReminderLog>[];
    for (final row in rows) {
      final type = ReminderType.fromStorageKey(
        row['reminder_type']?.toString() ?? '',
      );
      if (type == null) continue;
      final firedAt =
          DateTime.tryParse(row['scheduled_at']?.toString() ?? '') ??
          DateTime.tryParse(row['delivered_at']?.toString() ?? '');
      if (firedAt == null) continue;
      logs.add(
        ReminderLog(
          type: type,
          firedAt: firedAt,
          title: row['title']?.toString() ?? '',
          message: row['message']?.toString() ?? '',
          clockStatus: row['clock_status']?.toString(),
          deliveredAt: DateTime.tryParse(row['delivered_at']?.toString() ?? ''),
        ),
      );
    }
    return logs;
  }

  Future<void> markDelivered({
    required String userId,
    required DateTime date,
    required ReminderLog log,
    required DateTime deliveredAt,
  }) async {
    if (userId.isEmpty) return;
    final db = await _db.database;
    await db.insert(
      AttendanceDb.reminderDeliveriesTable,
      {
        'user_id': userId,
        'date': _dateKey(date),
        'reminder_type': log.type.storageKey,
        'scheduled_at': log.firedAt.toIso8601String(),
        'delivered_at': deliveredAt.toIso8601String(),
        'clock_status': log.clockStatus,
        'title': log.title,
        'message': log.message,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearDelivered({
    required String userId,
    required DateTime date,
    required ReminderType type,
  }) async {
    if (userId.isEmpty) return;
    final db = await _db.database;
    await db.delete(
      AttendanceDb.reminderDeliveriesTable,
      where: 'user_id = ? AND date = ? AND reminder_type = ?',
      whereArgs: [userId, _dateKey(date), type.storageKey],
    );
  }

  Future<void> persistMissingSettings({
    required String userId,
    required Map<ReminderType, bool> enabled,
    required Map<ReminderType, int> remindMinutes,
  }) async {
    if (userId.isEmpty) return;
    final db = await _db.database;
    final existing = await db.query(
      AttendanceDb.reminderSettingsTable,
      columns: ['reminder_type'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final have = {for (final row in existing) row['reminder_type']?.toString()};
    final now = DateTime.now().toIso8601String();
    for (final type in ReminderType.values) {
      if (have.contains(type.storageKey)) continue;
      await db.insert(
        AttendanceDb.reminderSettingsTable,
        {
          'user_id': userId,
          'reminder_type': type.storageKey,
          'enabled': (enabled[type] ?? false) ? 1 : 0,
          'remind_minutes': remindMinutes[type],
          'updated_at': now,
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}
