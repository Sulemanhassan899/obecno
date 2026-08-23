class ManagerEmployeeApiEndpoints {
  ManagerEmployeeApiEndpoints._();

  // ---------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------
  static const String dashboard = '/manager/dashboard';
  static const String departments = '/manager/departments';
  static const String locations = '/manager/locations';

  // ---------------------------------------------------------------------
  // Team
  // ---------------------------------------------------------------------
  static const String teamMembers = '/manager/team-members';
  static const String teamLeaves = '/manager/team-leaves';
  static const String teamLeavesReview = '/manager/team-leaves/review';
  static const String teamCalendar = '/manager/team-calendar';

  // ---------------------------------------------------------------------
  // Team attendance
  // ---------------------------------------------------------------------
  static const String teamAttendance = '/manager/team-attendance';
  static const String teamAttendanceFilters =
      '/manager/team-attendance/filters';
  static const String teamAttendanceDetails =
      '/manager/team-attendance/details';
  static const String teamAttendanceEdit = '/manager/team-attendance/edit';
  static const String teamAttendanceEditSave =
      '/manager/team-attendance/edit/save';
}
