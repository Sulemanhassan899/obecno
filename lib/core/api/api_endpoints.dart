class ApiEndpoints {
  ApiEndpoints._();

  // ---------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String currentUser = '/auth/me';
  static const String forgot = '/auth/forgot-password';
  static const String changePassword = '/auth/change-password';

  // ---------------------------------------------------------------------
  // Attendance / Clock module
  // ---------------------------------------------------------------------
  static const String attendance = "/employee/attendance";

  static const String attendanceCalendar = "/employee/calendar";

  static String monthlyAttendance(String employeeId, String yearMonth) =>
      '/attendance/monthly/$employeeId/$yearMonth';

  static String attendanceSummary(String employeeId) =>
      '/attendance/summary/$employeeId';

  // ---------------------------------------------------------------------
  // Employee
  // ---------------------------------------------------------------------
  static const String employeeProfile = '/employee/profile';
  static const String employeeProfilePhoto = '/employee/profile/photo';
  static const String employeeDashboard = '/employee/dashboard';
  static const String employeeLeaves = '/employee/leaves';
  static const String employeeLeaveBalances = '/employee/leaves/balances';
  static const String employeeLeaveTypes = '/employee/leaves/types';
  static const String employeeLeaveApply = '/employee/leaves/apply';
  static const String employeeSalary = '/employee/salary';

  // ---------------------------------------------------------------------
  // Company (employee view) — 🔥 NEW
  // ---------------------------------------------------------------------
  static const String companyProfile = '/employee/company-profile';
  static const String companyEmployees = '/employee/company-employees';
  static const String companyCalendar = '/employee/company-calendar';

  // ---------------------------------------------------------------------
  // CMS (public legal pages) — 🔥 NEW
  // ---------------------------------------------------------------------
  static const String termsAndConditions = '/terms-and-conditions';
  static const String privacyPolicy = '/privacy-policy';

  // ---------------------------------------------------------------------
  // Team (manager leave review) — 🔥 NEW
  // ---------------------------------------------------------------------
  static const String teamLeaves = '/employee/team-leaves';
  static const String teamLeavesReview = '/employee/team-leaves/review';

  // ---------------------------------------------------------------------
  // Reference (lookup data) — 🔥 NEW
  // ---------------------------------------------------------------------
  static const String countries = '/countries';
  static const String cities = '/cities';

  // ---------------------------------------------------------------------
  // Tickets (Ansupport) — 🔥 NEW
  // ---------------------------------------------------------------------
  static const String tickets = '/employee/tickets';
  static const String ticketShow = '/employee/tickets/show';
  static const String ticketsMeta = '/employee/tickets/meta';
  static const String ticketReply = '/employee/tickets/reply';

  // ---------------------------------------------------------------------
  // Device  — 🔥 NEW
  // ---------------------------------------------------------------------

  static const String devices = '/employee/devices';
  static const String registerdevices = '/employee/devices';

  // ---------------------------------------------------------------------
  // Device  — 🔥 NEW
  // ---------------------------------------------------------------------

  static const String perimssion = '/employee/permissions';

  // ---------------------------------------------------------------------
  // Query param helpers
  // ---------------------------------------------------------------------
  static Map<String, dynamic> pagination({int page = 1, int pageSize = 20}) => {
    'page': page,
    'pageSize': pageSize,
  };
}