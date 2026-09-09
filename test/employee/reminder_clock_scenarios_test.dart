import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/more/data/models/reminder_log.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';
import 'package:obecno/features/more/providers/reminder_settings_provider.dart';
import 'package:obecno/features/more/services/reminder_notification_plan.dart';

/// Clock-jump scenarios for check-in, check-out, break start, and break end.
/// Permission time can be anything; the user reminder can be any earlier time.
void main() {
  DateTime onDay(TimeOfDay time) =>
      DateTime(2026, 9, 9, time.hour, time.minute);

  DateTime after(TimeOfDay time, int minutes) =>
      onDay(time).add(Duration(minutes: minutes));

  Map<ReminderType, bool> allOn() => {
    for (final type in ReminderType.values)
      type:
          type != ReminderType.enterLocation &&
          type != ReminderType.leaveLocation,
  };

  List<ScheduledReminderNotification> plan({
    required DateTime now,
    required TimeOfDay policyCheckIn,
    required TimeOfDay policyCheckOut,
    TimeOfDay? remindCheckIn,
    TimeOfDay? remindCheckOut,
    TimeOfDay? remindBreak,
    TimeOfDay? remindBreakEnd,
    List<ReminderPunch> punches = const [],
    int graceMinutes = 5,
    int breakMinutes = 60,
    Map<ReminderType, bool>? enabled,
    Set<ReminderType> alreadyFired = const {},
  }) {
    return ReminderNotificationPlan.build(
      now: now,
      enabled: enabled ?? allOn(),
      checkInTime: remindCheckIn ?? policyCheckIn,
      checkOutTime: remindCheckOut ?? policyCheckOut,
      policyCheckInTime: policyCheckIn,
      policyCheckOutTime: policyCheckOut,
      breakReminderTime: remindBreak,
      breakEndedReminderTime: remindBreakEnd,
      graceMinutes: graceMinutes,
      breakMinutes: breakMinutes,
      longAttendanceHours: 12,
      punches: punches,
      workingWeekdays: const {1, 2, 3, 4, 5},
      alreadyFired: alreadyFired,
    );
  }

  List<ScheduledReminderNotification> ofType(
    List<ScheduledReminderNotification> items,
    ReminderType type,
  ) {
    return items
        .where((item) => item.type == type && item.fireAt.day == 9)
        .toList();
  }

  void expectStaysUntilDismissed(ReminderType type) {
    final id = ReminderNotificationPlan.idFor(type);
    expect(
      ReminderNotificationPlan.persistentIds(
        alreadyFired: {type},
        activeIds: {id},
      ),
      contains(id),
    );
    expect(
      ReminderNotificationPlan.shouldShowNow(
        type: type,
        id: id,
        alreadyFired: {type},
        activeIds: const [],
      ),
      isFalse,
    );
  }

  void expectCannotPickAfter(TimeOfDay policy, TimeOfDay remind) {
    final tooLate = ReminderNotificationPlan.timeFromMinutes(
      ReminderNotificationPlan.minutesOf(policy) + 1,
    );
    expect(ReminderSettingsProvider.clampToLatest(tooLate, policy), policy);
    expect(ReminderSettingsProvider.clampToLatest(remind, policy), remind);
  }

  group('check-in — happy and critical', () {
    void runCase({
      required TimeOfDay policy,
      required TimeOfDay remind,
      required int graceMinutes,
    }) {
      final label = ReminderCopy.formatTime(remind);
      final remindAt = onDay(remind);
      final policyAt = onDay(policy);
      final missedAt = after(remind, graceMinutes);
      const policyOut = TimeOfDay(hour: 18, minute: 0);

      group(
        'permission ${ReminderCopy.formatTime(policy)}, reminder ${ReminderCopy.formatTime(remind)}, grace $graceMinutes',
        () {
          test('happy: clock at reminder time shows Check time is $label', () {
            final items = plan(
              now: remindAt,
              policyCheckIn: policy,
              policyCheckOut: policyOut,
              remindCheckIn: remind,
              graceMinutes: graceMinutes,
            );
            final checkIn = ofType(items, ReminderType.checkIn);
            expect(checkIn.any((item) => item.fireAt == remindAt), isTrue);
            expect(checkIn.first.body, 'Ready to start your day?');
            expect(checkIn.first.title, 'Time to check in');
            expect(
              ofType(items, ReminderType.checkInMissed).single.fireAt,
              missedAt,
            );
            expect(
              ofType(
                items,
                ReminderType.checkInMissed,
              ).single.deliverImmediately,
              isFalse,
            );
          });

          test('happy: clock at permission time does not catch-up check-in', () {
            final items = plan(
              now: policyAt,
              policyCheckIn: policy,
              policyCheckOut: policyOut,
              remindCheckIn: remind,
              graceMinutes: graceMinutes,
            );
            expect(
              ofType(items, ReminderType.checkIn).any(
                (item) => item.deliverImmediately && item.fireAt == remindAt,
              ),
              isFalse,
            );
          });

          test(
            'happy: punch between reminder and permission cancels missed',
            () {
              final items = plan(
                now: after(policy, 1),
                policyCheckIn: policy,
                policyCheckOut: policyOut,
                remindCheckIn: remind,
                graceMinutes: graceMinutes,
                punches: [
                  ReminderPunch(
                    kind: ReminderPunchKind.checkIn,
                    time: remindAt.add(const Duration(minutes: 5)),
                  ),
                ],
              );
              expect(ofType(items, ReminderType.checkIn), isEmpty);
              expect(ofType(items, ReminderType.checkInMissed), isEmpty);
            },
          );

          test('happy: cannot set reminder after permission time', () {
            expectCannotPickAfter(policy, remind);
          });

          test('critical: at missed minute with no punch shows Check In Missed', () {
            final items = plan(
              now: missedAt,
              policyCheckIn: policy,
              policyCheckOut: policyOut,
              remindCheckIn: remind,
              graceMinutes: graceMinutes,
            );
            final missed = ofType(items, ReminderType.checkInMissed).single;
            expect(missed.fireAt, missedAt);
            expect(missed.deliverImmediately, isTrue);
            expect(missed.title, 'Missed your check-in?');
            expect(missed.body, "Check in now if you've started work.");
          });

          test('critical: punch after grace does not fire missed', () {
            final items = plan(
              now: missedAt.add(const Duration(minutes: 10)),
              policyCheckIn: policy,
              policyCheckOut: policyOut,
              remindCheckIn: remind,
              graceMinutes: graceMinutes,
              punches: [
                ReminderPunch(
                  kind: ReminderPunchKind.checkIn,
                  time: missedAt.add(const Duration(minutes: 5)),
                ),
              ],
            );
            expect(ofType(items, ReminderType.checkIn), isEmpty);
            expect(ofType(items, ReminderType.checkInMissed), isEmpty);
          });

          test('critical: banner stays until the user dismisses it', () {
            expectStaysUntilDismissed(ReminderType.checkIn);
            expectStaysUntilDismissed(ReminderType.checkInMissed);
          });
        },
      );
    }

    runCase(
      policy: const TimeOfDay(hour: 9, minute: 0),
      remind: const TimeOfDay(hour: 8, minute: 0),
      graceMinutes: 30,
    );
    runCase(
      policy: const TimeOfDay(hour: 10, minute: 15),
      remind: const TimeOfDay(hour: 7, minute: 45),
      graceMinutes: 15,
    );
  });

  group('check-out — happy and critical', () {
    void runCase({
      required TimeOfDay policy,
      required TimeOfDay remind,
      required int graceMinutes,
    }) {
      final label = ReminderCopy.formatTime(remind);
      final missedAt = after(remind, graceMinutes);
      const policyIn = TimeOfDay(hour: 9, minute: 0);
      final inPunch = [
        ReminderPunch(kind: ReminderPunchKind.checkIn, time: onDay(policyIn)),
      ];

      group(
        'permission ${ReminderCopy.formatTime(policy)}, reminder ${ReminderCopy.formatTime(remind)}, grace $graceMinutes',
        () {
          test(
            'happy: clock at reminder time shows Check-out time is $label',
            () {
              final items = plan(
                now: onDay(remind),
                policyCheckIn: policyIn,
                policyCheckOut: policy,
                remindCheckOut: remind,
                graceMinutes: graceMinutes,
                punches: inPunch,
              );
              final checkout = ofType(items, ReminderType.checkOut);
              expect(
                checkout.any((item) => item.fireAt == onDay(remind)),
                isTrue,
              );
              expect(checkout.first.body, 'Wrapping up for today?');
              expect(checkout.first.title, 'Time to check out');
              expect(
                ofType(items, ReminderType.checkOutMissed).single.fireAt,
                missedAt,
              );
            },
          );

          test('happy: clock at permission time does not catch-up checkout', () {
            final items = plan(
              now: onDay(policy),
              policyCheckIn: policyIn,
              policyCheckOut: policy,
              remindCheckOut: remind,
              graceMinutes: graceMinutes,
              punches: inPunch,
            );
            expect(
              ofType(
                items,
                ReminderType.checkOut,
              ).any((item) => item.deliverImmediately),
              isFalse,
            );
          });

          test(
            'happy: checkout between reminder and permission cancels missed',
            () {
              final items = plan(
                now: after(policy, 1),
                policyCheckIn: policyIn,
                policyCheckOut: policy,
                remindCheckOut: remind,
                graceMinutes: graceMinutes,
                punches: [
                  ...inPunch,
                  ReminderPunch(
                    kind: ReminderPunchKind.checkOut,
                    time: onDay(remind).add(const Duration(minutes: 5)),
                  ),
                ],
              );
              expect(ofType(items, ReminderType.checkOut), isEmpty);
              expect(ofType(items, ReminderType.checkOutMissed), isEmpty);
            },
          );

          test('happy: not checked in means no checkout notices', () {
            final items = plan(
              now: onDay(remind),
              policyCheckIn: policyIn,
              policyCheckOut: policy,
              remindCheckOut: remind,
              graceMinutes: graceMinutes,
            );
            expect(ofType(items, ReminderType.checkOut), isEmpty);
            expect(ofType(items, ReminderType.checkOutMissed), isEmpty);
          });

          test('happy: cannot set reminder after permission time', () {
            expectCannotPickAfter(policy, remind);
          });

          test(
            'critical: at missed minute still checked in shows Check Out Missed',
            () {
              final items = plan(
                now: missedAt,
                policyCheckIn: policyIn,
                policyCheckOut: policy,
                remindCheckOut: remind,
                graceMinutes: graceMinutes,
                punches: inPunch,
              );
              final missed = ofType(items, ReminderType.checkOutMissed).single;
              expect(missed.deliverImmediately, isTrue);
              expect(missed.title, 'Still checked in?');
              expect(missed.body, "Check out if you've finished work.");
            },
          );

          test('critical: banner stays until the user dismisses it', () {
            expectStaysUntilDismissed(ReminderType.checkOut);
            expectStaysUntilDismissed(ReminderType.checkOutMissed);
          });
        },
      );
    }

    runCase(
      policy: const TimeOfDay(hour: 18, minute: 0),
      remind: const TimeOfDay(hour: 17, minute: 0),
      graceMinutes: 30,
    );
    runCase(
      policy: const TimeOfDay(hour: 19, minute: 30),
      remind: const TimeOfDay(hour: 18, minute: 10),
      graceMinutes: 10,
    );
  });

  group('break start — happy and critical', () {
    void runCase({
      required TimeOfDay policyCheckIn,
      required TimeOfDay policyCheckOut,
      required TimeOfDay remind,
    }) {
      final policyBreak = ReminderNotificationPlan.defaultBreakReminderTime(
        checkInTime: policyCheckIn,
        checkOutTime: policyCheckOut,
      );
      final label = ReminderCopy.formatTime(remind);
      final inPunch = [
        ReminderPunch(
          kind: ReminderPunchKind.checkIn,
          time: onDay(policyCheckIn),
        ),
      ];

      group(
        'work ${ReminderCopy.formatTime(policyCheckIn)}-${ReminderCopy.formatTime(policyCheckOut)}, reminder ${ReminderCopy.formatTime(remind)}',
        () {
          test('happy: clock at reminder time shows Break time is $label', () {
            final items = plan(
              now: onDay(remind),
              policyCheckIn: policyCheckIn,
              policyCheckOut: policyCheckOut,
              remindBreak: remind,
              punches: inPunch,
            );
            final breaks = ofType(items, ReminderType.breakTime);
            expect(breaks.any((item) => item.fireAt == onDay(remind)), isTrue);
            expect(breaks.first.body, 'Your break starts in 5 minutes.');
            expect(breaks.first.title, 'Break coming up');
          });

          test('happy: clock at permission break time does not catch-up break', () {
            final items = plan(
              now: onDay(policyBreak),
              policyCheckIn: policyCheckIn,
              policyCheckOut: policyCheckOut,
              remindBreak: remind,
              punches: inPunch,
            );
            expect(
              ofType(items, ReminderType.breakTime).any(
                (item) =>
                    item.deliverImmediately && item.fireAt == onDay(remind),
              ),
              isFalse,
            );
          });

          test('happy: starting break before reminder cancels take-break', () {
            final items = plan(
              now: onDay(remind),
              policyCheckIn: policyCheckIn,
              policyCheckOut: policyCheckOut,
              remindBreak: remind,
              punches: [
                ...inPunch,
                ReminderPunch(
                  kind: ReminderPunchKind.breakStart,
                  time: onDay(remind).subtract(const Duration(minutes: 10)),
                ),
              ],
            );
            expect(ofType(items, ReminderType.breakTime), isEmpty);
          });

          test('happy: cannot set reminder after permission break time', () {
            expectCannotPickAfter(policyBreak, remind);
          });

          test(
            'critical: after reminder, early take-break does not catch-up',
            () {
              final items = plan(
                now: onDay(remind).add(const Duration(minutes: 10)),
                policyCheckIn: policyCheckIn,
                policyCheckOut: policyCheckOut,
                remindBreak: remind,
                punches: inPunch,
              );
              expect(ofType(items, ReminderType.breakTime), isEmpty);
            },
          );

          test('critical: after permission break time does not catch-up break', () {
            final items = plan(
              now: onDay(policyBreak).add(const Duration(minutes: 20)),
              policyCheckIn: policyCheckIn,
              policyCheckOut: policyCheckOut,
              remindBreak: remind,
              punches: inPunch,
            );
            expect(ofType(items, ReminderType.breakTime), isEmpty);
          });

          test('critical: banner stays until the user dismisses it', () {
            expectStaysUntilDismissed(ReminderType.breakTime);
          });
        },
      );
    }

    runCase(
      policyCheckIn: const TimeOfDay(hour: 9, minute: 0),
      policyCheckOut: const TimeOfDay(hour: 18, minute: 0),
      remind: const TimeOfDay(hour: 12, minute: 0),
    );
    runCase(
      policyCheckIn: const TimeOfDay(hour: 8, minute: 0),
      policyCheckOut: const TimeOfDay(hour: 16, minute: 0),
      remind: const TimeOfDay(hour: 11, minute: 15),
    );
  });

  group('break end — happy and critical', () {
    void runCase({
      required TimeOfDay policyCheckIn,
      required TimeOfDay policyCheckOut,
      required TimeOfDay remind,
      required int breakMinutes,
    }) {
      final policyEnd = ReminderNotificationPlan.defaultBreakEndedReminderTime(
        checkInTime: policyCheckIn,
        checkOutTime: policyCheckOut,
        breakMinutes: breakMinutes,
      );
      final label = ReminderCopy.formatTime(remind);
      final breakStart = onDay(remind).subtract(const Duration(minutes: 15));
      final onBreak = [
        ReminderPunch(
          kind: ReminderPunchKind.checkIn,
          time: onDay(policyCheckIn),
        ),
        ReminderPunch(kind: ReminderPunchKind.breakStart, time: breakStart),
      ];
      final breakDue = breakStart.add(Duration(minutes: breakMinutes));

      group(
        'work ${ReminderCopy.formatTime(policyCheckIn)}-${ReminderCopy.formatTime(policyCheckOut)}, reminder ${ReminderCopy.formatTime(remind)}',
        () {
          test(
            'happy: clock at reminder time shows Break end time is $label',
            () {
              final items = plan(
                now: onDay(remind),
                policyCheckIn: policyCheckIn,
                policyCheckOut: policyCheckOut,
                remindBreakEnd: remind,
                breakMinutes: breakMinutes,
                punches: onBreak,
              );
              final ended = ofType(items, ReminderType.breakTimeEnded);
              expect(ended, isNotEmpty);
              expect(ended.first.body, 'Ready to get back to work?');
              expect(ended.first.title, 'Break time is over');
            },
          );

          test('happy: clock at permission end time does not catch-up break end', () {
            final items = plan(
              now: onDay(policyEnd),
              policyCheckIn: policyCheckIn,
              policyCheckOut: policyCheckOut,
              remindBreakEnd: remind,
              breakMinutes: breakMinutes,
              punches: onBreak,
            );
            expect(
              ofType(items, ReminderType.breakTimeEnded).any(
                (item) => item.deliverImmediately && item.fireAt == onDay(remind),
              ),
              isFalse,
            );
          });

          test('happy: ending break on time cancels break-end notices', () {
            final items = plan(
              now: onDay(remind).add(const Duration(minutes: 20)),
              policyCheckIn: policyCheckIn,
              policyCheckOut: policyCheckOut,
              remindBreakEnd: remind,
              breakMinutes: breakMinutes,
              punches: [
                ...onBreak,
                ReminderPunch(
                  kind: ReminderPunchKind.breakEnd,
                  time: onDay(remind).add(const Duration(minutes: 5)),
                ),
              ],
            );
            expect(ofType(items, ReminderType.breakTimeEnded), isEmpty);
            expect(ofType(items, ReminderType.longerBreak), isEmpty);
          });

          test(
            'happy: cannot set reminder after permission break-end time',
            () {
              expectCannotPickAfter(policyEnd, remind);
            },
          );

          test('critical: still on break at end minute shows break-ended', () {
            final items = plan(
              now: onDay(remind),
              policyCheckIn: policyCheckIn,
              policyCheckOut: policyCheckOut,
              remindBreakEnd: remind,
              breakMinutes: breakMinutes,
              punches: onBreak,
            );
            expect(
              ofType(
                items,
                ReminderType.breakTimeEnded,
              ).any((item) => item.deliverImmediately),
              isTrue,
            );
          });

          test(
            'critical: longer-break fires one hour after break duration ends',
            () {
              final longerAt = breakDue.add(const Duration(hours: 1));
              final items = plan(
                now: longerAt,
                policyCheckIn: policyCheckIn,
                policyCheckOut: policyCheckOut,
                remindBreakEnd: remind,
                breakMinutes: breakMinutes,
                punches: onBreak,
              );
              final longer = ofType(items, ReminderType.longerBreak);
              expect(longer, isNotEmpty);
              expect(longer.first.fireAt, longerAt);
              expect(longer.any((item) => item.deliverImmediately), isTrue);
              expect(longer.first.title, 'Break ending soon');
              expect(longer.first.body, 'Back to work in 10 minutes.');
            },
          );

          test('critical: banner stays until the user dismisses it', () {
            expectStaysUntilDismissed(ReminderType.breakTimeEnded);
            expectStaysUntilDismissed(ReminderType.longerBreak);
          });
        },
      );
    }

    runCase(
      policyCheckIn: const TimeOfDay(hour: 9, minute: 0),
      policyCheckOut: const TimeOfDay(hour: 18, minute: 0),
      remind: const TimeOfDay(hour: 14, minute: 0),
      breakMinutes: 60,
    );
    runCase(
      policyCheckIn: const TimeOfDay(hour: 8, minute: 0),
      policyCheckOut: const TimeOfDay(hour: 17, minute: 0),
      remind: const TimeOfDay(hour: 12, minute: 30),
      breakMinutes: 45,
    );
  });

  group('earlier reminder names the notification time', () {
    ScheduledReminderNotification? due(
      List<ScheduledReminderNotification> items,
      ReminderType type,
      DateTime fireAt,
    ) {
      for (final item in items) {
        if (item.type == type && item.fireAt == fireAt) return item;
      }
      return null;
    }

    test('check-in at 12:26 AM says Check time is 12:26 AM', () {
      const policy = TimeOfDay(hour: 9, minute: 0);
      const remind = TimeOfDay(hour: 0, minute: 26);
      final fireAt = onDay(remind);
      final items = plan(
        now: fireAt.add(const Duration(seconds: 37)),
        policyCheckIn: policy,
        policyCheckOut: const TimeOfDay(hour: 18, minute: 0),
        remindCheckIn: remind,
        graceMinutes: 30,
      );
      final checkIn = due(items, ReminderType.checkIn, fireAt)!;
      expect(checkIn.deliverImmediately, isTrue);
      expect(checkIn.title, 'Time to check in');
      expect(checkIn.body, 'Ready to start your day?');
    });

    test('check-out at 5:00 PM says Check-out time is 05:00 PM', () {
      const policy = TimeOfDay(hour: 18, minute: 0);
      const remind = TimeOfDay(hour: 17, minute: 0);
      final fireAt = onDay(remind);
      final items = plan(
        now: fireAt.add(const Duration(seconds: 37)),
        policyCheckIn: const TimeOfDay(hour: 9, minute: 0),
        policyCheckOut: policy,
        remindCheckOut: remind,
        punches: [
          ReminderPunch(
            kind: ReminderPunchKind.checkIn,
            time: onDay(const TimeOfDay(hour: 9, minute: 0)),
          ),
        ],
      );
      final checkout = due(items, ReminderType.checkOut, fireAt)!;
      expect(checkout.deliverImmediately, isTrue);
      expect(checkout.title, 'Time to check out');
      expect(checkout.body, 'Wrapping up for today?');
    });

    test('break at 12:00 PM says Break time is 12:00 PM', () {
      const policyIn = TimeOfDay(hour: 9, minute: 0);
      const policyOut = TimeOfDay(hour: 18, minute: 0);
      const remind = TimeOfDay(hour: 12, minute: 0);
      final fireAt = onDay(remind);
      final items = plan(
        now: fireAt.add(const Duration(seconds: 37)),
        policyCheckIn: policyIn,
        policyCheckOut: policyOut,
        remindBreak: remind,
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: onDay(policyIn)),
        ],
      );
      final breaks = due(items, ReminderType.breakTime, fireAt)!;
      expect(breaks.deliverImmediately, isTrue);
      expect(breaks.title, 'Break coming up');
      expect(breaks.body, 'Your break starts in 5 minutes.');
    });

    test('break end at 2:00 PM says Break end time is 02:00 PM', () {
      const policyIn = TimeOfDay(hour: 9, minute: 0);
      const policyOut = TimeOfDay(hour: 18, minute: 0);
      const remind = TimeOfDay(hour: 14, minute: 0);
      final fireAt = onDay(remind);
      final items = plan(
        now: fireAt.add(const Duration(seconds: 37)),
        policyCheckIn: policyIn,
        policyCheckOut: policyOut,
        remindBreakEnd: remind,
        breakMinutes: 60,
        punches: [
          ReminderPunch(kind: ReminderPunchKind.checkIn, time: onDay(policyIn)),
          ReminderPunch(
            kind: ReminderPunchKind.breakStart,
            time: fireAt.subtract(const Duration(minutes: 15)),
          ),
        ],
      );
      final ended = items.where((item) => item.type == ReminderType.breakTimeEnded);
      expect(ended.any((item) => item.deliverImmediately), isTrue);
      expect(ended.first.title, 'Break time is over');
      expect(ended.first.body, 'Ready to get back to work?');
    });
  });
}
