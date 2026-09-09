import 'package:flutter/material.dart';

import 'package:obecno/features/more/data/models/reminder_log.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';

class ScheduledReminderNotification {
  const ScheduledReminderNotification({
    required this.id,
    required this.type,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.deliverImmediately,
  });

  final int id;
  final ReminderType type;
  final DateTime fireAt;
  final String title;
  final String body;
  final bool deliverImmediately;
}

class ReminderNotificationSyncResult {
  const ReminderNotificationSyncResult({
    required this.planned,
    required this.seenTypes,
  });

  final List<ScheduledReminderNotification> planned;
  final Set<ReminderType> seenTypes;
}

/// When each reminder should actually notify — never the policy/permission time
/// unless that is also the time the user chose.
class ReminderFireSchedule {
  const ReminderFireSchedule({
    required this.checkInAt,
    required this.checkInMissedAt,
    required this.checkOutAt,
    required this.checkOutMissedAt,
    required this.breakAt,
    this.breakEndedAt,
    this.longerBreakAt,
    this.veryLongAttendanceAt,
  });

  final DateTime checkInAt;
  final DateTime checkInMissedAt;
  final DateTime checkOutAt;
  final DateTime checkOutMissedAt;
  final DateTime breakAt;
  final DateTime? breakEndedAt;
  final DateTime? longerBreakAt;
  final DateTime? veryLongAttendanceAt;

  static ReminderFireSchedule forDay({
    required DateTime day,
    required TimeOfDay checkInTime,
    required TimeOfDay checkOutTime,
    required TimeOfDay policyCheckInTime,
    required TimeOfDay policyCheckOutTime,
    required TimeOfDay breakReminderTime,
    TimeOfDay? breakEndedReminderTime,
    required int graceMinutes,
    required int breakMinutes,
    required int longAttendanceHours,
    required ReminderClockStatus status,
  }) {
    DateTime at(TimeOfDay time) =>
        DateTime(day.year, day.month, day.day, time.hour, time.minute);
    final grace = Duration(minutes: graceMinutes < 0 ? 0 : graceMinutes);
    final hours = longAttendanceHours <= 0 ? 12 : longAttendanceHours;
    final minutes = breakMinutes <= 0 ? 60 : breakMinutes;

    DateTime? breakEndedAt;
    DateTime? longerBreakAt;
    if (status.breakStart != null) {
      final breakDue = status.breakStart!.add(Duration(minutes: minutes));
      longerBreakAt = breakDue.add(ReminderNotificationPlan.longerBreakAfter);
      if (breakEndedReminderTime != null) {
        var endedAt = at(breakEndedReminderTime);
        if (endedAt.isBefore(status.breakStart!) || endedAt.isAfter(breakDue)) {
          endedAt = breakDue;
        }
        breakEndedAt = endedAt;
      } else {
        breakEndedAt = breakDue;
      }
    }

    return ReminderFireSchedule(
      checkInAt: at(checkInTime),
      checkInMissedAt: at(checkInTime).add(grace),
      checkOutAt: at(checkOutTime),
      checkOutMissedAt: at(checkOutTime).add(grace),
      breakAt: at(breakReminderTime),
      breakEndedAt: breakEndedAt,
      longerBreakAt: longerBreakAt,
      veryLongAttendanceAt: status.firstCheckIn?.add(Duration(hours: hours)),
    );
  }
}

/// Builds OS notifications for every enabled reminder that is due or upcoming.
class ReminderNotificationPlan {
  ReminderNotificationPlan._();

  static const notificationIdBase = 7400;
  static const defaultWorkingWeekdays = {1, 2, 3, 4, 5};
  static const longerBreakAfter = Duration(hours: 1);

  static int idFor(ReminderType type, {int dayOffset = 0, int slot = 0}) =>
      notificationIdBase + type.index * 10 + dayOffset + slot;

  static ReminderType? typeForId(int id) {
    final raw = id - notificationIdBase;
    if (raw < 0) return null;
    final index = raw ~/ 10;
    if (index < 0 || index >= ReminderType.values.length) return null;
    return ReminderType.values[index];
  }

  /// Delivered banners stay until the user swipes them away.
  static Set<int> persistentIds({
    required Set<ReminderType> alreadyFired,
    required Iterable<int> activeIds,
  }) {
    return {for (final type in alreadyFired) idFor(type), ...activeIds};
  }

  static bool shouldShowNow({
    required ReminderType type,
    required int id,
    required Set<ReminderType> alreadyFired,
    required Iterable<int> activeIds,
  }) {
    if (activeIds.contains(id)) return false;
    if (alreadyFired.contains(type) && id == idFor(type)) return false;
    return true;
  }

