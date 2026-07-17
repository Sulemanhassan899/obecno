

class ApiEndpoints {
  ApiEndpoints._();

  // ---------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------
  static const String login = '/api/auth/login';
  static const String logout = '/api/auth/logout';
  static const String currentUser = '/api/auth/me';
  static const String forgot = '/api/auth/forgot-password';
  static const String changePassword = '/api/auth/change-password';

  // ---------------------------------------------------------------------
  // Attendance / Clock module
  // ---------------------------------------------------------------------
  static const String attendance = "/api/employee/attendance";

  // 🔥 NEW — only addition in this file, everything else is untouched.
  static const String attendanceCalendar = "/api/employee/calendar";

  static String monthlyAttendance(String employeeId, String yearMonth) =>
      '/attendance/monthly/$employeeId/$yearMonth';

  static String attendanceSummary(String employeeId) =>
      '/attendance/summary/$employeeId';

  // ---------------------------------------------------------------------
  // Employee
  // ---------------------------------------------------------------------
  static const String employeeProfile = '/api/employee/profile';
  static const String employeeProfilePhoto = '/api/employee/profile/photo';

  // ---------------------------------------------------------------------
  // Tickets (Ansupport) — 🔥 NEW
  // ---------------------------------------------------------------------
  static const String tickets = '/api/employee/tickets';
  static const String ticketShow = '/api/employee/tickets/show';
  static const String ticketsMeta = '/api/employee/tickets/meta';
  static const String ticketReply = '/api/employee/tickets/reply';

  // ---------------------------------------------------------------------
  // Query param helpers
  // ---------------------------------------------------------------------
  static Map<String, dynamic> pagination({int page = 1, int pageSize = 20}) => {
    'page': page,
    'pageSize': pageSize,
  };
}
