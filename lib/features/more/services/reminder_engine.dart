import 'package:flutter/material.dart';

import 'package:obecno/features/more/data/local/reminder_dao.dart';
import 'package:obecno/features/more/data/models/reminder_log.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';
import 'package:obecno/features/more/services/reminder_notification_plan.dart';

class ReminderEngine {
  ReminderEngine._();

  static const _statusDependentTypes = {
    ReminderType.checkOut,
    ReminderType.checkOutMissed,
    ReminderType.breakTime,
    ReminderType.breakTimeEnded,
    ReminderType.longerBreak,
    ReminderType.veryLongAttendance,
    ReminderType.leaveLocation,
  };

  static Future<List<ReminderLog>> syncDay({
    required ReminderDao dao,
    required String userId,
    required DateTime day,
    required DateTime now,
    required Map<ReminderType, bool> enabled,
    required TimeOfDay checkInTime,
    required TimeOfDay checkOutTime,
    TimeOfDay? policyCheckInTime,
    TimeOfDay? policyCheckOutTime,
    TimeOfDay? breakReminderTime,
    TimeOfDay? breakEndedReminderTime,
    TimeOfDay? checkInMissedTime,
    TimeOfDay? checkOutMissedTime,
    required int graceMinutes,
    int? checkInMissedMinutes,
    int? checkOutMissedMinutes,
    int? longerBreakMinutes,
    required int breakMinutes,
    required int longAttendanceHours,
    required List<ReminderPunch> punches,
    String locationName = 'work',
  }) async {
    if (userId.isEmpty) return const [];

    final status = ReminderClockStatus.fromPunches(punches);
    final policyIn = policyCheckInTime ?? checkInTime;
    final policyOut = policyCheckOutTime ?? checkOutTime;
    final breakAtTime =
        breakReminderTime ??
        ReminderNotificationPlan.defaultBreakReminderTime(
          checkInTime: policyIn,
          checkOutTime: policyOut,
        );
    final breakEndedAtTime =
        breakEndedReminderTime ??
        ReminderNotificationPlan.defaultBreakEndedReminderTime(
          checkInTime: policyIn,
          checkOutTime: policyOut,
          breakMinutes: breakMinutes,
        );
    final schedule = ReminderFireSchedule.forDay(
      day: day,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      policyCheckInTime: policyIn,
      policyCheckOutTime: policyOut,
      breakReminderTime: breakAtTime,
      breakEndedReminderTime: breakEndedAtTime,
      checkInMissedTime: checkInMissedTime,
      checkOutMissedTime: checkOutMissedTime,
      graceMinutes: graceMinutes,
      checkInMissedMinutes: checkInMissedMinutes,
      checkOutMissedMinutes: checkOutMissedMinutes,
      longerBreakMinutes: longerBreakMinutes,
      breakMinutes: breakMinutes,
      longAttendanceHours: longAttendanceHours,
      status: status,
    );

    await _pruneInvalidLogs(
      dao: dao,
      userId: userId,
      day: day,
      now: now,
      status: status,
      schedule: schedule,
    );

    Future<void> logIfDue(ReminderType type, DateTime fireAt, bool due) async {
      if (!(enabled[type] ?? false)) return;
      if (!due) return;
      if (fireAt.isAfter(now)) return;
      await dao.insertLogIfAbsent(
        userId: userId,
        date: day,
        log: ReminderLog(
          type: type,
          firedAt: fireAt,
          title: ReminderCopy.title(type, locationName: locationName),
          message: ReminderCopy.message(
            type,
            checkInTime: checkInTime,
            checkOutTime: checkOutTime,
            breakTime: breakAtTime,
            breakEndTime: breakEndedAtTime,
            longAttendanceHours: longAttendanceHours,
          ),
          clockStatus: status.storageValue,
        ),
      );
    }

    bool afterStartingWork(DateTime fireAt) {
      final start = status.firstCheckIn;
      if (start == null) return false;
      return !fireAt.isBefore(start);
    }

    await logIfDue(
      ReminderType.checkIn,
      schedule.checkInAt,
      status.hasNotStarted ||
          (status.firstCheckIn != null &&
              status.firstCheckIn!.isAfter(schedule.checkInAt)),
    );
    await logIfDue(
      ReminderType.checkInMissed,
      schedule.checkInMissedAt,
      status.hasNotStarted ||
          (status.firstCheckIn != null &&
              status.firstCheckIn!.isAfter(schedule.checkInMissedAt)),
    );

    await logIfDue(
      ReminderType.checkOut,
      schedule.checkOutAt,
      afterStartingWork(schedule.checkOutAt) &&
          (status.isCheckedIn ||
              (status.lastCheckOut != null &&
                  status.lastCheckOut!.isAfter(schedule.checkOutAt))),
    );
    await logIfDue(
      ReminderType.checkOutMissed,
      schedule.checkOutMissedAt,
      afterStartingWork(schedule.checkOutMissedAt) &&
          (status.isCheckedIn ||
              (status.lastCheckOut != null &&
                  status.lastCheckOut!.isAfter(schedule.checkOutMissedAt))),
    );

    if (status.firstCheckIn != null) {
      await logIfDue(ReminderType.enterLocation, status.firstCheckIn!, true);
    }
    if (status.lastCheckOut != null) {
      await logIfDue(ReminderType.leaveLocation, status.lastCheckOut!, true);
    }

    await logIfDue(
      ReminderType.breakTime,
      schedule.breakAt,
      afterStartingWork(schedule.breakAt) &&
          !_onBreakBefore(status, schedule.breakAt) &&
          (status.isCheckedIn || status.isOnBreak),
    );

    final endedAt = schedule.breakEndedAt;
    final longerAt = schedule.longerBreakAt;
    if (endedAt != null) {
      await logIfDue(
        ReminderType.breakTimeEnded,
        endedAt,
        _onBreakAt(status, endedAt),
      );
    }
    if (longerAt != null) {
      await logIfDue(
        ReminderType.longerBreak,
        longerAt,
        _onBreakAt(status, longerAt),
      );
    }

    final longAt = schedule.veryLongAttendanceAt;
    if (longAt != null) {
      await logIfDue(
        ReminderType.veryLongAttendance,
        longAt,
        _stayedThrough(status, longAt),
      );
    }

    return dao.loadLogs(userId: userId, date: day);
  }

