class ManagerEmployeeApiEndpoints {
  ManagerEmployeeApiEndpoints._();

  // ---------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------
  static const String dashboard = '/manager/dashboard';
  static const String departments = '/manager/departments';

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

  // ---------------------------------------------------------------------
  // Locations
  // ---------------------------------------------------------------------
  static const String locations = '/manager/locations';

  static String location(Object locationId) => '$locations/$locationId';

  // ---------------------------------------------------------------------
  // Office employees
  // ---------------------------------------------------------------------
  static const String employees = '/manager/employees';
  static const String addEmployee = employees;
  static const String inviteEmployees = '$employees/invite';
  static const String employeesCreate = '/manager/employees/create';

  static String employee(Object employeeId) => '$employees/$employeeId';

  static String employeeAttendance(Object employeeId) =>
      '${employee(employeeId)}/attendance';

  static String employeeSalary(Object employeeId) =>
      '${employee(employeeId)}/salary';

  static String employeeAppraisals(Object employeeId) =>
      '${employee(employeeId)}/appraisals';

  static String employeeLeaves(Object employeeId) =>
      '${employee(employeeId)}/leaves';

  static String employeeLeaveBalances(Object employeeId) =>
      '${employee(employeeId)}/leave-balances';

  static String employeeLeaveQuota(Object employeeId) =>
      '${employee(employeeId)}/leave-quota';

  static String employeeHolidays(Object employeeId) =>
      '${employee(employeeId)}/holidays';

  static String employeeCalendar(Object employeeId) =>
      '${employee(employeeId)}/calendar';

  static String employeePermissions(Object employeeId) =>
      '${employee(employeeId)}/permissions';

  static String employeeLocations(Object employeeId) =>
      '${employee(employeeId)}/locations';

  static String employeeSchedule(Object employeeId) =>
      '${employee(employeeId)}/schedule';

  static String employeeDevices(Object employeeId) =>
      '${employee(employeeId)}/devices';

  static String employeeDevice(Object employeeId, Object deviceId) =>
      '${employeeDevices(employeeId)}/$deviceId';

  static String employeeDeviceReview(Object employeeId, Object deviceId) =>
      '${employeeDevice(employeeId, deviceId)}/review';

  static String employeeDeviceAction(
    Object employeeId,
    Object deviceId,
    String action,
  ) => '${employeeDevice(employeeId, deviceId)}/$action';

  // ---------------------------------------------------------------------
  // Legacy query-param employee APIs
  // ---------------------------------------------------------------------
  static const String legacyEmployeeProfile = '/manager/employee/profile';
  static const String legacyEmployeeAttendance = '/manager/employee/attendance';
  static const String legacyEmployeeSalary = '/manager/employee/salary';
  static const String legacyEmployeeAppraisals = '/manager/employee/appraisals';
  static const String legacyEmployeeLeaves = '/manager/employee/leaves';
  static const String legacyEmployeeLeaveBalances =
      '/manager/employee/leave-balances';
  static const String legacyEmployeeLeaveQuota =
      '/manager/employee/leave-quota';
  static const String legacyEmployeeHolidays = '/manager/employee/holidays';
  static const String legacyEmployeeCalendar = '/manager/employee/calendar';
  static const String legacyEmployeePermissions =
      '/manager/employee/permissions';
  static const String legacyEmployeeDevices = '/manager/employee/devices';

  // ---------------------------------------------------------------------
  // Billing
  // ---------------------------------------------------------------------
  static const String subscriptions = '/manager/subscriptions';
  static const String payments = '/manager/payments';
}
