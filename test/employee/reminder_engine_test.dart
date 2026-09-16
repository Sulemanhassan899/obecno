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

    test('break reminder before check-in is not catch-up logged', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(0, 20),
        checkInTime: const TimeOfDay(hour: 0, minute: 20),
        breakReminderTime: const TimeOfDay(hour: 0, minute: 17),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(0, 20)),
        ],
      );
      expect(of(logs, ReminderType.breakTime), isNull);
      expect(of(logs, ReminderType.checkOut), isNull);
    });

    test('stale break log from before check-in is pruned', () async {
      final dao = _MemoryReminderDao();
      await dao.insertLogIfAbsent(
        userId: 'emp-1',
        date: day,
        log: ReminderLog(
          type: ReminderType.breakTime,
          firedAt: at(0, 17),
          title: 'Break coming up',
          message: 'Your break starts in 5 minutes.',
        ),
      );
      final logs = await sync(
        dao: dao,
        now: at(0, 20),
        checkInTime: const TimeOfDay(hour: 0, minute: 20),
        breakReminderTime: const TimeOfDay(hour: 0, minute: 17),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(0, 20)),
        ],
      );
      expect(of(logs, ReminderType.breakTime), isNull);
    });

    test('break reminder after check-in still logs', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(13, 30),
        breakReminderTime: const TimeOfDay(hour: 13, minute: 0),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9))],
      );
      expect(of(logs, ReminderType.breakTime)!.firedAt, at(13));
    });

    test(
      'finished earlier break does not skip the later take-break reminder',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(22, 28),
          breakReminderTime: const TimeOfDay(hour: 22, minute: 28),
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(10, 19)),
            ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(22, 25)),
            ReminderPunch(kind: ReminderPunchKind.breakEnd, time: at(22, 27)),
          ],
        );
        expect(of(logs, ReminderType.breakTime)!.firedAt, at(22, 28));
      },
    );

    test(
      'take-break at the reminder time still logs under that break',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(22, 30),
          breakReminderTime: const TimeOfDay(hour: 22, minute: 28),
          breakEndedReminderTime: const TimeOfDay(hour: 22, minute: 30),
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(10, 19)),
            ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(22, 25)),
            ReminderPunch(kind: ReminderPunchKind.breakEnd, time: at(22, 27)),
            ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(22, 28)),
            ReminderPunch(kind: ReminderPunchKind.breakEnd, time: at(22, 30)),
          ],
        );
        expect(of(logs, ReminderType.breakTime)!.firedAt, at(22, 28));
        expect(of(logs, ReminderType.breakTimeEnded)!.firedAt, at(22, 30));
      },
    );

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

    test(
      'ending break after the settings clock still lists break-ended',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(14, 40),
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
            ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(13)),
            ReminderPunch(kind: ReminderPunchKind.breakEnd, time: at(14, 35)),
          ],
        );
        expect(of(logs, ReminderType.breakTimeEnded)!.firedAt, at(14, 30));
        expect(
          of(logs, ReminderType.breakTimeEnded)!.timelineLabel,
          'Break time ended',
        );
        expect(of(logs, ReminderType.longerBreak), isNull);
      },
    );
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

    test(
      'twelve hours still checked in logs still-working at punch + 12h',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(22, 10),
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(10)),
          ],
        );
        expect(of(logs, ReminderType.veryLongAttendance)!.firedAt, at(22));
      },
    );

    test('not checked in does not log still-working or break', () async {
      final logs = await sync(dao: _MemoryReminderDao(), now: at(15, 51));
      expect(of(logs, ReminderType.veryLongAttendance), isNull);
      expect(of(logs, ReminderType.breakTime), isNull);
      expect(of(logs, ReminderType.checkIn)!.firedAt, at(9));
    });

    test(
      'check-in at policy time after 8am reminder logs missed at 8:05',
      () async {
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
      },
    );

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

    test('custom long attendance hours are used for overtime', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(17, 10),
        longAttendanceHours: 8,
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9))],
      );
      expect(of(logs, ReminderType.veryLongAttendance)!.firedAt, at(17));
      expect(
        of(logs, ReminderType.veryLongAttendance)!.timelineLabel,
        'Checked in for 8 hours.',
      );
      expect(
        of(logs, ReminderType.veryLongAttendance)!.message,
        "You've been checked in for 8 hours.",
      );
    });

    test('custom long attendance minutes are used for overtime', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(9, 10),
        longAttendanceHours: 10,
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9))],
      );
      expect(of(logs, ReminderType.veryLongAttendance)!.firedAt, at(9, 10));
      expect(
        of(logs, ReminderType.veryLongAttendance)!.timelineLabel,
        'Checked in for 10 minutes.',
      );
    });

    test(
      'every long-attendance picker from 10 minutes to 12 hours logs at punch plus duration',
      () async {
        final durations = ReminderCopy.durationOptionsInMinutes
            .where((minutes) => minutes <= 12 * 60)
            .toList();
        expect(durations.first, 5);
        expect(durations.last, 12 * 60);
        final checkInAt = at(9);
        for (final minutes in durations) {
          final fireAt = checkInAt.add(Duration(minutes: minutes));
          final before = await sync(
            dao: _MemoryReminderDao(),
            now: fireAt.subtract(const Duration(minutes: 1)),
            longAttendanceHours: minutes,
            punches: [
              ReminderPunch(kind: ReminderPunchKind.checkIn, time: checkInAt),
            ],
          );
          expect(
            of(before, ReminderType.veryLongAttendance),
            isNull,
            reason: '$minutes minutes logged too early',
          );

          final onTime = await sync(
            dao: _MemoryReminderDao(),
            now: fireAt,
            longAttendanceHours: minutes,
            punches: [
              ReminderPunch(kind: ReminderPunchKind.checkIn, time: checkInAt),
            ],
          );
          expect(
            of(onTime, ReminderType.veryLongAttendance)!.firedAt,
            fireAt,
            reason: '$minutes minutes missed the fire time',
          );
          expect(
            of(onTime, ReminderType.veryLongAttendance)!.timelineLabel,
            ReminderCopy.longAttendanceTimeline(minutes),
          );

          final late = await sync(
            dao: _MemoryReminderDao(),
            now: fireAt.add(const Duration(minutes: 7)),
            longAttendanceHours: minutes,
            punches: [
              ReminderPunch(kind: ReminderPunchKind.checkIn, time: checkInAt),
            ],
          );
          expect(
            of(late, ReminderType.veryLongAttendance)!.firedAt,
            fireAt,
            reason: '$minutes minutes skipped after the fire time',
          );
        }
      },
    );

    test(
      'long attendance still logs on a later checkout if they stayed through it',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(9, 20),
          longAttendanceHours: 10,
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
            ReminderPunch(kind: ReminderPunchKind.checkOut, time: at(9, 15)),
          ],
        );
        expect(of(logs, ReminderType.veryLongAttendance)!.firedAt, at(9, 10));
      },
    );

    test(
      'long attendance does not log when they checkout before the duration',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(9, 20),
          longAttendanceHours: 10,
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
            ReminderPunch(kind: ReminderPunchKind.checkOut, time: at(9, 5)),
          ],
        );
        expect(of(logs, ReminderType.veryLongAttendance), isNull);
      },
    );

    test('long attendance still logs while on break', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(9, 12),
        longAttendanceHours: 10,
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(9, 5)),
        ],
      );
      expect(of(logs, ReminderType.veryLongAttendance)!.firedAt, at(9, 10));
    });

    test('staying on break logs break-ended at the settings clock', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(14, 35),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(13)),
        ],
      );
      expect(of(logs, ReminderType.longerBreak), isNull);
      expect(of(logs, ReminderType.breakTimeEnded)!.firedAt, at(14, 30));
    });

    test(
      'staying on break an hour after the settings clock logs longer-break',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(15, 35),
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
            ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(13)),
          ],
        );
        expect(of(logs, ReminderType.longerBreak)!.firedAt, at(15, 30));
        expect(of(logs, ReminderType.breakTimeEnded)!.firedAt, at(14, 30));
      },
    );

    test('afternoon break logs at start plus duration, not 2:30', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(16, 30),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(15, 28)),
        ],
      );
      expect(of(logs, ReminderType.breakTimeEnded)!.firedAt, at(16, 28));
    });

    test('second break logs from the open break start', () async {
      final logs = await sync(
        dao: _MemoryReminderDao(),
        now: at(16, 5),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(11)),
          ReminderPunch(kind: ReminderPunchKind.breakEnd, time: at(11, 20)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(15)),
        ],
      );
      expect(of(logs, ReminderType.breakTimeEnded)!.firedAt, at(16));
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

    test(
      'punch at 8:40 after 8:30 reminder still logs missed at 8:35',
      () async {
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
      },
    );

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

    test(
      '5:30 checkout reminder logs missed at 5:35, not permission 6:05',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(18, 20),
          checkOutTime: const TimeOfDay(hour: 17, minute: 30),
          policyCheckOutTime: checkOut,
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ],
        );
        expect(of(logs, ReminderType.checkOut)!.firedAt, at(17, 30));
        expect(of(logs, ReminderType.checkOutMissed)!.firedAt, at(17, 35));
      },
    );

    test(
      'later check-in reminder logs missed after chosen time plus grace',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(10, 20),
          checkInTime: const TimeOfDay(hour: 10, minute: 0),
          policyCheckInTime: checkIn,
          graceMinutes: 15,
        );
        expect(of(logs, ReminderType.checkIn)!.firedAt, at(10));
        expect(of(logs, ReminderType.checkInMissed)!.firedAt, at(10, 15));
      },
    );

    test(
      'later checkout reminder logs missed after chosen time plus grace',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(19, 20),
          checkOutTime: const TimeOfDay(hour: 19, minute: 0),
          policyCheckOutTime: checkOut,
          graceMinutes: 10,
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ],
        );
        expect(of(logs, ReminderType.checkOut)!.firedAt, at(19));
        expect(of(logs, ReminderType.checkOutMissed)!.firedAt, at(19, 10));
      },
    );

    test(
      '12 AM to 12 PM permission logs checkout missed at noon plus grace',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(12, 10),
          checkInTime: const TimeOfDay(hour: 0, minute: 0),
          checkOutTime: const TimeOfDay(hour: 12, minute: 0),
          policyCheckInTime: const TimeOfDay(hour: 0, minute: 0),
          policyCheckOutTime: const TimeOfDay(hour: 12, minute: 0),
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(0, 10)),
          ],
        );
        expect(of(logs, ReminderType.checkOut)!.firedAt, at(12));
        expect(of(logs, ReminderType.checkOutMissed)!.firedAt, at(12, 5));
      },
    );

    test(
      'checked in all day with no break or checkout logs every due reminder',
      () async {
        final logs = await sync(
          dao: _MemoryReminderDao(),
          now: at(23, 10),
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(8, 46)),
          ],
        );
        expect(of(logs, ReminderType.checkIn), isNull);
        expect(of(logs, ReminderType.checkInMissed), isNull);
        expect(of(logs, ReminderType.breakTime)!.firedAt, at(13, 25));
        expect(of(logs, ReminderType.breakTimeEnded), isNull);
        expect(of(logs, ReminderType.longerBreak), isNull);
        expect(of(logs, ReminderType.checkOut)!.firedAt, at(18));
        expect(of(logs, ReminderType.checkOutMissed)!.firedAt, at(18, 5));
        expect(of(logs, ReminderType.veryLongAttendance)!.firedAt, at(20, 46));
      },
    );

    test(
      'opening the sheet after a quiet day lists missed notices above the card',
      () {
        final logs = [
          ReminderLog(
            type: ReminderType.veryLongAttendance,
            firedAt: at(20, 46),
            title: 'Still working?',
            message: "You've been checked in for 12 hours.",
          ),
          ReminderLog(
            type: ReminderType.checkOutMissed,
            firedAt: at(18, 5),
            title: 'Still checked in?',
            message: "Check out if you've finished work.",
          ),
          ReminderLog(
            type: ReminderType.checkOut,
            firedAt: at(18),
            title: 'Time to check out',
            message: 'Wrapping up for today?',
          ),
          ReminderLog(
            type: ReminderType.breakTime,
            firedAt: at(13, 25),
            title: 'Break coming up',
            message: 'Your break starts in 5 minutes.',
          ),
        ];
        final items = ReminderEngine.mixTimeline(
          punchTimes: [at(8, 46)],
          primaryKinds: const [ReminderPunchKind.checkIn],
          logs: logs,
        );
        expect(items, hasLength(2));
        expect(items.first.isPunch, isFalse);
        expect(items.first.standaloneLogs.map((log) => log.type).toList(), [
          ReminderType.veryLongAttendance,
          ReminderType.checkOutMissed,
          ReminderType.checkOut,
          ReminderType.breakTime,
        ]);
        expect(items.last.isPunch, isTrue);
        expect(items.last.attachedLogs, isEmpty);
      },
    );

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

    test(
      'break-end reminder sits above cards while on break, like break start',
      () {
        final logs = [
          ReminderLog(
            type: ReminderType.breakTimeEnded,
            firedAt: at(14, 30),
            title: 'Break time is over',
            message: 'Ready to get back to work?',
          ),
        ];
        final items = ReminderEngine.mixTimeline(
          punchTimes: [at(13), at(9)],
          primaryKinds: const [
            ReminderPunchKind.breakStart,
            ReminderPunchKind.checkIn,
          ],
          logs: logs,
        );
        expect(items, hasLength(3));
        expect(items.first.isPunch, isFalse);
        expect(
          items.first.standaloneLogs.single.type,
          ReminderType.breakTimeEnded,
        );
        expect(items[1].isPunch, isTrue);
        expect(items[1].attachedLogs, isEmpty);
        expect(items.last.attachedLogs, isEmpty);
      },
    );

    test(
      'break-end reminder attaches to the break-end card after punch back',
      () {
        final logs = [
          ReminderLog(
            type: ReminderType.breakTimeEnded,
            firedAt: at(14, 30),
            title: 'Break time is over',
            message: 'Ready to get back to work?',
          ),
        ];
        final items = ReminderEngine.mixTimeline(
          punchTimes: [at(14, 35), at(13), at(9)],
          primaryKinds: const [
            ReminderPunchKind.breakEnd,
            ReminderPunchKind.breakStart,
            ReminderPunchKind.checkIn,
          ],
          logs: logs,
        );
        expect(items.every((item) => item.isPunch), isTrue);
        expect(
          items.first.attachedLogs.single.type,
          ReminderType.breakTimeEnded,
        );
        expect(items[1].attachedLogs, isEmpty);
      },
    );

    test(
      'earlier break-end punch does not hide a later break-end reminder',
      () {
        final logs = [
          ReminderLog(
            type: ReminderType.breakTimeEnded,
            firedAt: at(21, 38),
            title: 'Break time is over',
            message: 'Ready to get back to work?',
          ),
        ];
        final items = ReminderEngine.mixTimeline(
          punchTimes: [at(21, 31), at(21, 31), at(20, 47)],
          primaryKinds: const [
            ReminderPunchKind.breakEnd,
            ReminderPunchKind.breakStart,
            ReminderPunchKind.checkIn,
          ],
          logs: logs,
        );
        expect(items.first.isPunch, isFalse);
        expect(
          items.first.standaloneLogs.single.type,
          ReminderType.breakTimeEnded,
        );
        expect(items[1].isPunch, isTrue);
        expect(items[1].attachedLogs, isEmpty);
      },
    );

    test(
      'earlier break-start punch does not hide a later take-break reminder',
      () {
        final logs = [
          ReminderLog(
            type: ReminderType.breakTime,
            firedAt: at(22, 28),
            title: 'Break coming up',
            message: 'Your break starts in 5 minutes.',
          ),
        ];
        final items = ReminderEngine.mixTimeline(
          punchTimes: [at(22, 28), at(22, 27), at(22, 25), at(10, 19)],
          primaryKinds: const [
            ReminderPunchKind.breakStart,
            ReminderPunchKind.breakEnd,
            ReminderPunchKind.breakStart,
            ReminderPunchKind.checkIn,
          ],
          logs: logs,
        );
        expect(items.every((item) => item.isPunch), isTrue);
        expect(items.first.attachedLogs.single.type, ReminderType.breakTime);
        expect(items[2].attachedLogs, isEmpty);
      },
    );

    test(
      'take-break reminder sits above cards until a later break starts',
      () {
        final logs = [
          ReminderLog(
            type: ReminderType.breakTime,
            firedAt: at(22, 28),
            title: 'Break coming up',
            message: 'Your break starts in 5 minutes.',
          ),
        ];
        final items = ReminderEngine.mixTimeline(
          punchTimes: [at(22, 27), at(22, 25), at(10, 19)],
          primaryKinds: const [
            ReminderPunchKind.breakEnd,
            ReminderPunchKind.breakStart,
            ReminderPunchKind.checkIn,
          ],
          logs: logs,
        );
        expect(items.first.isPunch, isFalse);
        expect(items.first.standaloneLogs.single.type, ReminderType.breakTime);
        expect(items[2].attachedLogs, isEmpty);
      },
    );

    test('checkout reminder appears while still checked in', () {
      final logs = [
        ReminderLog(
          type: ReminderType.checkOut,
          firedAt: at(16, 45),
          title: 'Time to check out',
          message: 'Wrapping up for today?',
        ),
      ];
      final items = ReminderEngine.mixTimeline(
        punchTimes: [at(16, 25)],
        primaryKinds: const [ReminderPunchKind.checkIn],
        logs: logs,
      );
      expect(items, hasLength(2));
      expect(items.first.isPunch, isFalse);
      expect(items.first.standaloneLogs.single.type, ReminderType.checkOut);
      expect(items.last.isPunch, isTrue);
      expect(items.last.attachedLogs, isEmpty);
    });

    test('checkout reminder attaches once a checkout punch exists', () {
      final logs = [
        ReminderLog(
          type: ReminderType.checkOut,
          firedAt: at(16, 45),
          title: 'Time to check out',
          message: 'Wrapping up for today?',
        ),
      ];
      final items = ReminderEngine.mixTimeline(
        punchTimes: [at(17), at(9)],
        primaryKinds: const [
          ReminderPunchKind.checkOut,
          ReminderPunchKind.checkIn,
        ],
        logs: logs,
      );
      expect(items, hasLength(2));
      expect(items.every((item) => item.isPunch), isTrue);
      expect(items.first.attachedLogs.single.type, ReminderType.checkOut);
      expect(items.last.attachedLogs, isEmpty);
    });

    test(
      'long attendance sits above cards until checkout, then attaches',
      () {
        final logs = [
          ReminderLog(
            type: ReminderType.veryLongAttendance,
            firedAt: at(9, 10),
            title: 'Still working?',
            message: "You've been checked in for 10 minutes.",
          ),
        ];
        final waiting = ReminderEngine.mixTimeline(
          punchTimes: [at(9)],
          primaryKinds: const [ReminderPunchKind.checkIn],
          logs: logs,
        );
        expect(waiting.first.isPunch, isFalse);
        expect(
          waiting.first.standaloneLogs.single.type,
          ReminderType.veryLongAttendance,
        );

        final done = ReminderEngine.mixTimeline(
          punchTimes: [at(9, 20), at(9)],
          primaryKinds: const [
            ReminderPunchKind.checkOut,
            ReminderPunchKind.checkIn,
          ],
          logs: logs,
        );
        expect(done.every((item) => item.isPunch), isTrue);
        expect(
          done.first.attachedLogs.single.type,
          ReminderType.veryLongAttendance,
        );
      },
    );

    test('reminders still show when there is no punch card', () {
      final logs = [
        ReminderLog(
          type: ReminderType.checkIn,
          firedAt: at(9),
          title: 'Time to check in',
          message: 'Ready to start your day?',
        ),
      ];
      final items = ReminderEngine.mixTimeline(
        punchTimes: const [],
        primaryKinds: const [],
        logs: logs,
      );
      expect(items.single.isPunch, isFalse);
      expect(items.single.standaloneLogs.single.type, ReminderType.checkIn);
    });

    test('fired checkout alert stays after punch list goes empty', () async {
      final dao = _MemoryReminderDao();
      await sync(
        dao: dao,
        now: at(18, 10),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9))],
      );
      final logs = await sync(dao: dao, now: at(18, 10));
      expect(of(logs, ReminderType.checkOut), isNotNull);
      expect(of(logs, ReminderType.checkOutMissed), isNotNull);
    });

    test('missing-card alerts group above the check-in card', () {
      final logs = [
        ReminderLog(
          type: ReminderType.veryLongAttendance,
          firedAt: at(23, 10),
          title: 'Still working?',
          message: "You've been checked in for 12 hours.",
        ),
        ReminderLog(
          type: ReminderType.checkOutMissed,
          firedAt: at(18, 10),
          title: 'Still checked in?',
          message: "Check out if you've finished work.",
        ),
        ReminderLog(
          type: ReminderType.checkOut,
          firedAt: at(18),
          title: 'Time to check out',
          message: 'Wrapping up for today?',
        ),
        ReminderLog(
          type: ReminderType.breakTime,
          firedAt: at(12, 50),
          title: 'Break coming up',
          message: 'Your break starts in 5 minutes.',
        ),
        ReminderLog(
          type: ReminderType.checkInMissed,
          firedAt: at(21, 20),
          title: 'Missed your check-in?',
          message: "Check in now if you've started work.",
        ),
        ReminderLog(
          type: ReminderType.checkIn,
          firedAt: at(21),
          title: 'Time to check in',
          message: 'Ready to start your day?',
        ),
      ];
      final items = ReminderEngine.mixTimeline(
        punchTimes: [at(8, 46)],
        primaryKinds: const [ReminderPunchKind.checkIn],
        logs: logs,
      );
      expect(items, hasLength(2));
      expect(items.first.isPunch, isFalse);
      expect(items.first.standaloneLogs.map((log) => log.type).toList(), [
        ReminderType.veryLongAttendance,
        ReminderType.checkOutMissed,
        ReminderType.checkOut,
        ReminderType.breakTime,
      ]);
      expect(items.last.isPunch, isTrue);
      expect(items.last.attachedLogs.map((log) => log.type).toList(), [
        ReminderType.checkInMissed,
        ReminderType.checkIn,
      ]);
    });
  });
}
