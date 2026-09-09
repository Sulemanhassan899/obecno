import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/more/data/models/reminder_log.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';
import 'package:obecno/features/more/providers/reminder_settings_provider.dart';
import 'package:obecno/features/more/presentation/widgets/reminder_time_picker_sheet.dart';
import 'package:obecno/features/more/services/reminder_notification_plan.dart';

void main() {
  const checkIn = TimeOfDay(hour: 9, minute: 0);
  const checkOut = TimeOfDay(hour: 18, minute: 0);

  // Wednesday 9 Sep 2026.
  DateTime wed(int hour, [int minute = 0]) =>
      DateTime(2026, 9, 9, hour, minute);

  Map<ReminderType, bool> allOn({Set<ReminderType> except = const {}}) {
    return {
      for (final type in ReminderType.values)
        type:
            !except.contains(type) &&
            type != ReminderType.enterLocation &&
            type != ReminderType.leaveLocation,
    };
  }

  List<ScheduledReminderNotification> plan({
    required DateTime now,
    Map<ReminderType, bool>? enabled,
    List<ReminderPunch> punches = const [],
    Set<int> workingWeekdays = const {1, 2, 3, 4, 5},
    int graceMinutes = 5,
    int breakMinutes = 60,
    int longAttendanceHours = 12,
    TimeOfDay? checkInTime,
    TimeOfDay? checkOutTime,
    TimeOfDay? policyCheckInTime,
    TimeOfDay? policyCheckOutTime,
    TimeOfDay? breakReminderTime,
    TimeOfDay? breakEndedReminderTime,
    Set<ReminderType> alreadyFired = const {},
    String locationName = 'Islamabad',
  }) {
    return ReminderNotificationPlan.build(
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
      workingWeekdays: workingWeekdays,
      alreadyFired: alreadyFired,
      locationName: locationName,
    );
  }

  ScheduledReminderNotification? of(
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

  group('happy path — before the workday', () {
    test('schedules today check-in and missed before policy time', () {
      final items = plan(now: wed(8));
      expect(
        items.map((e) => (e.type, e.fireAt)),
        containsAll([
          (ReminderType.checkIn, wed(9)),
          (ReminderType.checkInMissed, wed(9, 5)),
        ]),
      );
      expect(
        of(items, ReminderType.checkIn, day: 9)!.deliverImmediately,
        isFalse,
      );
      expect(
        of(items, ReminderType.checkInMissed, day: 9)!.deliverImmediately,
        isFalse,
      );
    });

    test('also schedules tomorrow check-in on a weekday', () {
      final items = plan(now: wed(8));
      expect(of(items, ReminderType.checkIn, day: 10), isNotNull);
      expect(of(items, ReminderType.checkInMissed, day: 10), isNotNull);
    });

    test('does not schedule checkout until the user is checked in', () {
      final items = plan(now: wed(8));
      expect(of(items, ReminderType.checkOut), isNull);
      expect(of(items, ReminderType.checkOutMissed), isNull);
      expect(of(items, ReminderType.breakTime), isNull);
      expect(of(items, ReminderType.veryLongAttendance), isNull);
    });

    test('uses location name in copy', () {
      final items = plan(now: wed(8));
      expect(of(items, ReminderType.checkIn)!.title, 'Time to check in');
      expect(of(items, ReminderType.checkIn)!.body, 'Ready to start your day?');
      expect(
        of(items, ReminderType.checkInMissed)!.title,
        'Missed your check-in?',
      );
    });

    test('blank location name falls back to work', () {
      final items = plan(now: wed(8), locationName: '  ');
      expect(
        ReminderCopy.title(ReminderType.enterLocation, locationName: 'work'),
        "You're at work",
      );
      expect(items, isNotEmpty);
    });
  });

  group('happy path — on-time attendance', () {
    test('cancels check-in reminders once the user has punched in', () {
      final items = plan(
        now: wed(8),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(7, 50)),
        ],
      );
      expect(of(items, ReminderType.checkIn, day: 9), isNull);
      expect(of(items, ReminderType.checkInMissed, day: 9), isNull);
      expect(of(items, ReminderType.checkOut), isNotNull);
      expect(of(items, ReminderType.checkOutMissed), isNotNull);
      expect(of(items, ReminderType.veryLongAttendance)!.fireAt, wed(19, 50));
      expect(of(items, ReminderType.breakTime)!.fireAt, wed(13, 25));
      expect(of(items, ReminderType.breakTime)!.deliverImmediately, isFalse);
    });

    test('punch exactly at policy check-in cancels missed', () {
      final items = plan(
        now: wed(9, 1),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9))],
      );
      expect(of(items, ReminderType.checkIn, day: 9), isNull);
      expect(of(items, ReminderType.checkInMissed, day: 9), isNull);
    });

    test('cancels checkout reminders after checkout', () {
      final items = plan(
        now: wed(18, 10),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
          ReminderPunch(kind: ReminderPunchKind.checkOut, time: wed(18, 1)),
        ],
      );
      expect(of(items, ReminderType.checkOut), isNull);
      expect(of(items, ReminderType.checkOutMissed), isNull);
      expect(of(items, ReminderType.veryLongAttendance), isNull);
      expect(of(items, ReminderType.breakTime), isNull);
    });

    test('ending a break cancels break-ended and longer-break', () {
      final items = plan(
        now: wed(14, 10),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: wed(13)),
          ReminderPunch(kind: ReminderPunchKind.breakEnd, time: wed(13, 40)),
        ],
      );
      expect(of(items, ReminderType.breakTimeEnded), isNull);
      expect(of(items, ReminderType.longerBreak), isNull);
      expect(of(items, ReminderType.checkOut), isNotNull);
    });
  });

  group('happy path — breaks', () {
    test('schedules default midday break reminder after check-in', () {
      final items = plan(
        now: wed(10),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9))],
      );
      expect(of(items, ReminderType.breakTime)!.fireAt, wed(13, 25));
      expect(of(items, ReminderType.breakTime)!.title, 'Break coming up');
      expect(of(items, ReminderType.breakTimeEnded), isNull);
      expect(of(items, ReminderType.longerBreak), isNull);
    });

    test('schedules break-ended reminders while on break', () {
      final items = plan(
        now: wed(13, 5),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: wed(13)),
        ],
      );
      expect(of(items, ReminderType.breakTime), isNull);
      expect(of(items, ReminderType.breakTimeEnded)!.fireAt, wed(14));
      expect(of(items, ReminderType.longerBreak)!.fireAt, wed(15));
      expect(
        of(items, ReminderType.breakTimeEnded)!.title,
        'Break time is over',
      );
      expect(of(items, ReminderType.longerBreak)!.title, 'Break ending soon');
      expect(
        of(items, ReminderType.longerBreak)!.body,
        'Back to work in 10 minutes.',
      );
    });

    test('custom earlier break reminder fires at the chosen time', () {
      final items = plan(
        now: wed(10),
        breakReminderTime: const TimeOfDay(hour: 12, minute: 0),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9))],
      );
      expect(of(items, ReminderType.breakTime)!.fireAt, wed(12));
    });

    test('custom earlier break-ended fires before duration due', () {
      final items = plan(
        now: wed(13, 5),
        breakEndedReminderTime: const TimeOfDay(hour: 13, minute: 30),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: wed(13)),
        ],
      );
      expect(of(items, ReminderType.breakTimeEnded)!.fireAt, wed(13, 30));
      expect(of(items, ReminderType.longerBreak)!.fireAt, wed(15));
    });
  });

  group('critical — late / missed punches', () {
    test(
      'does not catch-up check-in hours after the reminder time',
      () {
        final items = plan(now: wed(16, 59));
        expect(of(items, ReminderType.checkIn, day: 9), isNull);
        expect(of(items, ReminderType.checkInMissed, day: 9), isNull);
        expect(of(items, ReminderType.checkIn, day: 10), isNotNull);
      },
    );

    test('fires check-in on the reminder minute only', () {
      final items = plan(now: wed(9));
      expect(of(items, ReminderType.checkIn, day: 9)!.deliverImmediately, isTrue);
      expect(
        of(items, ReminderType.checkInMissed, day: 9)!.deliverImmediately,
        isFalse,
      );
    });

    test('does not notify check-in missed after the user has punched in', () {
      final items = plan(
        now: wed(21),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(17, 59)),
        ],
      );
      expect(of(items, ReminderType.checkIn, day: 9), isNull);
      expect(of(items, ReminderType.checkInMissed, day: 9), isNull);
    });

    test('punch during grace cancels missed but keeps checkout', () {
      final items = plan(
        now: wed(9, 3),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9, 3)),
        ],
      );
      expect(of(items, ReminderType.checkIn, day: 9), isNull);
      expect(of(items, ReminderType.checkInMissed, day: 9), isNull);
      expect(of(items, ReminderType.checkOut), isNotNull);
    });

    test('still checked in at checkout time gets the checkout notice', () {
      final items = plan(
        now: wed(18),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9))],
      );
      expect(of(items, ReminderType.checkOut)!.deliverImmediately, isTrue);
      expect(
        of(items, ReminderType.checkOutMissed)!.deliverImmediately,
        isFalse,
      );
      expect(of(items, ReminderType.checkOut)!.title, 'Time to check out');
    });

    test('very long attendance fires 12 hours after first punch', () {
      final items = plan(
        now: wed(21),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9))],
      );
      final long = of(items, ReminderType.veryLongAttendance)!;
      expect(long.fireAt, wed(21));
      expect(long.deliverImmediately, isTrue);
      expect(long.title, 'Still working?');
      expect(long.body, "You've been checked in for 12 hours.");
    });

    test('still working is not planned when the user has not checked in', () {
      final items = plan(now: wed(15, 51));
      expect(of(items, ReminderType.veryLongAttendance), isNull);
      expect(of(items, ReminderType.breakTime), isNull);
      expect(of(items, ReminderType.checkIn, day: 9), isNull);
    });

    test('still working waits 12 hours from actual check-in, not policy', () {
      final items = plan(
        now: wed(18),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(10))],
      );
      final long = of(items, ReminderType.veryLongAttendance)!;
      expect(long.fireAt, wed(22));
      expect(long.deliverImmediately, isFalse);
    });

    test('very long attendance does not fire after checkout', () {
      final items = plan(
        now: wed(22),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
          ReminderPunch(kind: ReminderPunchKind.checkOut, time: wed(21, 30)),
        ],
      );
      expect(of(items, ReminderType.veryLongAttendance), isNull);
    });

    test('longer break fires on the minute one hour after duration', () {
      final items = plan(
        now: wed(15),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: wed(13)),
        ],
      );
      expect(of(items, ReminderType.longerBreak)!.fireAt, wed(15));
      expect(of(items, ReminderType.longerBreak)!.deliverImmediately, isTrue);
      expect(of(items, ReminderType.breakTimeEnded), isNull);
    });
  });

  group('critical — custom times vs policy', () {
    test('earlier check-in reminder fires missed after the reminder, not policy', () {
      final items = plan(
        now: wed(7),
        checkInTime: const TimeOfDay(hour: 8, minute: 0),
        policyCheckInTime: checkIn,
        policyCheckOutTime: checkOut,
      );
      expect(of(items, ReminderType.checkIn, day: 9)!.fireAt, wed(8));
      expect(of(items, ReminderType.checkInMissed, day: 9)!.fireAt, wed(8, 5));
      expect(of(items, ReminderType.checkIn)!.body, 'Ready to start your day?');
      expect(
        of(items, ReminderType.checkInMissed, day: 9)!.body,
        "Check in now if you've started work.",
      );
    });

    test('earlier checkout reminder fires missed after the reminder, not policy', () {
      final items = plan(
        now: wed(16),
        checkOutTime: const TimeOfDay(hour: 17, minute: 0),
        policyCheckOutTime: checkOut,
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9))],
      );
      expect(of(items, ReminderType.checkOut)!.fireAt, wed(17));
      expect(of(items, ReminderType.checkOutMissed)!.fireAt, wed(17, 5));
      expect(of(items, ReminderType.checkOut)!.body, 'Wrapping up for today?');
    });

    test('on-time vs policy after custom reminder still cancels missed', () {
      final items = plan(
        now: wed(9, 10),
        checkInTime: const TimeOfDay(hour: 8, minute: 0),
        policyCheckInTime: checkIn,
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(8, 40)),
        ],
      );
      expect(of(items, ReminderType.checkIn, day: 9), isNull);
      expect(of(items, ReminderType.checkInMissed, day: 9), isNull);
    });

    test('punch at policy time after an earlier reminder cancels missed', () {
      final items = plan(
        now: wed(9, 20),
        checkInTime: const TimeOfDay(hour: 8, minute: 0),
        policyCheckInTime: checkIn,
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
        ],
      );
      expect(of(items, ReminderType.checkIn, day: 9), isNull);
      expect(of(items, ReminderType.checkInMissed, day: 9), isNull);
    });

    test('break-ended later than duration is clamped to punch duration', () {
      final items = plan(
        now: wed(13, 5),
        breakEndedReminderTime: const TimeOfDay(hour: 16, minute: 0),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: wed(13)),
        ],
      );
      expect(of(items, ReminderType.breakTimeEnded)!.fireAt, wed(14));
    });

    test('break-ended before the punch started falls back to duration', () {
      final items = plan(
        now: wed(13, 5),
        breakEndedReminderTime: const TimeOfDay(hour: 11, minute: 0),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: wed(13)),
        ],
      );
      expect(of(items, ReminderType.breakTimeEnded)!.fireAt, wed(14));
    });
  });

  group('critical — catch-up, toggles, rest days', () {
    test('break-start reminder fires on its minute, not hours later', () {
      final items = plan(
        now: wed(13, 25),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9))],
      );
      expect(of(items, ReminderType.breakTime)!.deliverImmediately, isTrue);
      expect(
        of(items, ReminderType.breakTime)!.body,
        'Your break starts in 5 minutes.',
      );

      final later = plan(
        now: wed(16, 59),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9))],
      );
      expect(of(later, ReminderType.breakTime), isNull);
    });

    test('already-fired OS reminder is not delivered again today', () {
      final items = plan(
        now: wed(10),
        alreadyFired: {ReminderType.checkIn, ReminderType.checkInMissed},
      );
      expect(of(items, ReminderType.checkIn, day: 9), isNull);
      expect(of(items, ReminderType.checkInMissed, day: 9), isNull);
      expect(of(items, ReminderType.checkIn, day: 10), isNotNull);
    });

    test('disabled reminder is not scheduled', () {
      final items = plan(
        now: wed(8),
        enabled: {
          for (final type in ReminderType.values) type: false,
          ReminderType.checkIn: true,
        },
      );
      expect(items.map((e) => e.type).toSet(), {ReminderType.checkIn});
      expect(items.first.title, 'Time to check in');
    });

    test('skips check-in reminders on a rest day', () {
      final saturday = DateTime(2026, 9, 12, 8);
      final items = plan(now: saturday);
      expect(items.where((e) => e.fireAt.day == 12), isEmpty);
    });

    test('friday does not schedule saturday when saturday is a rest day', () {
      final friday = DateTime(2026, 9, 11, 8);
      final items = plan(now: friday);
      expect(of(items, ReminderType.checkIn, day: 11), isNotNull);
      expect(of(items, ReminderType.checkIn, day: 12), isNull);
    });

    test('saturday is scheduled when it is a working day', () {
      final saturday = DateTime(2026, 9, 12, 8);
      final items = plan(now: saturday, workingWeekdays: const {6});
      expect(of(items, ReminderType.checkIn, day: 12), isNotNull);
    });

    test('empty working weekdays fall back to Mon-Fri', () {
      final items = plan(now: wed(8), workingWeekdays: {});
      expect(of(items, ReminderType.checkIn, day: 9), isNotNull);
    });

    test('zero grace fires missed at the policy time', () {
      final items = plan(now: wed(8), graceMinutes: 0);
      expect(of(items, ReminderType.checkInMissed, day: 9)!.fireAt, wed(9));
    });

    test('negative grace is treated as zero', () {
      final items = plan(now: wed(8), graceMinutes: -10);
      expect(of(items, ReminderType.checkInMissed, day: 9)!.fireAt, wed(9));
    });

    test('zero long-attendance hours default to 12', () {
      final items = plan(
        now: wed(10),
        longAttendanceHours: 0,
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9))],
      );
      expect(of(items, ReminderType.veryLongAttendance)!.fireAt, wed(21));
    });

    test('very short break schedules longer-break one hour after duration', () {
      final items = plan(
        now: wed(13, 1),
        breakMinutes: 5,
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: wed(13)),
        ],
      );
      expect(of(items, ReminderType.longerBreak)!.fireAt, wed(14, 5));
      expect(of(items, ReminderType.breakTimeEnded)!.fireAt, wed(13, 5));
    });
  });

  group('user set reminder before policy — 8:30 vs 9:00 check-in', () {
    const remindAt = TimeOfDay(hour: 8, minute: 30);

    List<ScheduledReminderNotification> early({
      required DateTime now,
      List<ReminderPunch> punches = const [],
      Set<ReminderType> alreadyFired = const {},
    }) {
      return plan(
        now: now,
        checkInTime: remindAt,
        policyCheckInTime: checkIn,
        policyCheckOutTime: checkOut,
        punches: punches,
        alreadyFired: alreadyFired,
      );
    }

    test('happy: before 8:30 schedules reminder then missed at 8:35', () {
      final items = early(now: wed(8));
      expect(of(items, ReminderType.checkIn, day: 9)!.fireAt, wed(8, 30));
      expect(
        of(items, ReminderType.checkIn, day: 9)!.deliverImmediately,
        isFalse,
      );
      expect(of(items, ReminderType.checkInMissed, day: 9)!.fireAt, wed(8, 35));
      expect(
        of(items, ReminderType.checkInMissed, day: 9)!.deliverImmediately,
        isFalse,
      );
    });

    test('happy: punch before 8:30 cancels both check-in notices', () {
      final items = early(
        now: wed(8, 20),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(8, 15)),
        ],
      );
      expect(of(items, ReminderType.checkIn, day: 9), isNull);
      expect(of(items, ReminderType.checkInMissed, day: 9), isNull);
    });

    test('happy: punch after 8:30 but before policy cancels missed', () {
      final items = early(
        now: wed(8, 50),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(8, 40)),
        ],
      );
      expect(of(items, ReminderType.checkIn, day: 9), isNull);
      expect(of(items, ReminderType.checkInMissed, day: 9), isNull);
    });

    test(
      'critical: 8:45 does not catch-up the 8:30 reminder or 8:35 missed',
      () {
        final items = early(now: wed(8, 45));
        expect(of(items, ReminderType.checkIn, day: 9), isNull);
        expect(of(items, ReminderType.checkInMissed, day: 9), isNull);
      },
    );

    test('critical: 9:10 does not catch-up 8:30 or 9:05 reminders', () {
      final items = early(now: wed(9, 10));
      expect(of(items, ReminderType.checkIn, day: 9), isNull);
      expect(of(items, ReminderType.checkInMissed, day: 9), isNull);
    });

    test('critical: punch after grace does not fire missed', () {
      final items = early(
        now: wed(9, 20),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9, 10)),
        ],
      );
      expect(of(items, ReminderType.checkIn, day: 9), isNull);
      expect(of(items, ReminderType.checkInMissed, day: 9), isNull);
    });

    test('critical: 8:30 reminder stays after punch until user dismisses', () {
      final checkInId = ReminderNotificationPlan.idFor(ReminderType.checkIn);
      final keep = ReminderNotificationPlan.persistentIds(
        alreadyFired: {ReminderType.checkIn},
        activeIds: {checkInId},
      );
      expect(keep.contains(checkInId), isTrue);
      expect(
        ReminderNotificationPlan.shouldShowNow(
          type: ReminderType.checkIn,
          id: checkInId,
          alreadyFired: {ReminderType.checkIn},
          activeIds: {checkInId},
        ),
        isFalse,
      );
      final items = early(
        now: wed(8, 50),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(8, 40)),
        ],
        alreadyFired: {ReminderType.checkIn},
      );
      expect(of(items, ReminderType.checkIn, day: 9), isNull);
    });

    test('critical: dismissed 8:30 reminder is not shown again', () {
      expect(
        ReminderNotificationPlan.shouldShowNow(
          type: ReminderType.checkIn,
          id: ReminderNotificationPlan.idFor(ReminderType.checkIn),
          alreadyFired: {ReminderType.checkIn},
          activeIds: const [],
        ),
        isFalse,
      );
    });

    test('critical: 8:31 is not allowed past 9:00 policy', () {
      expect(
        ReminderSettingsProvider.clampToLatest(
          const TimeOfDay(hour: 9, minute: 1),
          checkIn,
        ),
        checkIn,
      );
      expect(
        ReminderSettingsProvider.clampToLatest(remindAt, checkIn),
        remindAt,
      );
    });
  });

  group('user set reminder before policy — checkout, break, break end', () {
    test('happy: checkout reminder at 5:30, missed at 5:35', () {
      final items = plan(
        now: wed(16),
        checkOutTime: const TimeOfDay(hour: 17, minute: 30),
        policyCheckOutTime: checkOut,
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9))],
      );
      expect(of(items, ReminderType.checkOut)!.fireAt, wed(17, 30));
      expect(of(items, ReminderType.checkOutMissed)!.fireAt, wed(17, 35));
      expect(of(items, ReminderType.checkOut)!.deliverImmediately, isFalse);
    });

    test('happy: checkout punch after 5:30 reminder cancels both', () {
      final items = plan(
        now: wed(17, 50),
        checkOutTime: const TimeOfDay(hour: 17, minute: 30),
        policyCheckOutTime: checkOut,
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
          ReminderPunch(kind: ReminderPunchKind.checkOut, time: wed(17, 40)),
        ],
      );
      expect(of(items, ReminderType.checkOut), isNull);
      expect(of(items, ReminderType.checkOutMissed), isNull);
    });

    test('critical: 5:45 does not catch-up the 5:30 checkout or 5:35 missed', () {
      final items = plan(
        now: wed(17, 45),
        checkOutTime: const TimeOfDay(hour: 17, minute: 30),
        policyCheckOutTime: checkOut,
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9))],
      );
      expect(of(items, ReminderType.checkOut), isNull);
      expect(of(items, ReminderType.checkOutMissed), isNull);
    });

    test('happy: break reminder at 12:30 instead of 1:25', () {
      final items = plan(
        now: wed(10),
        breakReminderTime: const TimeOfDay(hour: 12, minute: 30),
        punches: [ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9))],
      );
      expect(of(items, ReminderType.breakTime)!.fireAt, wed(12, 30));
      expect(of(items, ReminderType.breakTime)!.deliverImmediately, isFalse);
    });

    test('happy: taking break before 12:30 skips the take-break notice', () {
      final items = plan(
        now: wed(12, 40),
        breakReminderTime: const TimeOfDay(hour: 12, minute: 30),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: wed(12, 20)),
        ],
      );
      expect(of(items, ReminderType.breakTime), isNull);
    });

    test(
      'critical: 12:40 does not catch-up the 12:30 take-break reminder',
      () {
        final items = plan(
          now: wed(12, 40),
          breakReminderTime: const TimeOfDay(hour: 12, minute: 30),
          punches: [
            ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
          ],
        );
        final breaks = items.where(
          (item) => item.type == ReminderType.breakTime && item.fireAt.day == 9,
        );
        expect(breaks, isEmpty);
      },
    );

    test('happy: break-ended reminder at 2:00 while on a 1:00 break', () {
      final items = plan(
        now: wed(13, 10),
        breakEndedReminderTime: const TimeOfDay(hour: 14, minute: 0),
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: wed(9)),
          ReminderPunch(kind: ReminderPunchKind.breakStart, time: wed(13)),
        ],
      );
      expect(of(items, ReminderType.breakTimeEnded)!.fireAt, wed(14));
      expect(of(items, ReminderType.longerBreak)!.fireAt, wed(15));
    });

    test(
      'critical: checkout reminder stays visible after punch until dismissed',
      () {
        final id = ReminderNotificationPlan.idFor(ReminderType.checkOut);
        expect(
          ReminderNotificationPlan.persistentIds(
            alreadyFired: {ReminderType.checkOut},
            activeIds: {id},
          ),
          contains(id),
        );
        expect(
          ReminderNotificationPlan.shouldShowNow(
            type: ReminderType.checkOut,
            id: id,
            alreadyFired: const {},
            activeIds: {id},
          ),
          isFalse,
        );
      },
    );
  });

  group('ids, copy, and time clamps', () {
    test('notification ids are unique across types and day offsets', () {
      final ids = <int>{};
      for (final type in ReminderType.values) {
        for (final offset in [0, 1]) {
          final id = ReminderNotificationPlan.idFor(type, dayOffset: offset);
          expect(
            ids.add(id),
            isTrue,
            reason: 'collision on $type offset $offset',
          );
        }
      }
    });

    test('default break window is midpoint minus five, plus duration', () {
      expect(
        ReminderNotificationPlan.defaultBreakReminderTime(
          checkInTime: checkIn,
          checkOutTime: checkOut,
        ),
        const TimeOfDay(hour: 13, minute: 25),
      );
      expect(
        ReminderNotificationPlan.defaultBreakEndedReminderTime(
          checkInTime: checkIn,
          checkOutTime: checkOut,
          breakMinutes: 60,
        ),
        const TimeOfDay(hour: 14, minute: 30),
      );
    });

    test('clampToLatest rejects times after the policy time', () {
      const policy = TimeOfDay(hour: 9, minute: 0);
      expect(
        ReminderSettingsProvider.clampToLatest(
          const TimeOfDay(hour: 9, minute: 1),
          policy,
        ),
        policy,
      );
      expect(
        ReminderSettingsProvider.clampToLatest(
          const TimeOfDay(hour: 8, minute: 0),
          policy,
        ),
        const TimeOfDay(hour: 8, minute: 0),
      );
      expect(ReminderSettingsProvider.clampToLatest(policy, policy), policy);
    });

    test('picker clamp matches provider clamp', () {
      const latest = TimeOfDay(hour: 18, minute: 0);
      const tooLate = TimeOfDay(hour: 18, minute: 1);
      const earlier = TimeOfDay(hour: 17, minute: 0);
      expect(
        ReminderTimePickerSheet.clamp(tooLate, latest),
        ReminderSettingsProvider.clampToLatest(tooLate, latest),
      );
      expect(
        ReminderTimePickerSheet.clamp(earlier, latest),
        ReminderSettingsProvider.clampToLatest(earlier, latest),
      );
    });

    test('only check-in, check-out, and break times are editable', () {
      expect(ReminderType.checkIn.canPickEarlierTime, isTrue);
      expect(ReminderType.checkOut.canPickEarlierTime, isTrue);
      expect(ReminderType.breakTime.canPickEarlierTime, isTrue);
      expect(ReminderType.breakTimeEnded.canPickEarlierTime, isTrue);
      expect(ReminderType.checkInMissed.canPickEarlierTime, isFalse);
      expect(ReminderType.checkOutMissed.canPickEarlierTime, isFalse);
      expect(ReminderType.longerBreak.canPickEarlierTime, isFalse);
      expect(ReminderType.veryLongAttendance.canPickEarlierTime, isFalse);
      expect(ReminderType.enterLocation.canPickEarlierTime, isFalse);
      expect(ReminderType.leaveLocation.canPickEarlierTime, isFalse);
    });

    test('copy exists for every reminder type', () {
      for (final type in ReminderType.values) {
        expect(ReminderCopy.title(type, locationName: 'Office'), isNotEmpty);
        expect(ReminderCopy.message(type), isNotEmpty);
        expect(type.storageKey, isNotEmpty);
        expect(ReminderType.fromStorageKey(type.storageKey), type);
      }
    });
  });

  group('first-time vs returning activation', () {
    test('first-time login waits for Clock', () {
      expect(
        ReminderSettingsProvider.shouldScheduleOnLoad(
          resumeExistingSession: false,
          clockArmed: false,
        ),
        isFalse,
      );
    });

    test('returning session keeps scheduling without Clock', () {
      expect(
        ReminderSettingsProvider.shouldScheduleOnLoad(
          resumeExistingSession: true,
          clockArmed: false,
        ),
        isTrue,
      );
    });

    test('Clock visit arms later logins', () {
      expect(
        ReminderSettingsProvider.shouldScheduleOnLoad(
          resumeExistingSession: false,
          clockArmed: true,
        ),
        isTrue,
      );
    });
  });

  group('evening login does not dump morning reminders', () {
    test('5pm does not fire 9am check-in or missed', () {
      final items = plan(now: wed(17));
      expect(of(items, ReminderType.checkIn, day: 9), isNull);
      expect(of(items, ReminderType.checkInMissed, day: 9), isNull);
      expect(
        of(items, ReminderType.checkIn, day: 10)!.fireAt,
        DateTime(2026, 9, 10, 9),
      );
      expect(
        of(items, ReminderType.checkIn, day: 10)!.deliverImmediately,
        isFalse,
      );
    });

    test('picked 8am reminder still schedules 8am, not permission 9am', () {
      final items = plan(
        now: wed(7),
        checkInTime: const TimeOfDay(hour: 8, minute: 0),
        policyCheckInTime: checkIn,
      );
      expect(of(items, ReminderType.checkIn, day: 9)!.fireAt, wed(8));
      expect(of(items, ReminderType.checkInMissed, day: 9)!.fireAt, wed(8, 5));
    });
  });
}
