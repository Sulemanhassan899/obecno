import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/more/data/models/reminder_log.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';
import 'package:obecno/features/more/services/reminder_notification_plan.dart';

void main() {
  const checkIn = TimeOfDay(hour: 9, minute: 0);
  const checkOut = TimeOfDay(hour: 18, minute: 0);
  DateTime wed(int hour, [int minute = 0]) =>
      DateTime(2026, 9, 9, hour, minute);

  final beforeWork = wed(8);
  final afterPunchIn = wed(10);
  final onBreak = wed(13, 5);
  final pastGrace = wed(9, 30);

  final punchedIn = [
    ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
  ];
  final punchedAndBreak = [
    ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
    ReminderPunch(kind: ReminderPunchKind.breakStart, time: wed(13)),
  ];

  Map<ReminderType, bool> only(ReminderType type) => {
    for (final value in ReminderType.values) value: value == type,
  };

  Map<ReminderType, bool> allOn({Set<ReminderType> except = const {}}) => {
    for (final value in ReminderType.values)
      value:
          !except.contains(value) &&
          value != ReminderType.enterLocation &&
          value != ReminderType.leaveLocation,
  };

  Map<ReminderType, bool> combine(Set<ReminderType> types) => {
    for (final value in ReminderType.values) value: types.contains(value),
  };

  List<ScheduledReminderNotification> plan({
    required DateTime now,
    required Map<ReminderType, bool> enabled,
    List<ReminderPunch> punches = const [],
  }) {
    return ReminderNotificationPlan.build(
      now: now,
      enabled: enabled,
      checkInTime: checkIn,
      checkOutTime: checkOut,
      graceMinutes: 5,
      breakMinutes: 60,
      longAttendanceHours: 12,
      punches: punches,
      workingWeekdays: const {1, 2, 3, 4, 5},
    );
  }

  Set<ReminderType> today(List<ScheduledReminderNotification> items) => items
      .where((item) => item.fireAt.day == 9)
      .map((item) => item.type)
      .toSet();

  group('one by one — only that setting on', () {
    test('Check In on, before work → check-in only, notification on', () {
      final items = plan(now: beforeWork, enabled: only(ReminderType.checkIn));
      expect(today(items), {ReminderType.checkIn});
    });

    test('Check In Missed on, before work → missed only', () {
      final items = plan(
        now: beforeWork,
        enabled: only(ReminderType.checkInMissed),
      );
      expect(today(items), {ReminderType.checkInMissed});
    });

    test('Check Out on, after punch-in → check-out only', () {
      final items = plan(
        now: afterPunchIn,
        enabled: only(ReminderType.checkOut),
        punches: punchedIn,
      );
      expect(today(items), {ReminderType.checkOut});
    });

    test('Check Out Missed on, after punch-in → check-out missed only', () {
      final items = plan(
        now: afterPunchIn,
        enabled: only(ReminderType.checkOutMissed),
        punches: punchedIn,
      );
      expect(today(items), {ReminderType.checkOutMissed});
    });

    test('Break time on, after punch-in → break only', () {
      final items = plan(
        now: afterPunchIn,
        enabled: only(ReminderType.breakTime),
        punches: punchedIn,
      );
      expect(today(items), {ReminderType.breakTime});
    });

    test('Break time ended on, on break → break-ended only', () {
      final items = plan(
        now: onBreak,
        enabled: only(ReminderType.breakTimeEnded),
        punches: punchedAndBreak,
      );
      expect(today(items), {ReminderType.breakTimeEnded});
    });

    test('Longer break on, on break → longer-break only', () {
      final items = plan(
        now: onBreak,
        enabled: only(ReminderType.longerBreak),
        punches: punchedAndBreak,
      );
      expect(today(items), {ReminderType.longerBreak});
    });

    test('Very long attendance on, after punch-in → long-attendance only', () {
      final items = plan(
        now: afterPunchIn,
        enabled: only(ReminderType.veryLongAttendance),
        punches: punchedIn,
      );
      expect(today(items), {ReminderType.veryLongAttendance});
    });
  });

  group('one by one — that setting off, others on', () {
    test('Check In off → missed still scheduled', () {
      final items = plan(
        now: beforeWork,
        enabled: allOn(except: {ReminderType.checkIn}),
      );
      expect(today(items), isNot(contains(ReminderType.checkIn)));
      expect(today(items), contains(ReminderType.checkInMissed));
    });

    test('Check In Missed off → check-in still scheduled', () {
      final items = plan(
        now: beforeWork,
        enabled: allOn(except: {ReminderType.checkInMissed}),
      );
      expect(today(items), isNot(contains(ReminderType.checkInMissed)));
      expect(today(items), contains(ReminderType.checkIn));
    });

    test('Check Out off → check-out missed still scheduled', () {
      final items = plan(
        now: afterPunchIn,
        enabled: allOn(except: {ReminderType.checkOut}),
        punches: punchedIn,
      );
      expect(today(items), isNot(contains(ReminderType.checkOut)));
      expect(today(items), contains(ReminderType.checkOutMissed));
    });

    test('Check Out Missed off → check-out still scheduled', () {
      final items = plan(
        now: afterPunchIn,
        enabled: allOn(except: {ReminderType.checkOutMissed}),
        punches: punchedIn,
      );
      expect(today(items), isNot(contains(ReminderType.checkOutMissed)));
      expect(today(items), contains(ReminderType.checkOut));
    });

    test('Break time off → check-out notices still scheduled', () {
      final items = plan(
        now: afterPunchIn,
        enabled: allOn(except: {ReminderType.breakTime}),
        punches: punchedIn,
      );
      expect(today(items), isNot(contains(ReminderType.breakTime)));
      expect(today(items), contains(ReminderType.checkOut));
      expect(today(items), contains(ReminderType.checkOutMissed));
    });

    test('Break time ended off → longer-break still scheduled', () {
      final items = plan(
        now: onBreak,
        enabled: allOn(except: {ReminderType.breakTimeEnded}),
        punches: punchedAndBreak,
      );
      expect(today(items), isNot(contains(ReminderType.breakTimeEnded)));
      expect(today(items), contains(ReminderType.longerBreak));
    });

    test('Longer break off → break-ended still scheduled', () {
      final items = plan(
        now: onBreak,
        enabled: allOn(except: {ReminderType.longerBreak}),
        punches: punchedAndBreak,
      );
      expect(today(items), isNot(contains(ReminderType.longerBreak)));
      expect(today(items), contains(ReminderType.breakTimeEnded));
    });

    test('Very long attendance off → check-out notices still scheduled', () {
      final items = plan(
        now: afterPunchIn,
        enabled: allOn(except: {ReminderType.veryLongAttendance}),
        punches: punchedIn,
      );
      expect(today(items), isNot(contains(ReminderType.veryLongAttendance)));
      expect(today(items), contains(ReminderType.checkOut));
      expect(today(items), contains(ReminderType.checkOutMissed));
    });
  });

  group('combined toggles', () {
    test('all off → nothing scheduled', () {
      final items = plan(
        now: beforeWork,
        enabled: {for (final type in ReminderType.values) type: false},
      );
      expect(today(items), isEmpty);
    });

    test('Check In on + Check In Missed off, before work → check-in only', () {
      final items = plan(
        now: beforeWork,
        enabled: combine({ReminderType.checkIn}),
      );
      expect(today(items), {ReminderType.checkIn});
    });

    test('Check In + Missed on, before work → both scheduled', () {
      final items = plan(
        now: beforeWork,
        enabled: combine({ReminderType.checkIn, ReminderType.checkInMissed}),
      );
      expect(today(items), {ReminderType.checkIn, ReminderType.checkInMissed});
    });

    test('Check Out + Missed on, after punch-in → both scheduled', () {
      final items = plan(
        now: afterPunchIn,
        enabled: combine({ReminderType.checkOut, ReminderType.checkOutMissed}),
        punches: punchedIn,
      );
      expect(today(items), {
        ReminderType.checkOut,
        ReminderType.checkOutMissed,
      });
    });

    test('all break settings on → take-break after punch-in', () {
      final items = plan(
        now: afterPunchIn,
        enabled: combine({
          ReminderType.breakTime,
          ReminderType.breakTimeEnded,
          ReminderType.longerBreak,
        }),
        punches: punchedIn,
      );
      expect(today(items), {ReminderType.breakTime});
    });

    test('all break settings on → ended + longer-break while on break', () {
      final items = plan(
        now: onBreak,
        enabled: combine({
          ReminderType.breakTime,
          ReminderType.breakTimeEnded,
          ReminderType.longerBreak,
        }),
        punches: punchedAndBreak,
      );
      expect(today(items), {
        ReminderType.breakTimeEnded,
        ReminderType.longerBreak,
      });
    });

    test(
      'Check In off, Check Out on → only check-out notices after punch-in',
      () {
        final items = plan(
          now: afterPunchIn,
          enabled: combine({
            ReminderType.checkOut,
            ReminderType.checkOutMissed,
          }),
          punches: punchedIn,
        );
        expect(today(items).contains(ReminderType.checkIn), isFalse);
        expect(today(items), {
          ReminderType.checkOut,
          ReminderType.checkOutMissed,
        });
      },
    );

    test(
      'Check In, Check Out, Break, Break-end on after punch-in → check-out + break',
      () {
        final items = plan(
          now: afterPunchIn,
          enabled: combine({
            ReminderType.checkIn,
            ReminderType.checkOut,
            ReminderType.breakTime,
            ReminderType.breakTimeEnded,
          }),
          punches: punchedIn,
        );
        expect(today(items).contains(ReminderType.checkIn), isFalse);
        expect(today(items), {ReminderType.checkOut, ReminderType.breakTime});
      },
    );

    test('turn Check In off, then on again → restored', () {
      final off = plan(
        now: beforeWork,
        enabled: allOn(except: {ReminderType.checkIn}),
      );
      expect(today(off), isNot(contains(ReminderType.checkIn)));

      final on = plan(now: beforeWork, enabled: allOn());
      expect(today(on), contains(ReminderType.checkIn));
    });

    test('Missed on, Check In off, at missed minute → missed still fires', () {
      final items = plan(
        now: wed(9, 5),
        enabled: combine({ReminderType.checkInMissed}),
      );
      expect(today(items), {ReminderType.checkInMissed});
      expect(
        items
            .firstWhere((item) => item.type == ReminderType.checkInMissed)
            .deliverImmediately,
        isTrue,
      );
    });

    test(
      'Check In on, Missed off, at check-in minute → check-in fires, missed does not',
      () {
        final items = plan(
          now: wed(9),
          enabled: combine({ReminderType.checkIn}),
        );
        expect(today(items), {ReminderType.checkIn});
        expect(
          items
              .firstWhere((item) => item.type == ReminderType.checkIn)
              .deliverImmediately,
          isTrue,
        );
      },
    );
  });
}
