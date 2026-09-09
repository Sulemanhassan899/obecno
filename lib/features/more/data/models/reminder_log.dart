import 'package:flutter/material.dart';

import 'package:obecno/features/more/data/models/reminder_type.dart';

enum ReminderPunchKind {
  checkIn,
  checkOut,
  breakStart,
  breakEnd;

  static ReminderPunchKind? fromName(String name) {
    switch (name) {
      case 'checkIn':
        return ReminderPunchKind.checkIn;
      case 'checkOut':
        return ReminderPunchKind.checkOut;
      case 'breakStart':
        return ReminderPunchKind.breakStart;
      case 'breakEnd':
        return ReminderPunchKind.breakEnd;
      default:
        return null;
    }
  }
}

class ReminderPunch {
  const ReminderPunch({required this.kind, required this.time});

  final ReminderPunchKind kind;
  final DateTime time;
}

/// Live clock-button state derived from today's punches.
class ReminderClockStatus {
  const ReminderClockStatus({
    required this.firstCheckIn,
    required this.lastCheckOut,
    required this.breakStart,
    required this.breakEnd,
    required this.isCheckedIn,
    required this.isOnBreak,
  });

  static const empty = ReminderClockStatus(
    firstCheckIn: null,
    lastCheckOut: null,
    breakStart: null,
    breakEnd: null,
    isCheckedIn: false,
    isOnBreak: false,
  );

  final DateTime? firstCheckIn;
  final DateTime? lastCheckOut;
  final DateTime? breakStart;
  final DateTime? breakEnd;
  final bool isCheckedIn;
  final bool isOnBreak;

  bool get hasNotStarted => firstCheckIn == null;

  bool get isCurrentlyCheckedOut =>
      firstCheckIn != null && !isCheckedIn && !isOnBreak;

  String get storageValue {
    if (hasNotStarted) return 'not_started';
    if (isOnBreak) return 'on_break';
    if (isCheckedIn) return 'checked_in';
    return 'checked_out';
  }

  static ReminderClockStatus fromPunches(List<ReminderPunch> punches) {
    final sorted = [...punches]..sort((a, b) => a.time.compareTo(b.time));
    DateTime? firstCheckIn;
    DateTime? lastCheckOut;
    DateTime? breakStart;
    DateTime? breakEnd;
    var isCheckedIn = false;
    var isOnBreak = false;
    for (final punch in sorted) {
      switch (punch.kind) {
        case ReminderPunchKind.checkIn:
          firstCheckIn ??= punch.time;
          isCheckedIn = true;
          isOnBreak = false;
          break;
        case ReminderPunchKind.checkOut:
          lastCheckOut = punch.time;
          isCheckedIn = false;
          isOnBreak = false;
          break;
        case ReminderPunchKind.breakStart:
          breakStart ??= punch.time;
          isOnBreak = true;
          break;
        case ReminderPunchKind.breakEnd:
          breakEnd = punch.time;
          isOnBreak = false;
          break;
      }
    }
    return ReminderClockStatus(
      firstCheckIn: firstCheckIn,
      lastCheckOut: lastCheckOut,
      breakStart: breakStart,
      breakEnd: breakEnd,
      isCheckedIn: isCheckedIn,
      isOnBreak: isOnBreak,
    );
  }
}

class ReminderLog {
  const ReminderLog({
    required this.type,
    required this.firedAt,
    required this.title,
    required this.message,
    this.clockStatus,
    this.deliveredAt,
    this.synced = false,
  });

  final ReminderType type;
  final DateTime firedAt;
  final String title;
  final String message;
  final String? clockStatus;
  final DateTime? deliveredAt;
  final bool synced;

  String get timelineLabel {
    switch (type) {
      case ReminderType.enterLocation:
        return 'Enter office/location';
      case ReminderType.leaveLocation:
        return 'Leave office/location';
      case ReminderType.checkIn:
        return 'Check In';
      case ReminderType.checkInMissed:
        return 'Check In Missed';
      case ReminderType.checkOut:
        return 'Check Out';
      case ReminderType.checkOutMissed:
        return 'Check Out Missed';
      case ReminderType.breakTime:
        return 'Break time';
      case ReminderType.breakTimeEnded:
        return 'Break time ended';
      case ReminderType.longerBreak:
        return 'Longer break';
      case ReminderType.veryLongAttendance:
        return 'Checked in for 12 hours.';
    }
  }

  bool get showSparkle {
    switch (type) {
      case ReminderType.enterLocation:
      case ReminderType.leaveLocation:
      case ReminderType.veryLongAttendance:
        return true;
      default:
        return false;
    }
  }

  ReminderPunchKind get anchor {
    switch (type) {
      case ReminderType.enterLocation:
      case ReminderType.checkIn:
      case ReminderType.checkInMissed:
        return ReminderPunchKind.checkIn;
      case ReminderType.leaveLocation:
      case ReminderType.checkOut:
      case ReminderType.checkOutMissed:
      case ReminderType.veryLongAttendance:
        return ReminderPunchKind.checkOut;
      case ReminderType.breakTime:
        return ReminderPunchKind.breakStart;
      case ReminderType.breakTimeEnded:
      case ReminderType.longerBreak:
        return ReminderPunchKind.breakEnd;
    }
  }
}

class ReminderCopy {
  ReminderCopy._();

  static String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.period == DayPeriod.pm ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $ampm';
  }

  static String title(ReminderType type, {String locationName = 'work'}) {
    switch (type) {
      case ReminderType.enterLocation:
        return "You're at $locationName";
      case ReminderType.leaveLocation:
        return 'Leaving work?';
      case ReminderType.checkIn:
        return 'Time to check in';
      case ReminderType.checkInMissed:
        return 'Missed your check-in?';
      case ReminderType.checkOut:
        return 'Time to check out';
      case ReminderType.checkOutMissed:
        return 'Still checked in?';
      case ReminderType.breakTime:
        return 'Break coming up';
      case ReminderType.breakTimeEnded:
        return 'Break time is over';
      case ReminderType.longerBreak:
        return 'Break ending soon';
      case ReminderType.veryLongAttendance:
        return 'Still working?';
    }
  }

  static String message(
    ReminderType type, {
    TimeOfDay? checkInTime,
    TimeOfDay? checkOutTime,
    TimeOfDay? breakTime,
    TimeOfDay? breakEndTime,
  }) {
    switch (type) {
      case ReminderType.enterLocation:
        return "Don't forget to check in.";
      case ReminderType.leaveLocation:
        return "You're still checked in.";
      case ReminderType.checkIn:
        return 'Ready to start your day?';
      case ReminderType.checkInMissed:
        return "Check in now if you've started work.";
      case ReminderType.checkOut:
        return 'Wrapping up for today?';
      case ReminderType.checkOutMissed:
        return "Check out if you've finished work.";
      case ReminderType.breakTime:
        return 'Your break starts in 5 minutes.';
      case ReminderType.breakTimeEnded:
        return 'Ready to get back to work?';
      case ReminderType.longerBreak:
        return 'Back to work in 10 minutes.';
      case ReminderType.veryLongAttendance:
        return "You've been checked in for 12 hours.";
    }
  }
}
