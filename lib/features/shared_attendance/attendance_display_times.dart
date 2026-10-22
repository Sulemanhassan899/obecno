/// Single display rule for Clock + Attendance headers.
///
/// - Check-in: always the day's first check-in (does not jump on re-check-in).
/// - Check-out: hidden while the day is still open (checked in / on break);
///   otherwise the latest checkout.
class AttendanceDisplayTimes {
  AttendanceDisplayTimes._();

  static DateTime? displayCheckIn({required DateTime? firstCheckIn}) =>
      firstCheckIn;

  static DateTime? displayCheckOut({
    required bool dayStillOpen,
    required DateTime? lastCheckOut,
  }) {
    if (dayStillOpen) return null;
    return lastCheckOut;
  }
}
