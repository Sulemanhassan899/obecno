import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/more/data/local/reminder_dao.dart';
import 'package:obecno/features/more/data/models/reminder_log.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';
import 'package:obecno/features/more/services/reminder_engine.dart';

class _MemoryReminderDao extends Fake implements ReminderDao {
  final Map<String, ReminderLog> logs = {};

  String _key(String userId, DateTime date, ReminderType type) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$userId|$y-$m-$d|${type.storageKey}';
  }

  @override
  Future<void> insertLogIfAbsent({
    required String userId,
    required DateTime date,
    required ReminderLog log,
  }) async {
    if (userId.isEmpty) return;
    logs.putIfAbsent(_key(userId, date, log.type), () => log);
  }

  @override
  Future<void> deleteLogsOfTypes({
    required String userId,
    required DateTime date,
    required Set<ReminderType> types,
  }) async {
    if (userId.isEmpty || types.isEmpty) return;
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final prefix = '$userId|$y-$m-$d|';
    logs.removeWhere(
      (key, log) => key.startsWith(prefix) && types.contains(log.type),
    );
  }

  @override
  Future<List<ReminderLog>> loadLogs({
    required String userId,
    required DateTime date,
  }) async {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final prefix = '$userId|$y-$m-$d|';
    return logs.entries
        .where((entry) => entry.key.startsWith(prefix))
        .map((entry) => entry.value)
        .toList();
  }
}