  /// Still on break, or ended at/after this clock — the notice should stick.
  static bool _onBreakAt(ReminderClockStatus status, DateTime? fireAt) {
    if (fireAt == null || status.breakStart == null) return false;
    if (status.breakStart!.isAfter(fireAt)) return false;
    final ended = status.breakEnd;
    return ended == null || !ended.isBefore(fireAt);
  }

  /// Already on a break that started before this clock. A finished earlier
  /// break does not consume the take-break reminder.
  static bool _onBreakBefore(ReminderClockStatus status, DateTime fireAt) {
    if (status.breakStart == null) return false;
    if (!status.breakStart!.isBefore(fireAt)) return false;
    final ended = status.breakEnd;
    return ended == null || !ended.isBefore(fireAt);
  }

  /// Still checked in, or left at/after this clock — they were here long enough.
  static bool _stayedThrough(ReminderClockStatus status, DateTime fireAt) {
    if (status.firstCheckIn == null) return false;
    if (status.isCheckedIn) return true;
    final left = status.lastCheckOut;
    return left != null && !left.isBefore(fireAt);
  }

  static Future<void> _pruneInvalidLogs({
    required ReminderDao dao,
    required String userId,
    required DateTime day,
    required DateTime now,
    required ReminderClockStatus status,
    required ReminderFireSchedule schedule,
  }) async {
    final stale = <ReminderType>{};

    if (status.hasNotStarted) {
      stale.addAll(_statusDependentTypes);
    } else if (!status.isCheckedIn) {
      stale.add(ReminderType.breakTime);
      if (status.lastCheckOut == null) {
        stale.add(ReminderType.checkOut);
        stale.add(ReminderType.checkOutMissed);
      } else {
        if (!status.lastCheckOut!.isAfter(schedule.checkOutAt)) {
          stale.add(ReminderType.checkOut);
        }
        if (!status.lastCheckOut!.isAfter(schedule.checkOutMissedAt)) {
          stale.add(ReminderType.checkOutMissed);
        }
      }
    }
    final startedAt = status.firstCheckIn;
    if (startedAt != null) {
      if (schedule.breakAt.isBefore(startedAt)) {
        stale.add(ReminderType.breakTime);
      }
      if (schedule.checkOutAt.isBefore(startedAt)) {
        stale.add(ReminderType.checkOut);
      }
      if (schedule.checkOutMissedAt.isBefore(startedAt)) {
        stale.add(ReminderType.checkOutMissed);
      }
    }
    if (!_onBreakAt(status, schedule.breakEndedAt)) {
      stale.add(ReminderType.breakTimeEnded);
    }
    if (!_onBreakAt(status, schedule.longerBreakAt)) {
      stale.add(ReminderType.longerBreak);
    }
    final longAt = schedule.veryLongAttendanceAt;
    final reachedLongAttendance =
        longAt != null &&
        !longAt.isAfter(now) &&
        _stayedThrough(status, longAt);
    if (!reachedLongAttendance) {
      stale.add(ReminderType.veryLongAttendance);
    }

    if (stale.isEmpty) return;

    // Keep notices that already fired, except reminders that landed before
    // the employee actually checked in (break/checkout catch-up on punch-in).
    final existing = await dao.loadLogs(userId: userId, date: day);
    for (final log in existing) {
      if (log.firedAt.isAfter(now)) continue;
      if (status.firstCheckIn != null &&
          _statusDependentTypes.contains(log.type) &&
          log.firedAt.isBefore(status.firstCheckIn!)) {
        continue;
      }
      stale.remove(log.type);
    }
    if (stale.isEmpty) return;
    await dao.deleteLogsOfTypes(userId: userId, date: day, types: stale);
  }

