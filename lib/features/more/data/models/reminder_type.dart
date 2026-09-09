enum ReminderType {
  enterLocation,
  leaveLocation,
  checkIn,
  checkInMissed,
  checkOut,
  checkOutMissed,
  breakTime,
  breakTimeEnded,
  longerBreak,
  veryLongAttendance;

  String get storageKey {
    switch (this) {
      case ReminderType.enterLocation:
        return 'enter_location';
      case ReminderType.leaveLocation:
        return 'leave_location';
      case ReminderType.checkIn:
        return 'check_in';
      case ReminderType.checkInMissed:
        return 'check_in_missed';
      case ReminderType.checkOut:
        return 'check_out';
      case ReminderType.checkOutMissed:
        return 'check_out_missed';
      case ReminderType.breakTime:
        return 'break_time';
      case ReminderType.breakTimeEnded:
        return 'break_time_ended';
      case ReminderType.longerBreak:
        return 'longer_break';
      case ReminderType.veryLongAttendance:
        return 'very_long_attendance';
    }
  }

  static ReminderType? fromStorageKey(String key) {
    for (final type in ReminderType.values) {
      if (type.storageKey == key) return type;
    }
    return null;
  }

  bool get canPickEarlierTime {
    switch (this) {
      case ReminderType.checkIn:
      case ReminderType.checkOut:
      case ReminderType.breakTime:
      case ReminderType.breakTimeEnded:
        return true;
      default:
        return false;
    }
  }
}
