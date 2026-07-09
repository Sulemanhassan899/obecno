/// Shared app-wide enums.

/// Result of a password-strength check performed by [Validators.passwordStrength].
enum PasswordStrength { weak, medium, strong }

/// Generic granted/denied/unknown result used by [PermissionHelper].
enum AppPermissionStatus { granted, denied, permanentlyDenied, unknown }

enum AttendanceDayStatus {
  checkedOut, // initial → Check In
  checkedIn, // → Check Out OR Break
  onBreak, // → End Break
  endedBreak, // → Check Out
  outofRange, // override
  lateCheckIn,
  absent,
  normal,
  missingCheckOut,
  manuallyEdited,
  weekend,
}