void main() {
  const checkIn = TimeOfDay(hour: 9, minute: 0);
  const checkOut = TimeOfDay(hour: 18, minute: 0);
  final day = DateTime(2026, 9, 9);
  DateTime at(int hour, [int minute = 0]) => DateTime(2026, 9, 9, hour, minute);

  Map<ReminderType, bool> allOn() => {
    for (final type in ReminderType.values) type: true,
  };

  Future<List<ReminderLog>> sync({
    required _MemoryReminderDao dao,
    required DateTime now,
    List<ReminderPunch> punches = const [],
    Map<ReminderType, bool>? enabled,
    TimeOfDay? checkInTime,
    TimeOfDay? checkOutTime,
    TimeOfDay? policyCheckInTime,
    TimeOfDay? policyCheckOutTime,
    TimeOfDay? breakReminderTime,
    TimeOfDay? breakEndedReminderTime,
    int graceMinutes = 5,
    int breakMinutes = 60,
    int longAttendanceHours = 12,
    String userId = 'emp-1',
  }) {
    return ReminderEngine.syncDay(
      dao: dao,
      userId: userId,
      day: day,
      now: now,
      enabled: enabled ?? allOn(),
      checkInTime: checkInTime ?? checkIn,
      checkOutTime: checkOutTime ?? checkOut,
      policyCheckInTime: policyCheckInTime,
      policyCheckOutTime: policyCheckOutTime,
      breakReminderTime: breakReminderTime,
      breakEndedReminderTime: breakEndedReminderTime,
      graceMinutes: graceMinutes,
      breakMinutes: breakMinutes,
      longAttendanceHours: longAttendanceHours,
      punches: punches,
      locationName: 'Islamabad',
    );
  }

  ReminderLog? of(List<ReminderLog> logs, ReminderType type) {
    for (final log in logs) {
      if (log.type == type) return log;
    }
    return null;
  }

  group('happy path', () {
    test('on-time check-in does not log check-in or missed', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(10),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(8, 50)),
        ],
      );
      expect(of(logs, ReminderType.checkIn), isNull);
      expect(of(logs, ReminderType.checkInMissed), isNull);
      expect(of(logs, ReminderType.enterLocation), isNotNull);
    });

    test('on-time checkout logs leave but not checkout reminders', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(18, 10),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ReminderPunch(kind: ReminderPunchKind.checkOut, time: at(17, 55)),
        ],
      );
      expect(of(logs, ReminderType.checkOut), isNull);
      expect(of(logs, ReminderType.checkOutMissed), isNull);
      expect(of(logs, ReminderType.leaveLocation)!.firedAt, at(17, 55));
    });

    test('break reminder logs at the chosen clock time', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(13, 30),
        breakReminderTime: const TimeOfDay(hour: 13, minute: 0),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9))],
      );
      expect(of(logs, ReminderType.breakTime)!.firedAt, at(13));
    });

    test('ending break on time skips longer-break', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(14, 10),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(13)),
          ReminderPunch(kind: ReminderPunchKind.breakEnd, time: at(13, 40)),
        ],
      );
      expect(of(logs, ReminderType.longerBreak), isNull);
    });
  });

  group('critical path', () {
    test('empty user writes nothing', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(10),
        userId: '',
      );
      expect(logs, isEmpty);
    });

    test('future reminders are not written yet', () async {
      final logs = await sync(dao: _MemoryReminderDao(), now: at(8));
      expect(of(logs, ReminderType.checkIn), isNull);
      expect(of(logs, ReminderType.checkInMissed), isNull);
    });

    test('late morning logs check-in and missed catch-up', () async {
      final logs = await sync(dao: _MemoryReminderDao(), now: at(10));
      expect(of(logs, ReminderType.checkIn)!.firedAt, at(9));
      expect(of(logs, ReminderType.checkInMissed)!.firedAt, at(9, 5));
      expect(of(logs, ReminderType.checkIn)!.title, 'Time to check in');
      expect(
        of(logs, ReminderType.checkInMissed)!.title,
        'Missed your check-in?',
      );
    });

    test(
      'late punch vs custom time logs check-in and missed at reminder time',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(9, 10),
          checkInTime: const TimeOfDay(hour: 8, minute: 0),
          policyCheckInTime: checkIn,
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(8, 40)),
          ],
        );
        expect(of(logs, ReminderType.checkIn)!.firedAt, at(8));
        expect(of(logs, ReminderType.checkInMissed)!.firedAt, at(8, 5));
      },
    );

    test('punch after grace logs missed at the reminder time', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(9, 20),
        checkInTime: const TimeOfDay(hour: 8, minute: 0),
        policyCheckInTime: checkIn,
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9, 10)),
        ],
      );
      expect(of(logs, ReminderType.checkInMissed)!.firedAt, at(8, 5));
    });

    test(
      'still checked in after checkout logs both checkout notices',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(18, 20),
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ],
        );
        expect(of(logs, ReminderType.checkOut)!.firedAt, at(18));
        expect(of(logs, ReminderType.checkOutMissed)!.firedAt, at(18, 5));
      },
    );

    test('custom earlier checkout logs missed after the reminder', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(18, 20),
        checkOutTime: const TimeOfDay(hour: 17, minute: 0),
        policyCheckOutTime: checkOut,
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9))],
      );
      expect(of(logs, ReminderType.checkOut)!.firedAt, at(17));
      expect(of(logs, ReminderType.checkOutMissed)!.firedAt, at(17, 5));
    });

    test('eight hours still checked in does not log still-working', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(18),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(10))],
      );
      expect(of(logs, ReminderType.veryLongAttendance), isNull);
    });

    test('twelve hours still checked in logs still-working at punch + 12h', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(22, 10),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(10))],
      );
      expect(of(logs, ReminderType.veryLongAttendance)!.firedAt, at(22));
    });

    test('not checked in does not log still-working or break', () async {
      final logs = await sync(dao: _MemoryReminderDao(), now: at(15, 51));
      expect(of(logs, ReminderType.veryLongAttendance), isNull);
      expect(of(logs, ReminderType.breakTime), isNull);
      expect(of(logs, ReminderType.checkIn)!.firedAt, at(9));
    });

    test('check-in at policy time after 8am reminder logs missed at 8:05', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(9, 10),
        checkInTime: const TimeOfDay(hour: 8, minute: 0),
        policyCheckInTime: checkIn,
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
        ],
      );
      expect(of(logs, ReminderType.checkIn)!.firedAt, at(8));
      expect(of(logs, ReminderType.checkInMissed)!.firedAt, at(8, 5));
    });

    test('overtime logs very long attendance', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(21, 10),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9))],
      );
      expect(of(logs, ReminderType.veryLongAttendance)!.firedAt, at(21));
      expect(
        of(logs, ReminderType.veryLongAttendance)!.timelineLabel,
        'Checked in for 12 hours.',
      );
    });

    test('staying on break logs break-ended before the longer-break hour', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(14, 10),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(13)),
        ],
      );
      expect(of(logs, ReminderType.longerBreak), isNull);
      expect(of(logs, ReminderType.breakTimeEnded)!.firedAt, at(14));
    });

    test('staying on break an hour after duration logs longer-break', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(15, 1),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(13)),
        ],
      );
      expect(of(logs, ReminderType.longerBreak)!.firedAt, at(15));
      expect(of(logs, ReminderType.breakTimeEnded)!.firedAt, at(14));
    });

    test('disabled types are skipped', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(10),
        enabled: {
          for (final type in ReminderType.values) type: false,
          ReminderType.checkIn: true,
        },
      );
      expect(logs.map((e) => e.type).toSet(), {ReminderType.checkIn});
    });

    test('the same reminder is not logged twice', () async {
      final dao = _MemoryReminderDao();
      await sync(dao: dao, now: at(10));
      final second = await sync(dao: dao, now: at(11));
      expect(
        second.where((log) => log.type == ReminderType.checkIn),
        hasLength(1),
      );
      expect(
        second.where((log) => log.type == ReminderType.checkInMissed),
        hasLength(1),
      );
    });

    test(
      'starting a break before the reminder skips the take-break log',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(13, 30),
          breakReminderTime: const TimeOfDay(hour: 13, minute: 25),
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
            ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(13)),
          ],
        );
        expect(of(logs, ReminderType.breakTime), isNull);
      },
    );

    test('8:30 reminder logs at 8:30, missed at 8:35', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(8, 45),
        checkInTime: const TimeOfDay(hour: 8, minute: 30),
        policyCheckInTime: checkIn,
      );
      expect(of(logs, ReminderType.checkIn)!.firedAt, at(8, 30));
      expect(of(logs, ReminderType.checkInMissed)!.firedAt, at(8, 35));
    });

    test('punch at 8:40 after 8:30 reminder still logs missed at 8:35', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(8, 50),
        checkInTime: const TimeOfDay(hour: 8, minute: 30),
        policyCheckInTime: checkIn,
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(8, 40)),
        ],
      );
      expect(of(logs, ReminderType.checkIn)!.firedAt, at(8, 30));
      expect(of(logs, ReminderType.checkInMissed)!.firedAt, at(8, 35));
    });

    test(
      'no punch by 9:10 logs missed at the reminder time, not permission time',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(9, 10),
          checkInTime: const TimeOfDay(hour: 8, minute: 30),
          policyCheckInTime: checkIn,
        );
        expect(of(logs, ReminderType.checkIn)!.firedAt, at(8, 30));
        expect(of(logs, ReminderType.checkInMissed)!.firedAt, at(8, 35));
      },
    );

    test('5:30 checkout reminder logs missed at 5:35, not permission 6:05', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(18, 20),
        checkOutTime: const TimeOfDay(hour: 17, minute: 30),
        policyCheckOutTime: checkOut,
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9))],
      );
      expect(of(logs, ReminderType.checkOut)!.firedAt, at(17, 30));
      expect(of(logs, ReminderType.checkOutMissed)!.firedAt, at(17, 35));
    });

    test('timeline stores notification time, not permission time', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(10),
        checkInTime: const TimeOfDay(hour: 8, minute: 0),
        policyCheckInTime: checkIn,
        graceMinutes: 30,
      );
      expect(of(logs, ReminderType.checkIn)!.firedAt, at(8));
      expect(of(logs, ReminderType.checkInMissed)!.firedAt, at(8, 30));
      expect(of(logs, ReminderType.checkIn)!.timelineLabel, 'Check In');
      expect(
        of(logs, ReminderType.checkInMissed)!.timelineLabel,
        'Check In Missed',
      );
    });

    test('break reminder at chosen time logs with no break punch', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(12, 5),
        breakReminderTime: const TimeOfDay(hour: 12, minute: 0),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9))],
      );
      expect(of(logs, ReminderType.breakTime)!.firedAt, at(12));
    });

    test('break-end reminder at chosen time logs while on break', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(14, 5),
        breakEndedReminderTime: const TimeOfDay(hour: 14, minute: 0),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(13, 45)),
        ],
      );
      expect(of(logs, ReminderType.breakTimeEnded)!.firedAt, at(14));
    });

    test('timeline rows attach to the matching punch kind', () {
      final logs = [
        ReminderLog(
          type: ReminderType.checkInMissed,
          firedAt: at(9, 5),
          title: 'Missed',
          message: 'in',
        ),
        ReminderLog(
          type: ReminderType.longerBreak,
          firedAt: at(13, 50),
          title: 'Longer',
          message: 'break',
        ),
      ];
      expect(
        ReminderEngine.logsFor(ReminderPunchKind.checkIn, logs).single.type,
        ReminderType.checkInMissed,
      );
      expect(
        ReminderEngine.logsFor(ReminderPunchKind.breakEnd, logs).single.type,
        ReminderType.longerBreak,
      );
    });
  });
}
