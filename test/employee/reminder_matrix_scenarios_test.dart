import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/more/data/local/reminder_dao.dart';
import 'package:obecno/features/more/data/models/reminder_log.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';
import 'package:obecno/features/more/services/reminder_engine.dart';
import 'package:obecno/features/more/services/reminder_notification_plan.dart';

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
  const policyIn = TimeOfDay(hour: 9, minute: 0);
  const policyOut = TimeOfDay(hour: 18, minute: 0);
  final day = DateTime(2026, 9, 9);

  DateTime at(int hour, [int minute = 0]) => DateTime(2026, 9, 9, hour, minute);

  Map<ReminderType, bool> allOn({Set<ReminderType> except = const {}}) => {
    for (final type in ReminderType.values) type: !except.contains(type),
  };

  Map<ReminderType, bool> only(ReminderType type) => {
    for (final value in ReminderType.values) value: value == type,
  };

  List<ScheduledReminderNotification> plan({
    required DateTime now,
    Map<ReminderType, bool>? enabled,
    List<ReminderPunch> punches = const [],
    TimeOfDay? checkInTime,
    TimeOfDay? checkOutTime,
    TimeOfDay? policyCheckInTime,
    TimeOfDay? policyCheckOutTime,
    TimeOfDay? breakReminderTime,
    TimeOfDay? breakEndedReminderTime,
    int graceMinutes = 5,
    int breakMinutes = 60,
    int longAttendanceHours = 12,
    Set<int> workingWeekdays = const {1, 2, 3, 4, 5},
    Set<ReminderType> alreadyFired = const {},
  }) {
    return ReminderNotificationPlan.build(
      now: now,
      enabled:
          enabled ??
          allOn(
            except: {ReminderType.enterLocation, ReminderType.leaveLocation},
          ),
      checkInTime: checkInTime ?? policyIn,
      checkOutTime: checkOutTime ?? policyOut,
      policyCheckInTime: policyCheckInTime ?? policyIn,
      policyCheckOutTime: policyCheckOutTime ?? policyOut,
      breakReminderTime: breakReminderTime,
      breakEndedReminderTime: breakEndedReminderTime,
      graceMinutes: graceMinutes,
      breakMinutes: breakMinutes,
      longAttendanceHours: longAttendanceHours,
      punches: punches,
      workingWeekdays: workingWeekdays,
      alreadyFired: alreadyFired,
    );
  }

  ScheduledReminderNotification? ofPlan(
    List<ScheduledReminderNotification> items,
    ReminderType type, {
    int? day,
  }) {
    for (final item in items) {
      if (item.type != type) continue;
      if (day != null && item.fireAt.day != day) continue;
      return item;
    }
    return null;
  }

  Future<List<ReminderLog>> sync({
    required DateTime now,
    List<ReminderPunch> punches = const [],
    Map<ReminderType, bool>? enabled,
    TimeOfDay? checkInTime,
    TimeOfDay? checkOutTime,
    TimeOfDay? breakReminderTime,
    TimeOfDay? breakEndedReminderTime,
    int graceMinutes = 5,
    int breakMinutes = 60,
    int longAttendanceHours = 12,
    String userId = 'emp-1',
    _MemoryReminderDao? dao,
  }) {
    return ReminderEngine.syncDay(
      dao: dao ?? _MemoryReminderDao(),
      userId: userId,
      day: day,
      now: now,
      enabled: enabled ?? allOn(),
      checkInTime: checkInTime ?? policyIn,
      checkOutTime: checkOutTime ?? policyOut,
      policyCheckInTime: policyIn,
      policyCheckOutTime: policyOut,
      breakReminderTime: breakReminderTime,
      breakEndedReminderTime: breakEndedReminderTime,
      graceMinutes: graceMinutes,
      breakMinutes: breakMinutes,
      longAttendanceHours: longAttendanceHours,
      punches: punches,
    );
  }

  ReminderLog? ofLog(List<ReminderLog> logs, ReminderType type) {
    for (final log in logs) {
      if (log.type == type) return log;
    }
    return null;
  }

  final checkedIn = [
    ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
  ];
  final onBreak = [
    ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
    ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(13)),
  ];
  final finishedBreak = [
    ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
    ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(11)),
    ReminderPunch(kind: ReminderPunchKind.breakEnd, time: at(11, 20)),
  ];
  final checkedOut = [
    ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
    ReminderPunch(kind: ReminderPunchKind.checkOut, time: at(17, 55)),
  ];

  group('Check In', () {
    test('disabled is not scheduled', () {
      final items = plan(
        now: at(8),
        enabled: allOn(except: {ReminderType.checkIn}),
      );
      expect(ofPlan(items, ReminderType.checkIn, day: 9), isNull);
    });

    test('before work schedules future notice', () {
      final items = plan(now: at(8), enabled: only(ReminderType.checkIn));
      expect(ofPlan(items, ReminderType.checkIn, day: 9)!.fireAt, at(9));
      expect(
        ofPlan(items, ReminderType.checkIn, day: 9)!.deliverImmediately,
        isFalse,
      );
    });

    test('on the minute delivers immediately', () {
      final items = plan(now: at(9), enabled: only(ReminderType.checkIn));
      expect(
        ofPlan(items, ReminderType.checkIn, day: 9)!.deliverImmediately,
        isTrue,
      );
    });

    test('after the minute does not catch up', () {
      final items = plan(now: at(9, 10), enabled: only(ReminderType.checkIn));
      expect(ofPlan(items, ReminderType.checkIn, day: 9), isNull);
    });

    test('punch before reminder cancels today', () {
      final items = plan(
        now: at(8, 50),
        enabled: only(ReminderType.checkIn),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(8, 40)),
        ],
      );
      expect(ofPlan(items, ReminderType.checkIn, day: 9), isNull);
    });

    test('on-time punch does not log', () async {
      final logs = await sync(
        now: at(10),
        enabled: only(ReminderType.checkIn),
        punches: checkedIn,
      );
      expect(ofLog(logs, ReminderType.checkIn), isNull);
    });

    test('late punch logs at reminder time', () async {
      final logs = await sync(
        now: at(9, 20),
        checkInTime: const TimeOfDay(hour: 8, minute: 0),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9))],
      );
      expect(ofLog(logs, ReminderType.checkIn)!.firedAt, at(8));
    });

    test('no punch by late morning logs catch-up on timeline', () async {
      final logs = await sync(now: at(10), enabled: only(ReminderType.checkIn));
      expect(ofLog(logs, ReminderType.checkIn)!.firedAt, at(9));
    });

    test('custom later time schedules that clock', () {
      final items = plan(
        now: at(9, 30),
        checkInTime: const TimeOfDay(hour: 10, minute: 0),
        enabled: only(ReminderType.checkIn),
      );
      expect(ofPlan(items, ReminderType.checkIn, day: 9)!.fireAt, at(10));
    });

    test('rest day is skipped', () {
      final items = plan(now: DateTime(2026, 9, 12, 8));
      expect(items.where((e) => e.fireAt.day == 12), isEmpty);
    });

    test('already fired is not delivered again', () {
      final items = plan(
        now: at(9),
        enabled: only(ReminderType.checkIn),
        alreadyFired: {ReminderType.checkIn},
      );
      expect(ofPlan(items, ReminderType.checkIn, day: 9), isNull);
    });

    test('empty user writes nothing', () async {
      final logs = await sync(now: at(10), userId: '');
      expect(logs, isEmpty);
    });
  });

  group('Check In Missed', () {
    test('disabled is not scheduled', () {
      final items = plan(
        now: at(8),
        enabled: allOn(except: {ReminderType.checkInMissed}),
      );
      expect(ofPlan(items, ReminderType.checkInMissed, day: 9), isNull);
    });

    test('before work schedules at reminder plus grace', () {
      final items = plan(now: at(8), enabled: only(ReminderType.checkInMissed));
      expect(
        ofPlan(items, ReminderType.checkInMissed, day: 9)!.fireAt,
        at(9, 5),
      );
      expect(
        ofPlan(items, ReminderType.checkInMissed, day: 9)!.deliverImmediately,
        isFalse,
      );
    });

    test('on the grace minute delivers immediately', () {
      final items = plan(
        now: at(9, 5),
        enabled: only(ReminderType.checkInMissed),
      );
      expect(
        ofPlan(items, ReminderType.checkInMissed, day: 9)!.deliverImmediately,
        isTrue,
      );
    });

    test('after grace does not catch up', () {
      final items = plan(
        now: at(9, 20),
        enabled: only(ReminderType.checkInMissed),
      );
      expect(ofPlan(items, ReminderType.checkInMissed, day: 9), isNull);
    });

    test('punch during grace cancels missed', () {
      final items = plan(
        now: at(9, 3),
        enabled: only(ReminderType.checkInMissed),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9, 3)),
        ],
      );
      expect(ofPlan(items, ReminderType.checkInMissed, day: 9), isNull);
    });

    test('late punch after grace still logs missed', () async {
      final logs = await sync(
        now: at(9, 20),
        checkInTime: const TimeOfDay(hour: 8, minute: 0),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9, 10)),
        ],
      );
      expect(ofLog(logs, ReminderType.checkInMissed)!.firedAt, at(8, 5));
    });

    test('zero grace fires missed at the chosen clock', () {
      final items = plan(
        now: at(8),
        graceMinutes: 0,
        enabled: only(ReminderType.checkInMissed),
      );
      expect(ofPlan(items, ReminderType.checkInMissed, day: 9)!.fireAt, at(9));
    });
  });

  group('Check Out', () {
    test('disabled is not scheduled', () {
      final items = plan(
        now: at(10),
        punches: checkedIn,
        enabled: allOn(except: {ReminderType.checkOut}),
      );
      expect(ofPlan(items, ReminderType.checkOut), isNull);
    });

    test('not checked in is not scheduled', () {
      final items = plan(now: at(17), enabled: only(ReminderType.checkOut));
      expect(ofPlan(items, ReminderType.checkOut), isNull);
    });

    test('after check-in schedules future checkout', () {
      final items = plan(
        now: at(10),
        enabled: only(ReminderType.checkOut),
        punches: checkedIn,
      );
      expect(ofPlan(items, ReminderType.checkOut)!.fireAt, at(18));
      expect(ofPlan(items, ReminderType.checkOut)!.deliverImmediately, isFalse);
    });

    test('on the minute delivers immediately', () {
      final items = plan(
        now: at(18),
        enabled: only(ReminderType.checkOut),
        punches: checkedIn,
      );
      expect(ofPlan(items, ReminderType.checkOut)!.deliverImmediately, isTrue);
    });

    test('after the minute does not catch up', () {
      final items = plan(
        now: at(18, 10),
        enabled: only(ReminderType.checkOut),
        punches: checkedIn,
      );
      expect(ofPlan(items, ReminderType.checkOut), isNull);
    });

    test('on-time checkout cancels notice', () {
      final items = plan(
        now: at(18, 10),
        enabled: only(ReminderType.checkOut),
        punches: checkedOut,
      );
      expect(ofPlan(items, ReminderType.checkOut), isNull);
    });

    test('still checked in after time logs on timeline', () async {
      final logs = await sync(
        now: at(18, 20),
        enabled: only(ReminderType.checkOut),
        punches: checkedIn,
      );
      expect(ofLog(logs, ReminderType.checkOut)!.firedAt, at(18));
    });

    test('custom earlier checkout uses that clock', () {
      final items = plan(
        now: at(16),
        checkOutTime: const TimeOfDay(hour: 17, minute: 0),
        enabled: only(ReminderType.checkOut),
        punches: checkedIn,
      );
      expect(ofPlan(items, ReminderType.checkOut)!.fireAt, at(17));
    });

    test('timeline stays above cards until checkout punch', () {
      final items = ReminderEngine.mixTimeline(
        punchTimes: [at(9)],
        primaryKinds: const [ReminderPunchKind.checkIn],
        logs: [
          ReminderLog(
            type: ReminderType.checkOut,
            firedAt: at(18),
            title: 'Time to check out',
            message: 'Wrapping up for today?',
          ),
        ],
      );
      expect(items.first.isPunch, isFalse);
      expect(items.first.standaloneLogs.single.type, ReminderType.checkOut);
    });
  });

  group('Check Out Missed', () {
    test('disabled is not scheduled', () {
      final items = plan(
        now: at(10),
        punches: checkedIn,
        enabled: allOn(except: {ReminderType.checkOutMissed}),
      );
      expect(ofPlan(items, ReminderType.checkOutMissed), isNull);
    });

    test('schedules at checkout plus grace', () {
      final items = plan(
        now: at(10),
        enabled: only(ReminderType.checkOutMissed),
        punches: checkedIn,
      );
      expect(ofPlan(items, ReminderType.checkOutMissed)!.fireAt, at(18, 5));
    });

    test('on the grace minute delivers immediately', () {
      final items = plan(
        now: at(18, 5),
        enabled: only(ReminderType.checkOutMissed),
        punches: checkedIn,
      );
      expect(
        ofPlan(items, ReminderType.checkOutMissed)!.deliverImmediately,
        isTrue,
      );
    });

    test('after grace does not catch up', () {
      final items = plan(
        now: at(18, 20),
        enabled: only(ReminderType.checkOutMissed),
        punches: checkedIn,
      );
      expect(ofPlan(items, ReminderType.checkOutMissed), isNull);
    });

    test('checkout cancels missed', () {
      final items = plan(
        now: at(18, 10),
        enabled: only(ReminderType.checkOutMissed),
        punches: checkedOut,
      );
      expect(ofPlan(items, ReminderType.checkOutMissed), isNull);
    });

    test('still checked in after grace logs missed', () async {
      final logs = await sync(
        now: at(18, 20),
        enabled: only(ReminderType.checkOutMissed),
        punches: checkedIn,
      );
      expect(ofLog(logs, ReminderType.checkOutMissed)!.firedAt, at(18, 5));
    });
  });

  group('Break time', () {
    test('disabled is not scheduled', () {
      final items = plan(
        now: at(10),
        punches: checkedIn,
        enabled: allOn(except: {ReminderType.breakTime}),
      );
      expect(ofPlan(items, ReminderType.breakTime), isNull);
    });

    test('not checked in is not scheduled', () {
      final items = plan(now: at(10), enabled: only(ReminderType.breakTime));
      expect(ofPlan(items, ReminderType.breakTime), isNull);
    });

    test('after check-in schedules chosen break clock', () {
      final items = plan(
        now: at(10),
        enabled: only(ReminderType.breakTime),
        punches: checkedIn,
      );
      expect(ofPlan(items, ReminderType.breakTime)!.fireAt, at(13, 25));
      expect(
        ofPlan(items, ReminderType.breakTime)!.deliverImmediately,
        isFalse,
      );
    });

    test('on the minute delivers immediately', () {
      final items = plan(
        now: at(13, 25),
        enabled: only(ReminderType.breakTime),
        punches: checkedIn,
      );
      expect(ofPlan(items, ReminderType.breakTime)!.deliverImmediately, isTrue);
    });

    test('after the minute does not catch up', () {
      final items = plan(
        now: at(13, 40),
        enabled: only(ReminderType.breakTime),
        punches: checkedIn,
      );
      expect(ofPlan(items, ReminderType.breakTime), isNull);
    });

    test('starting break before reminder cancels notice', () {
      final items = plan(
        now: at(13, 25),
        enabled: only(ReminderType.breakTime),
        punches: onBreak,
      );
      expect(ofPlan(items, ReminderType.breakTime), isNull);
    });

    test('finished earlier break still schedules later take-break', () {
      final items = plan(
        now: at(12, 20),
        breakReminderTime: const TimeOfDay(hour: 12, minute: 30),
        enabled: only(ReminderType.breakTime),
        punches: finishedBreak,
      );
      expect(ofPlan(items, ReminderType.breakTime)!.fireAt, at(12, 30));
    });

    test('finished earlier break still logs later take-break', () async {
      final logs = await sync(
        now: at(22, 28),
        breakReminderTime: const TimeOfDay(hour: 22, minute: 28),
        enabled: only(ReminderType.breakTime),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(10, 19)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(22, 25)),
          ReminderPunch(kind: ReminderPunchKind.breakEnd, time: at(22, 27)),
        ],
      );
      expect(ofLog(logs, ReminderType.breakTime)!.firedAt, at(22, 28));
    });

    test('starting break at reminder time still logs', () async {
      final logs = await sync(
        now: at(22, 30),
        breakReminderTime: const TimeOfDay(hour: 22, minute: 28),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(10, 19)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(22, 25)),
          ReminderPunch(kind: ReminderPunchKind.breakEnd, time: at(22, 27)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(22, 28)),
        ],
      );
      expect(ofLog(logs, ReminderType.breakTime)!.firedAt, at(22, 28));
    });

    test('checkout cancels take-break', () {
      final items = plan(
        now: at(18, 10),
        enabled: only(ReminderType.breakTime),
        punches: checkedOut,
      );
      expect(ofPlan(items, ReminderType.breakTime), isNull);
    });

    test('earlier break start does not hide later take-break on timeline', () {
      final items = ReminderEngine.mixTimeline(
        punchTimes: [at(22, 28), at(22, 27), at(22, 25), at(10, 19)],
        primaryKinds: const [
          ReminderPunchKind.breakStart,
          ReminderPunchKind.breakEnd,
          ReminderPunchKind.breakStart,
          ReminderPunchKind.checkIn,
        ],
        logs: [
          ReminderLog(
            type: ReminderType.breakTime,
            firedAt: at(22, 28),
            title: 'Break coming up',
            message: 'Your break starts in 5 minutes.',
          ),
        ],
      );
      expect(items.first.attachedLogs.single.type, ReminderType.breakTime);
      expect(items[2].attachedLogs, isEmpty);
    });
  });

  group('Break time ended', () {
    test('disabled is not scheduled', () {
      final items = plan(
        now: at(13, 5),
        punches: onBreak,
        enabled: allOn(except: {ReminderType.breakTimeEnded}),
      );
      expect(ofPlan(items, ReminderType.breakTimeEnded), isNull);
    });

    test('not on break is not scheduled', () {
      final items = plan(
        now: at(13, 5),
        enabled: only(ReminderType.breakTimeEnded),
        punches: checkedIn,
      );
      expect(ofPlan(items, ReminderType.breakTimeEnded), isNull);
    });

    test('on break schedules chosen end clock', () {
      final items = plan(
        now: at(13, 5),
        enabled: only(ReminderType.breakTimeEnded),
        punches: onBreak,
      );
      expect(ofPlan(items, ReminderType.breakTimeEnded)!.fireAt, at(14, 30));
      expect(
        ofPlan(items, ReminderType.breakTimeEnded)!.deliverImmediately,
        isFalse,
      );
    });

    test('on the minute delivers immediately', () {
      final items = plan(
        now: at(14, 30),
        enabled: only(ReminderType.breakTimeEnded),
        punches: onBreak,
      );
      expect(
        ofPlan(items, ReminderType.breakTimeEnded)!.deliverImmediately,
        isTrue,
      );
    });

    test('ending break on time cancels notice', () {
      final items = plan(
        now: at(14, 10),
        enabled: only(ReminderType.breakTimeEnded),
        punches: [
          ...onBreak,
          ReminderPunch(kind: ReminderPunchKind.breakEnd, time: at(13, 40)),
        ],
      );
      expect(ofPlan(items, ReminderType.breakTimeEnded), isNull);
    });

    test('staying on break logs at the settings clock', () async {
      final logs = await sync(
        now: at(14, 35),
        enabled: only(ReminderType.breakTimeEnded),
        punches: onBreak,
      );
      expect(ofLog(logs, ReminderType.breakTimeEnded)!.firedAt, at(14, 30));
    });

    test('custom earlier end uses that clock', () {
      final items = plan(
        now: at(13, 5),
        breakEndedReminderTime: const TimeOfDay(hour: 13, minute: 30),
        enabled: only(ReminderType.breakTimeEnded),
        punches: onBreak,
      );
      expect(ofPlan(items, ReminderType.breakTimeEnded)!.fireAt, at(13, 30));
    });

    test('second break reminds from the open break', () {
      final items = plan(
        now: at(15, 5),
        enabled: only(ReminderType.breakTimeEnded),
        punches: [
          ...finishedBreak,
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(15)),
        ],
      );
      expect(ofPlan(items, ReminderType.breakTimeEnded)!.fireAt, at(16));
    });

    test('earlier break-end punch does not hide later reminder', () {
      final items = ReminderEngine.mixTimeline(
        punchTimes: [at(21, 31), at(21, 31), at(20, 47)],
        primaryKinds: const [
          ReminderPunchKind.breakEnd,
          ReminderPunchKind.breakStart,
          ReminderPunchKind.checkIn,
        ],
        logs: [
          ReminderLog(
            type: ReminderType.breakTimeEnded,
            firedAt: at(21, 38),
            title: 'Break time is over',
            message: 'Ready to get back to work?',
          ),
        ],
      );
      expect(items.first.isPunch, isFalse);
      expect(
        items.first.standaloneLogs.single.type,
        ReminderType.breakTimeEnded,
      );
    });
  });

  group('Longer break', () {
    test('disabled is not scheduled', () {
      final items = plan(
        now: at(13, 5),
        punches: onBreak,
        enabled: allOn(except: {ReminderType.longerBreak}),
      );
      expect(ofPlan(items, ReminderType.longerBreak), isNull);
    });

    test('not on break is not scheduled', () {
      final items = plan(
        now: at(13, 5),
        enabled: only(ReminderType.longerBreak),
        punches: checkedIn,
      );
      expect(ofPlan(items, ReminderType.longerBreak), isNull);
    });

    test('on break schedules one hour after break-end', () {
      final items = plan(
        now: at(13, 5),
        enabled: only(ReminderType.longerBreak),
        punches: onBreak,
      );
      expect(ofPlan(items, ReminderType.longerBreak)!.fireAt, at(15, 30));
    });

    test('ending break on time skips longer-break log', () async {
      final logs = await sync(
        now: at(14, 10),
        enabled: only(ReminderType.longerBreak),
        punches: [
          ...onBreak,
          ReminderPunch(kind: ReminderPunchKind.breakEnd, time: at(13, 40)),
        ],
      );
      expect(ofLog(logs, ReminderType.longerBreak), isNull);
    });

    test('staying an hour past end logs longer-break', () async {
      final logs = await sync(
        now: at(15, 35),
        enabled: only(ReminderType.longerBreak),
        punches: onBreak,
      );
      expect(ofLog(logs, ReminderType.longerBreak)!.firedAt, at(15, 30));
    });
  });

  group('Very long attendance', () {
    test('disabled is not scheduled', () {
      final items = plan(
        now: at(10),
        punches: checkedIn,
        enabled: allOn(except: {ReminderType.veryLongAttendance}),
      );
      expect(ofPlan(items, ReminderType.veryLongAttendance), isNull);
    });

    test('not checked in is not scheduled', () {
      final items = plan(
        now: at(10),
        enabled: only(ReminderType.veryLongAttendance),
      );
      expect(ofPlan(items, ReminderType.veryLongAttendance), isNull);
    });

    test('after check-in waits the chosen duration', () {
      final items = plan(
        now: at(10),
        enabled: only(ReminderType.veryLongAttendance),
        punches: checkedIn,
      );
      expect(ofPlan(items, ReminderType.veryLongAttendance)!.fireAt, at(21));
      expect(
        ofPlan(items, ReminderType.veryLongAttendance)!.deliverImmediately,
        isFalse,
      );
    });

    test('on the duration minute delivers immediately', () {
      final items = plan(
        now: at(21),
        enabled: only(ReminderType.veryLongAttendance),
        punches: checkedIn,
      );
      expect(
        ofPlan(items, ReminderType.veryLongAttendance)!.deliverImmediately,
        isTrue,
      );
    });

    test('after duration still catch-up notifies while checked in', () {
      final items = plan(
        now: at(21, 20),
        enabled: only(ReminderType.veryLongAttendance),
        punches: checkedIn,
      );
      expect(
        ofPlan(items, ReminderType.veryLongAttendance)!.deliverImmediately,
        isTrue,
      );
    });

    test('checkout before duration skips notice', () {
      final items = plan(
        now: at(18, 10),
        enabled: only(ReminderType.veryLongAttendance),
        punches: checkedOut,
      );
      expect(ofPlan(items, ReminderType.veryLongAttendance), isNull);
    });

    test('still logs after later checkout if they stayed through it', () async {
      final logs = await sync(
        now: at(9, 20),
        longAttendanceHours: 10,
        enabled: only(ReminderType.veryLongAttendance),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ReminderPunch(kind: ReminderPunchKind.checkOut, time: at(9, 15)),
        ],
      );
      expect(ofLog(logs, ReminderType.veryLongAttendance)!.firedAt, at(9, 10));
    });

    test('does not log when checkout is before the duration', () async {
      final logs = await sync(
        now: at(9, 20),
        longAttendanceHours: 10,
        enabled: only(ReminderType.veryLongAttendance),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ReminderPunch(kind: ReminderPunchKind.checkOut, time: at(9, 5)),
        ],
      );
      expect(ofLog(logs, ReminderType.veryLongAttendance), isNull);
    });

    test('still logs while on break', () async {
      final logs = await sync(
        now: at(9, 12),
        longAttendanceHours: 10,
        enabled: only(ReminderType.veryLongAttendance),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: at(9, 5)),
        ],
      );
      expect(ofLog(logs, ReminderType.veryLongAttendance)!.firedAt, at(9, 10));
    });

    test(
      'every picker from 10 minutes to 12 hours notifies and logs',
      () async {
        final durations = ReminderCopy.durationOptionsInMinutes
            .where((minutes) => minutes <= 12 * 60)
            .toList();
        expect(durations, containsAll([10, 20, 30, 40, 50, 60, 12 * 60]));
        final checkInAt = at(9);
        final punches = [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: checkInAt),
        ];
        for (final minutes in durations) {
          final fireAt = checkInAt.add(Duration(minutes: minutes));
          final before = plan(
            now: fireAt.subtract(const Duration(minutes: 1)),
            longAttendanceHours: minutes,
            enabled: only(ReminderType.veryLongAttendance),
            punches: punches,
          );
          expect(
            ofPlan(before, ReminderType.veryLongAttendance)!.deliverImmediately,
            isFalse,
            reason: '$minutes minutes fired early',
          );
          final onTime = plan(
            now: fireAt,
            longAttendanceHours: minutes,
            enabled: only(ReminderType.veryLongAttendance),
            punches: punches,
          );
          expect(
            ofPlan(onTime, ReminderType.veryLongAttendance)!.deliverImmediately,
            isTrue,
            reason: '$minutes minutes missed its minute',
          );
          final logs = await sync(
            now: fireAt.add(const Duration(minutes: 3)),
            longAttendanceHours: minutes,
            enabled: only(ReminderType.veryLongAttendance),
            punches: punches,
          );
          expect(
            ofLog(logs, ReminderType.veryLongAttendance)!.firedAt,
            fireAt,
            reason: '$minutes minutes skipped on timeline',
          );
        }
      },
    );

    test('sits above cards until a checkout punch exists', () {
      final logs = [
        ReminderLog(
          type: ReminderType.veryLongAttendance,
          firedAt: at(21),
          title: 'Still working?',
          message: "You've been checked in for 12 hours.",
        ),
      ];
      final waiting = ReminderEngine.mixTimeline(
        punchTimes: [at(9)],
        primaryKinds: const [ReminderPunchKind.checkIn],
        logs: logs,
      );
      expect(
        waiting.first.standaloneLogs.single.type,
        ReminderType.veryLongAttendance,
      );
      final done = ReminderEngine.mixTimeline(
        punchTimes: [at(21, 10), at(9)],
        primaryKinds: const [
          ReminderPunchKind.checkOut,
          ReminderPunchKind.checkIn,
        ],
        logs: logs,
      );
      expect(
        done.first.attachedLogs.single.type,
        ReminderType.veryLongAttendance,
      );
    });
  });

  group('Enter / leave location', () {
    test('OS plan never schedules enter or leave', () {
      final items = plan(now: at(10), punches: checkedIn, enabled: allOn());
      expect(ofPlan(items, ReminderType.enterLocation), isNull);
      expect(ofPlan(items, ReminderType.leaveLocation), isNull);
    });

    test('check-in logs enter location on timeline', () async {
      final logs = await sync(
        now: at(10),
        enabled: only(ReminderType.enterLocation),
        punches: checkedIn,
      );
      expect(ofLog(logs, ReminderType.enterLocation)!.firedAt, at(9));
    });

    test('checkout logs leave location on timeline', () async {
      final logs = await sync(
        now: at(18, 10),
        enabled: only(ReminderType.leaveLocation),
        punches: checkedOut,
      );
      expect(ofLog(logs, ReminderType.leaveLocation)!.firedAt, at(17, 55));
    });
  });

  group('Cross-cutting', () {
    test('overnight 9 PM to 6 AM places checkout next morning', () {
      const nightIn = TimeOfDay(hour: 21, minute: 0);
      const morningOut = TimeOfDay(hour: 6, minute: 0);
      final items = plan(
        now: at(21),
        checkInTime: nightIn,
        checkOutTime: morningOut,
        policyCheckInTime: nightIn,
        policyCheckOutTime: morningOut,
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: at(21))],
      );
      expect(
        ofPlan(items, ReminderType.checkOut)!.fireAt,
        DateTime(2026, 9, 10, 6),
      );
      expect(
        ofPlan(items, ReminderType.checkOutMissed)!.fireAt,
        DateTime(2026, 9, 10, 6, 5),
      );
    });

    test('the same reminder is not logged twice', () async {
      final dao = _MemoryReminderDao();
      await sync(dao: dao, now: at(10));
      final second = await sync(dao: dao, now: at(11));
      expect(
        second.where((log) => log.type == ReminderType.checkIn),
        hasLength(1),
      );
    });

    test('copy exists for every reminder type', () {
      for (final type in ReminderType.values) {
        expect(ReminderCopy.title(type, locationName: 'Office'), isNotEmpty);
        expect(ReminderCopy.message(type), isNotEmpty);
        expect(ReminderType.fromStorageKey(type.storageKey), type);
      }
    });

    test('quiet day lists missed notices above the check-in card', () {
      final items = ReminderEngine.mixTimeline(
        punchTimes: [at(8, 46)],
        primaryKinds: const [ReminderPunchKind.checkIn],
        logs: [
          ReminderLog(
            type: ReminderType.veryLongAttendance,
            firedAt: at(20, 46),
            title: 'Still working?',
            message: "You've been checked in for 12 hours.",
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
        ],
      );
      expect(items.first.isPunch, isFalse);
      expect(items.first.standaloneLogs.map((log) => log.type).toList(), [
        ReminderType.veryLongAttendance,
        ReminderType.checkOut,
        ReminderType.breakTime,
      ]);
    });
  });
}