  static List<ReminderLog> logsFor(
    ReminderPunchKind kind,
    List<ReminderLog> logs,
  ) {
    final matched = logs.where((log) => log.anchor == kind).toList()
      ..sort((a, b) => b.firedAt.compareTo(a.firedAt));
    return matched;
  }

  /// Notifications whose punch card is missing — still shown on the timeline.
  static List<ReminderLog> unattachedLogs(
    Set<ReminderPunchKind> presentKinds,
    List<ReminderLog> logs, {
    List<DateTime> punchTimes = const [],
    List<ReminderPunchKind?> primaryKinds = const [],
  }) {
    final unmatched = logs.where((log) {
      if (log.type == ReminderType.breakTimeEnded) {
        return !_breakEndCardCovers(
          log,
          punchTimes: punchTimes,
          primaryKinds: primaryKinds,
        );
      }
      if (log.type == ReminderType.breakTime) {
        return !_breakStartCardCovers(
          log,
          punchTimes: punchTimes,
          primaryKinds: primaryKinds,
        );
      }
      return !presentKinds.contains(log.anchor);
    }).toList()..sort((a, b) => b.firedAt.compareTo(a.firedAt));
    return unmatched;
  }

  /// Only a break-end punch at/after the reminder belongs to this notice.
  /// An earlier finished break must not hide a later "break time is over" row.
  static bool _breakEndCardCovers(
    ReminderLog log, {
    required List<DateTime> punchTimes,
    required List<ReminderPunchKind?> primaryKinds,
  }) {
    return _cardCovers(
      log,
      kind: ReminderPunchKind.breakEnd,
      punchTimes: punchTimes,
      primaryKinds: primaryKinds,
    );
  }

