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
      status.isCheckedIn ||
          (status.lastCheckOut != null &&
              status.lastCheckOut!.isAfter(schedule.checkOutAt)),
    );
    await logIfDue(
      ReminderType.checkOutMissed,
      schedule.checkOutMissedAt,
      status.isCheckedIn ||
          (status.lastCheckOut != null &&
              status.lastCheckOut!.isAfter(schedule.checkOutMissedAt)),
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
      (status.isCheckedIn && status.breakStart == null) ||
          (status.breakStart != null &&
              status.breakStart!.isAfter(schedule.breakAt)),
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
}
