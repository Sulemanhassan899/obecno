/// Every network path the app calls, in one place. Screens/repositories
/// must never hardcode a path string — always reference this file so a
/// backend route change means editing exactly one line.
class ApiEndpoints {
  ApiEndpoints._();

  // ---------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------
  static const String login = '/api/auth/login';
  static const String logout = '/auth/logout';
  static const String currentUser = '/auth/me';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // NEW — required by the auth module integration.
  /// Step 1 of login: checks the email/phone/ID exists, before password entry.
  static const String loginIdentifierCheck = '/auth/login/check';
  /// Verifies the OTP sent during the forgot-password flow.
  static const String verifyOtp = '/auth/verify-otp';

  // ---------------------------------------------------------------------
  // Attendance / Clock module
  // ---------------------------------------------------------------------
  static const String clockIn = '/attendance/clock-in';
  static const String clockOut = '/attendance/clock-out';
  static const String startBreak = '/attendance/break/start';
  static const String endBreak = '/attendance/break/end';
  static const String todayStatus = '/attendance/today';
  static const String attendanceEvents = '/attendance/events';

  static String monthlyAttendance(String employeeId, String yearMonth) =>
      '/attendance/monthly/$employeeId/$yearMonth';

  static String attendanceSummary(String employeeId) => '/attendance/summary/$employeeId';

  static const String manualAttendanceEntry = '/attendance/manual';

  // ---------------------------------------------------------------------
  // Employee
  // ---------------------------------------------------------------------
  static const String employees = '/employees';
  static String employeeById(String id) => '/employees/$id';
  static const String employeeProfile = '/employees/profile';

  // ---------------------------------------------------------------------
  // Query param helpers
  // ---------------------------------------------------------------------
  static Map<String, dynamic> pagination({int page = 1, int pageSize = 20}) => {
        'page': page,
        'pageSize': pageSize,
      };
}