  /// Only a break-start punch at/after the reminder belongs to this notice.
  /// An earlier finished break must not hide a later "break time" row.
  static bool _breakStartCardCovers(
    ReminderLog log, {
    required List<DateTime> punchTimes,
    required List<ReminderPunchKind?> primaryKinds,
  }) {
    return _cardCovers(
      log,
      kind: ReminderPunchKind.breakStart,
      punchTimes: punchTimes,
      primaryKinds: primaryKinds,
    );
  }

  static bool _cardCovers(
    ReminderLog log, {
    required ReminderPunchKind kind,
    required List<DateTime> punchTimes,
    required List<ReminderPunchKind?> primaryKinds,
  }) {
    final count = punchTimes.length < primaryKinds.length
        ? punchTimes.length
        : primaryKinds.length;
    for (var i = 0; i < count; i++) {
      if (primaryKinds[i] != kind) continue;
      if (!punchTimes[i].isBefore(log.firedAt)) return true;
    }
    return false;
  }

  static List<ReminderLog> _logsUnderPunch({
    required ReminderPunchKind kind,
    required DateTime punchTime,
    required List<ReminderLog> logs,
  }) {
    final attached = logsFor(kind, logs);
    return [
      for (final log in attached)
        if (!_timedBreakLog(log) || !punchTime.isBefore(log.firedAt)) log,
    ];
  }

  static bool _timedBreakLog(ReminderLog log) {
    return log.type == ReminderType.breakTime ||
        log.type == ReminderType.breakTimeEnded;
  }

  /// Screenshot layout: alerts whose punch card is missing sit in one group
  /// above the cards (Check Out / Break / 12h). Matching alerts stay under
  /// their card (Check In alerts under the Check-In card).
  static List<ReminderTimelineItem> mixTimeline({
    required List<DateTime> punchTimes,
    required List<ReminderPunchKind?> primaryKinds,
    required List<ReminderLog> logs,
    bool newestFirst = true,
  }) {
    assert(punchTimes.length == primaryKinds.length);

    final present = <ReminderPunchKind>{
      for (final kind in primaryKinds)
        if (kind != null) kind,
    };
    final missingCardAlerts = unattachedLogs(
      present,
      logs,
      punchTimes: punchTimes,
      primaryKinds: primaryKinds,
    );

    final items =
        [
          if (missingCardAlerts.isNotEmpty)
            ReminderTimelineItem.reminders(
              time: missingCardAlerts
                  .map((log) => log.firedAt)
                  .reduce((a, b) => a.isAfter(b) ? a : b),
              standaloneLogs: missingCardAlerts,
            ),
          for (var i = 0; i < punchTimes.length; i++)
            ReminderTimelineItem.punch(
              punchIndex: i,
              time: punchTimes[i],
              attachedLogs: primaryKinds[i] == null
                  ? const []
                  : _logsUnderPunch(
                      kind: primaryKinds[i]!,
                      punchTime: punchTimes[i],
                      logs: logs,
                    ),
            ),
        ]..sort((a, b) {
          final byTime = newestFirst
              ? b.time.compareTo(a.time)
              : a.time.compareTo(b.time);
          if (byTime != 0) return byTime;
          if (a.isPunch != b.isPunch) return a.isPunch ? -1 : 1;
          return 0;
        });
    return items;
  }
}

class ReminderTimelineItem {
  const ReminderTimelineItem.punch({
    required this.punchIndex,
    required this.time,
    required this.attachedLogs,
  }) : standaloneLogs = const [];

  const ReminderTimelineItem.reminders({
    required this.time,
    required this.standaloneLogs,
  }) : punchIndex = null,
       attachedLogs = const [];

  final int? punchIndex;
  final DateTime time;
  final List<ReminderLog> attachedLogs;
  final List<ReminderLog> standaloneLogs;

  bool get isPunch => punchIndex != null;
}