  static DateTime at(DateTime day, TimeOfDay time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  /// Device clock in the same minute as [fireAt] is on time, not a late catch-up.
  static bool isOnReminderMinute(DateTime fireAt, DateTime now) {
    return fireAt.year == now.year &&
        fireAt.month == now.month &&
        fireAt.day == now.day &&
        fireAt.hour == now.hour &&
        fireAt.minute == now.minute;
  }

  static int minutesOf(TimeOfDay time) => time.hour * 60 + time.minute;

  static TimeOfDay timeFromMinutes(int minutes) {
    final wrapped = minutes.clamp(0, 23 * 60 + 59);
    return TimeOfDay(hour: wrapped ~/ 60, minute: wrapped % 60);
  }

  static TimeOfDay defaultBreakReminderTime({
    required TimeOfDay checkInTime,
    required TimeOfDay checkOutTime,
  }) {
    final mid = (minutesOf(checkInTime) + minutesOf(checkOutTime)) ~/ 2;
    return timeFromMinutes(mid - 5);
  }

  static TimeOfDay defaultBreakEndedReminderTime({
    required TimeOfDay checkInTime,
    required TimeOfDay checkOutTime,
    required int breakMinutes,
  }) {
    final start = defaultBreakReminderTime(
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
    );
    final minutes = breakMinutes <= 0 ? 60 : breakMinutes;
    return timeFromMinutes(minutesOf(start) + 5 + minutes);
  }

  static List<ScheduledReminderNotification> build({
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
    Set<int> workingWeekdays = defaultWorkingWeekdays,
    Set<ReminderType> alreadyFired = const {},
    String locationName = 'work',
    bool allowCatchUp = false,
  }) {
    final items = <ScheduledReminderNotification>[];
    final grace = Duration(minutes: graceMinutes < 0 ? 0 : graceMinutes);
    final weekdays = workingWeekdays.isEmpty
        ? defaultWorkingWeekdays
        : workingWeekdays;
    final place = locationName.trim().isEmpty ? 'work' : locationName.trim();

    final policyIn = policyCheckInTime ?? checkInTime;
    final policyOut = policyCheckOutTime ?? checkOutTime;
    final policyBreak = defaultBreakReminderTime(
      checkInTime: policyIn,
      checkOutTime: policyOut,
    );
    final policyBreakEnded = defaultBreakEndedReminderTime(
      checkInTime: policyIn,
      checkOutTime: policyOut,
      breakMinutes: breakMinutes,
    );
    final breakAtTime = breakReminderTime ?? policyBreak;
    final breakEndedAtTime = breakEndedReminderTime ?? policyBreakEnded;

    void add(
      ReminderType type,
      DateTime fireAt, {
      required bool applicable,
      int dayOffset = 0,
    }) {
      if (!applicable) return;
      if (!(enabled[type] ?? false)) return;
      final onMinute = isOnReminderMinute(fireAt, now);
      if (fireAt.isBefore(now) && !onMinute && !allowCatchUp) return;
      final dueNow = onMinute || !fireAt.isAfter(now);
      if (dayOffset == 0 && alreadyFired.contains(type) && dueNow) return;
      items.add(
        ScheduledReminderNotification(
          id: idFor(type, dayOffset: dayOffset),
          type: type,
          fireAt: fireAt,
          title: ReminderCopy.title(type, locationName: place),
          body: ReminderCopy.message(
            type,
            checkInTime: checkInTime,
            checkOutTime: checkOutTime,
            breakTime: breakAtTime,
            breakEndTime: breakEndedAtTime,
          ),
          deliverImmediately: dueNow,
        ),
      );
    }

    final status = ReminderClockStatus.fromPunches(punches);
    final today = DateTime(now.year, now.month, now.day);
    final todaySchedule = ReminderFireSchedule.forDay(
      day: today,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      policyCheckInTime: policyIn,
      policyCheckOutTime: policyOut,
      breakReminderTime: breakAtTime,
      breakEndedReminderTime: breakEndedAtTime,
      graceMinutes: graceMinutes,
      breakMinutes: breakMinutes,
      longAttendanceHours: longAttendanceHours,
      status: status,
    );

    final days = [today, today.add(const Duration(days: 1))];
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      if (!weekdays.contains(day.weekday)) continue;
      final notStartedToday = i == 0 ? status.hasNotStarted : true;
      add(
        ReminderType.checkIn,
        at(day, checkInTime),
        applicable: notStartedToday,
        dayOffset: i,
      );
      add(
        ReminderType.checkInMissed,
        at(day, checkInTime).add(grace),
        applicable: notStartedToday,
        dayOffset: i,
      );
    }

    add(
      ReminderType.checkOut,
      todaySchedule.checkOutAt,
      applicable: status.isCheckedIn,
    );
    add(
      ReminderType.checkOutMissed,
      todaySchedule.checkOutMissedAt,
      applicable: status.isCheckedIn,
    );

    final longAt = todaySchedule.veryLongAttendanceAt;
    add(
      ReminderType.veryLongAttendance,
      longAt ?? now,
      applicable: status.isCheckedIn && longAt != null,
    );

    add(
      ReminderType.breakTime,
      todaySchedule.breakAt,
      applicable: status.isCheckedIn && status.breakStart == null,
    );

    final endedAt = todaySchedule.breakEndedAt;
    final longerAt = todaySchedule.longerBreakAt;
    add(
      ReminderType.breakTimeEnded,
      endedAt ?? now,
      applicable: status.isOnBreak && endedAt != null,
    );
    add(
      ReminderType.longerBreak,
      longerAt ?? now,
      applicable: status.isOnBreak && longerAt != null,
    );

    return items;
  }

  static Iterable<int> allIds() sync* {
    for (final type in ReminderType.values) {
      for (final offset in const [0, 1]) {
        for (final slot in const [0, 5]) {
          yield idFor(type, dayOffset: offset, slot: slot);
        }
      }
    }
  }
}
