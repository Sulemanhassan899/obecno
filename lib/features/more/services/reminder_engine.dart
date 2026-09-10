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
    required int graceMinutes,
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
    final schedule = ReminderFireSchedule.forDay(
      day: day,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      policyCheckInTime: policyIn,
      policyCheckOutTime: policyOut,
      breakReminderTime: breakAtTime,
      breakEndedReminderTime: breakEndedReminderTime,
      graceMinutes: graceMinutes,
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
            breakTime: breakReminderTime,
            breakEndTime: breakEndedReminderTime,
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
          ((status.isCheckedIn && status.breakStart == null) ||
              (status.breakStart != null &&
                  status.breakStart!.isAfter(schedule.breakAt))),
    );

    final endedAt = schedule.breakEndedAt;
    final longerAt = schedule.longerBreakAt;
    if (endedAt != null) {
      await logIfDue(
        ReminderType.breakTimeEnded,
        endedAt,
        status.isOnBreak ||
            (status.breakEnd != null && status.breakEnd!.isAfter(endedAt)),
      );
    }
    if (longerAt != null) {
      await logIfDue(
        ReminderType.longerBreak,
        longerAt,
        status.isOnBreak ||
            (status.breakEnd != null && status.breakEnd!.isAfter(longerAt)),
      );
    }

    final longAt = schedule.veryLongAttendanceAt;
    if (longAt != null) {
      await logIfDue(
        ReminderType.veryLongAttendance,
        longAt,
        status.isCheckedIn,
      );
    }

    return dao.loadLogs(userId: userId, date: day);
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
    if (!status.isOnBreak) {
      if (status.breakEnd == null ||
          schedule.breakEndedAt == null ||
          !status.breakEnd!.isAfter(schedule.breakEndedAt!)) {
        stale.add(ReminderType.breakTimeEnded);
      }
      if (status.breakEnd == null ||
          schedule.longerBreakAt == null ||
          !status.breakEnd!.isAfter(schedule.longerBreakAt!)) {
        stale.add(ReminderType.longerBreak);
      }
    }
    final longAt = schedule.veryLongAttendanceAt;
    final reachedTwelveHoursWhileCheckedIn =
        status.isCheckedIn && longAt != null && !longAt.isAfter(now);
    if (!reachedTwelveHoursWhileCheckedIn) {
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
    List<ReminderLog> logs,
  ) {
    final unmatched = logs
        .where((log) => !presentKinds.contains(log.anchor))
        .toList()
      ..sort((a, b) => b.firedAt.compareTo(a.firedAt));
    return unmatched;
  }

  /// Screenshot layout: alerts whose punch card is missing sit in one group
  /// above the cards (Check Out / Break / 12h). Matching alerts stay under
  /// their card (Check In alerts under the Check-In card).
  static List<ReminderTimelineItem> mixTimeline({
    required List<DateTime> punchTimes,
    required List<ReminderPunchKind?> primaryKinds,
    required List<ReminderLog> logs,
  }) {
    assert(punchTimes.length == primaryKinds.length);

    final present = <ReminderPunchKind>{
      for (final kind in primaryKinds)
        if (kind != null) kind,
    };
    final missingCardAlerts = unattachedLogs(present, logs);

    return [
      if (missingCardAlerts.isNotEmpty)
        ReminderTimelineItem.reminders(
          time: missingCardAlerts.first.firedAt,
          standaloneLogs: missingCardAlerts,
        ),
      for (var i = 0; i < punchTimes.length; i++)
        ReminderTimelineItem.punch(
          punchIndex: i,
          time: punchTimes[i],
          attachedLogs: primaryKinds[i] == null
              ? const []
              : logsFor(primaryKinds[i]!, logs),
        ),
    ];
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
