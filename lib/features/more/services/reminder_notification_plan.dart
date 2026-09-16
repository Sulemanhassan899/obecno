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
///
/// Check-in missed / check-out missed fire at a chosen clock, defaulting to
/// the related reminder plus [graceMinutes].
/// Longer break adds [longerBreakAfter] to the chosen (or due) break-end.
/// Very long attendance adds the chosen duration to the actual check-in punch.
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
    TimeOfDay? checkInMissedTime,
    TimeOfDay? checkOutMissedTime,
    required int graceMinutes,
    int? checkInMissedMinutes,
    int? checkOutMissedMinutes,
    int? longerBreakMinutes,
    required int breakMinutes,
    required int longAttendanceHours,
    required ReminderClockStatus status,
  }) {
    DateTime at(TimeOfDay time) => ReminderNotificationPlan.at(day, time);
    final grace = Duration(minutes: graceMinutes < 0 ? 0 : graceMinutes);
    final inMissed = Duration(minutes: checkInMissedMinutes ?? grace.inMinutes);
    final outMissed = Duration(
      minutes: checkOutMissedMinutes ?? grace.inMinutes,
    );
    final longerAfter = Duration(
      minutes:
          longerBreakMinutes ??
          ReminderNotificationPlan.longerBreakAfter.inMinutes,
    );
    final attendanceMinutes = ReminderCopy.durationMinutes(longAttendanceHours);
    final minutes = breakMinutes <= 0 ? 60 : breakMinutes;
    final overnight = ReminderNotificationPlan.isOvernightShift(
      policyCheckInTime,
      policyCheckOutTime,
    );

    final checkInAt = at(checkInTime);
    var checkOutAt = at(checkOutTime);
    if (overnight && !checkOutAt.isAfter(checkInAt)) {
      checkOutAt = checkOutAt.add(const Duration(days: 1));
    }

    DateTime place(TimeOfDay time) {
      var dt = at(time);
      if (overnight && dt.isBefore(checkInAt)) {
        dt = dt.add(const Duration(days: 1));
      }
      return dt;
    }

    DateTime? breakEndedAt;
    DateTime? longerBreakAt;
    if (status.breakStart != null) {
      final breakDue = status.breakStart!.add(Duration(minutes: minutes));
      var endedAt = breakDue;
      if (breakEndedReminderTime != null) {
        var selected = place(breakEndedReminderTime);
        if (overnight && selected.isBefore(status.breakStart!)) {
          selected = selected.add(const Duration(days: 1));
        }
        if (!selected.isBefore(status.breakStart!)) {
          endedAt = selected;
        }
      }
      breakEndedAt = endedAt;
      longerBreakAt = endedAt.add(longerAfter);
    }

    return ReminderFireSchedule(
      checkInAt: checkInAt,
      checkInMissedAt: checkInMissedTime == null
          ? checkInAt.add(inMissed)
          : ReminderNotificationPlan.clockOnOrAfter(
              checkInAt,
              checkInMissedTime,
            ),
      checkOutAt: checkOutAt,
      checkOutMissedAt: checkOutMissedTime == null
          ? checkOutAt.add(outMissed)
          : ReminderNotificationPlan.clockOnOrAfter(
              checkOutAt,
              checkOutMissedTime,
            ),
      breakAt: place(breakReminderTime),
      breakEndedAt: breakEndedAt,
      longerBreakAt: longerBreakAt,
      veryLongAttendanceAt: status.firstCheckIn?.add(
        Duration(minutes: attendanceMinutes),
      ),
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
    final day = 24 * 60;
    final wrapped = ((minutes % day) + day) % day;
    return TimeOfDay(hour: wrapped ~/ 60, minute: wrapped % 60);
  }

  static TimeOfDay addMinutes(TimeOfDay time, int minutes) =>
      timeFromMinutes(minutesOf(time) + minutes);

  /// Same calendar day as [anchor], or the next day when the clock is earlier.
  static DateTime clockOnOrAfter(DateTime anchor, TimeOfDay time) {
    var dt = DateTime(
      anchor.year,
      anchor.month,
      anchor.day,
      time.hour,
      time.minute,
    );
    if (dt.isBefore(anchor)) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }

  /// Checkout at or before check-in on the clock (9 PM–6 AM, 12 PM–12 AM).
  static bool isOvernightShift(TimeOfDay checkIn, TimeOfDay checkOut) =>
      minutesOf(checkOut) <= minutesOf(checkIn);

  static int spanMinutes(TimeOfDay start, TimeOfDay end) {
    var span = minutesOf(end) - minutesOf(start);
    if (span <= 0) span += 24 * 60;
    return span;
  }

  static TimeOfDay defaultBreakReminderTime({
    required TimeOfDay checkInTime,
    required TimeOfDay checkOutTime,
  }) {
    final mid =
        minutesOf(checkInTime) + spanMinutes(checkInTime, checkOutTime) ~/ 2;
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
    TimeOfDay? checkInMissedTime,
    TimeOfDay? checkOutMissedTime,
    required int graceMinutes,
    int? checkInMissedMinutes,
    int? checkOutMissedMinutes,
    int? longerBreakMinutes,
    required int breakMinutes,
    required int longAttendanceHours,
    required List<ReminderPunch> punches,
    Set<int> workingWeekdays = defaultWorkingWeekdays,
    Set<ReminderType> alreadyFired = const {},
    String locationName = 'work',
    bool allowCatchUp = false,
  }) {
    final items = <ScheduledReminderNotification>[];
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
      bool catchUp = false,
    }) {
      if (!applicable) return;
      if (!(enabled[type] ?? false)) return;
      final onMinute = isOnReminderMinute(fireAt, now);
      if (fireAt.isBefore(now) && !onMinute && !allowCatchUp && !catchUp) {
        return;
      }
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
            longAttendanceHours: longAttendanceHours,
          ),
          deliverImmediately: dueNow,
        ),
      );
    }

    final status = ReminderClockStatus.fromPunches(punches);
    final today = DateTime(now.year, now.month, now.day);
    ReminderFireSchedule scheduleFor(DateTime day) =>
        ReminderFireSchedule.forDay(
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
    final todaySchedule = scheduleFor(today);

    final days = [today, today.add(const Duration(days: 1))];
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      if (!weekdays.contains(day.weekday)) continue;
      final daySchedule = i == 0 ? todaySchedule : scheduleFor(day);
      final notStartedToday = i == 0 ? status.hasNotStarted : true;
      add(
        ReminderType.checkIn,
        daySchedule.checkInAt,
        applicable: notStartedToday,
        dayOffset: i,
      );
      add(
        ReminderType.checkInMissed,
        daySchedule.checkInMissedAt,
        applicable: notStartedToday,
        dayOffset: i,
      );
    }

    add(
      ReminderType.checkOut,
      todaySchedule.checkOutAt,
      applicable:
          status.isCheckedIn &&
          !todaySchedule.checkOutAt.isBefore(status.firstCheckIn!),
    );
    add(
      ReminderType.checkOutMissed,
      todaySchedule.checkOutMissedAt,
      applicable:
          status.isCheckedIn &&
          !todaySchedule.checkOutMissedAt.isBefore(status.firstCheckIn!),
    );

    final longAt = todaySchedule.veryLongAttendanceAt;
    add(
      ReminderType.veryLongAttendance,
      longAt ?? now,
      applicable: status.isCheckedIn && longAt != null,
      catchUp: true,
    );

    add(
      ReminderType.breakTime,
      todaySchedule.breakAt,
      applicable:
          status.isCheckedIn &&
          !status.isOnBreak &&
          !todaySchedule.breakAt.isBefore(status.firstCheckIn!),
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
