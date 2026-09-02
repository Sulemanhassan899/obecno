/// One manager API operation: HTTP method + path.
///
/// The same path can be used by more than one method (for example GET and POST
/// on `/manager/employees`). Always pick the named route for the verb you need
/// instead of reusing a path string with a different client method.
class ManagerApiRoute {
  const ManagerApiRoute.get(this.path) : method = 'GET';
  const ManagerApiRoute.post(this.path) : method = 'POST';
  const ManagerApiRoute.put(this.path) : method = 'PUT';
  const ManagerApiRoute.patch(this.path) : method = 'PATCH';
  const ManagerApiRoute.delete(this.path) : method = 'DELETE';

  /// HTTP verb: `GET`, `POST`, `PUT`, `PATCH`, or `DELETE`.
  final String method;
  final String path;

  @override
  String toString() => '$method $path';

  @override
  bool operator ==(Object other) =>
      other is ManagerApiRoute && other.method == method && other.path == path;

  @override
  int get hashCode => Object.hash(method, path);
}

class ManagerEmployeeApiEndpoints {
  ManagerEmployeeApiEndpoints._();

  static const _base = '/manager';
  static const _employees = '$_base/employees';
  static const _legacyEmployee = '$_base/employee';
  static const _locations = '$_base/locations';
  static const _teamAttendance = '$_base/team-attendance';

  static String _employee(Object employeeId) => '$_employees/$employeeId';

  // =====================================================================
  // Dashboard & company
  // =====================================================================
  static const getDepartments = ManagerApiRoute.get('$_base/departments');
  static const getDashboard = ManagerApiRoute.get('$_base/dashboard');

  // =====================================================================
  // Team
  // =====================================================================
  static const getTeamMembers = ManagerApiRoute.get('$_base/team-members');
  static const getTeamLeaves = ManagerApiRoute.get('$_base/team-leaves');
  static const postTeamLeavesReview = ManagerApiRoute.post(
    '$_base/team-leaves/review',
  );
  static const getTeamCalendar = ManagerApiRoute.get('$_base/team-calendar');

  // =====================================================================
  // Team attendance
  // =====================================================================
  static const getTeamAttendance = ManagerApiRoute.get(_teamAttendance);
  static const getTeamAttendanceFilters = ManagerApiRoute.get(
    '$_teamAttendance/filters',
  );
  static const getTeamAttendanceDetails = ManagerApiRoute.get(
    '$_teamAttendance/details',
  );
  static const getTeamAttendanceEdit = ManagerApiRoute.get(
    '$_teamAttendance/edit',
  );
  static const postTeamAttendanceEditSave = ManagerApiRoute.post(
    '$_teamAttendance/edit/save',
  );

  // =====================================================================
  // Billing
  // =====================================================================
  static const getSubscriptions = ManagerApiRoute.get('$_base/subscriptions');
  static const getPayments = ManagerApiRoute.get('$_base/payments');

  // =====================================================================
  // Locations — GET list, POST add, GET/PUT detail, schedule, members
  // =====================================================================
  static const getLocations = ManagerApiRoute.get(_locations);
  static const postLocations = ManagerApiRoute.post(_locations);

  static ManagerApiRoute getLocation(Object locationId) =>
      ManagerApiRoute.get('$_locations/$locationId');

  static ManagerApiRoute putLocation(Object locationId) =>
      ManagerApiRoute.put('$_locations/$locationId');

  static ManagerApiRoute putLocationSchedule(Object locationId) =>
      ManagerApiRoute.put('$_locations/$locationId/schedule');

  static ManagerApiRoute getLocationSchedule(Object locationId) =>
      ManagerApiRoute.get('$_locations/$locationId/schedule');

  static ManagerApiRoute patchLocationStatus(Object locationId) =>
      ManagerApiRoute.patch('$_locations/$locationId/status');

  static ManagerApiRoute deleteLocation(Object locationId) =>
      ManagerApiRoute.delete('$_locations/$locationId');

  static ManagerApiRoute postLocationMembers(Object locationId) =>
      ManagerApiRoute.post('$_locations/$locationId/members');

  // =====================================================================
  // Office employees — GET list, POST add (same collection path)
  // =====================================================================
  static const getEmployees = ManagerApiRoute.get(_employees);
  static const postEmployees = ManagerApiRoute.post(_employees);
  static const getEmployeesCreate = ManagerApiRoute.get('$_employees/create');
  static const postInviteEmployees = ManagerApiRoute.post('$_employees/invite');

  // =====================================================================
  // Employee profile — GET view, PUT full update, PATCH partial
  // =====================================================================
  static ManagerApiRoute getEmployee(Object employeeId) =>
      ManagerApiRoute.get(_employee(employeeId));

  static ManagerApiRoute putEmployee(Object employeeId) =>
      ManagerApiRoute.put(_employee(employeeId));

  static ManagerApiRoute patchEmployee(Object employeeId) =>
      ManagerApiRoute.patch(_employee(employeeId));

  static ManagerApiRoute getEmployeeEdit(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/edit');

  static ManagerApiRoute getEmployeeAttendance(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/attendance');

  static ManagerApiRoute getEmployeeAttendanceDetails(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/attendance/details');

  static ManagerApiRoute getEmployeeSalary(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/salary');

  static ManagerApiRoute getEmployeeAppraisals(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/appraisals');

  static ManagerApiRoute getEmployeeLeaves(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/leaves');

  static ManagerApiRoute getEmployeeLeaveBalances(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/leave-balances');

  static ManagerApiRoute getEmployeeLeaveQuota(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/leave-quota');

  static ManagerApiRoute getEmployeeHolidays(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/holidays');

  static ManagerApiRoute getEmployeeCalendar(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/calendar');

  // Permissions on the same path: GET / PUT / PATCH
  static ManagerApiRoute getEmployeePermissions(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/permissions');

  static ManagerApiRoute putEmployeePermissions(Object employeeId) =>
      ManagerApiRoute.put('${_employee(employeeId)}/permissions');

  static ManagerApiRoute patchEmployeePermissions(Object employeeId) =>
      ManagerApiRoute.patch('${_employee(employeeId)}/permissions');

  static ManagerApiRoute getEmployeeDevices(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/devices');

  static ManagerApiRoute getEmployeeLocations(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/locations');

  static ManagerApiRoute putEmployeeLocations(Object employeeId) =>
      ManagerApiRoute.put('${_employee(employeeId)}/locations');

  static ManagerApiRoute patchEmployeeLocations(Object employeeId) =>
      ManagerApiRoute.patch('${_employee(employeeId)}/locations');

  static ManagerApiRoute getEmployeeSchedule(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/schedule');

  static ManagerApiRoute putEmployeeSchedule(Object employeeId) =>
      ManagerApiRoute.put('${_employee(employeeId)}/schedule');

  static ManagerApiRoute patchEmployeeSchedule(Object employeeId) =>
      ManagerApiRoute.patch('${_employee(employeeId)}/schedule');

  static ManagerApiRoute getEmployeeDevice(
    Object employeeId,
    Object deviceId,
  ) => ManagerApiRoute.get('${_employee(employeeId)}/devices/$deviceId');

  static ManagerApiRoute putEmployeeDevice(
    Object employeeId,
    Object deviceId,
  ) => ManagerApiRoute.put('${_employee(employeeId)}/devices/$deviceId');

  static ManagerApiRoute patchEmployeeDevice(
    Object employeeId,
    Object deviceId,
  ) => ManagerApiRoute.patch('${_employee(employeeId)}/devices/$deviceId');

  static ManagerApiRoute postEmployeeDeviceReview(
    Object employeeId,
    Object deviceId,
  ) => ManagerApiRoute.post(
    '${_employee(employeeId)}/devices/$deviceId/review',
  );

  static ManagerApiRoute postEmployeeDeviceAction(
    Object employeeId,
    Object deviceId,
    String action,
  ) => ManagerApiRoute.post(
    '${_employee(employeeId)}/devices/$deviceId/$action',
  );

  static ManagerApiRoute getEmployeePhoto(Object employeeId) =>
      ManagerApiRoute.get('${_employee(employeeId)}/photo');

  static ManagerApiRoute postEmployeePhoto(Object employeeId) =>
      ManagerApiRoute.post('${_employee(employeeId)}/photo');

  // =====================================================================
  // Legacy query-param employee APIs (`/manager/employee/...`)
  // =====================================================================
  static const postLegacyEmployeeUpdate = ManagerApiRoute.post(
    '$_legacyEmployee/update',
  );
  static const getLegacyEmployeeProfile = ManagerApiRoute.get(
    '$_legacyEmployee/profile',
  );
  static const getLegacyEmployeeAttendance = ManagerApiRoute.get(
    '$_legacyEmployee/attendance',
  );
  static const getLegacyEmployeeSalary = ManagerApiRoute.get(
    '$_legacyEmployee/salary',
  );
  static const getLegacyEmployeeAppraisals = ManagerApiRoute.get(
    '$_legacyEmployee/appraisals',
  );
  static const getLegacyEmployeeLeaves = ManagerApiRoute.get(
    '$_legacyEmployee/leaves',
  );
  static const getLegacyEmployeeLeaveBalances = ManagerApiRoute.get(
    '$_legacyEmployee/leave-balances',
  );
  static const getLegacyEmployeeLeaveQuota = ManagerApiRoute.get(
    '$_legacyEmployee/leave-quota',
  );
  static const getLegacyEmployeeHolidays = ManagerApiRoute.get(
    '$_legacyEmployee/holidays',
  );
  static const getLegacyEmployeeCalendar = ManagerApiRoute.get(
    '$_legacyEmployee/calendar',
  );
  static const getLegacyEmployeePermissions = ManagerApiRoute.get(
    '$_legacyEmployee/permissions',
  );
  static const postLegacyEmployeePermissionsUpdate = ManagerApiRoute.post(
    '$_legacyEmployee/permissions/update',
  );
  static const getLegacyEmployeeDevices = ManagerApiRoute.get(
    '$_legacyEmployee/devices',
  );
  static const getLegacyEmployeePhoto = ManagerApiRoute.get(
    '$_legacyEmployee/photo',
  );
  static const postLegacyEmployeePhoto = ManagerApiRoute.post(
    '$_legacyEmployee/photo',
  );

  // ---------------------------------------------------------------------
  // Path-only aliases for existing repositories (prefer ManagerApiRoute).
  // ---------------------------------------------------------------------
  static const String dashboard = '$_base/dashboard';
  static const String departments = '$_base/departments';

  static const String teamMembers = '$_base/team-members';
  static const String teamLeaves = '$_base/team-leaves';
  static const String teamLeavesReview = '$_base/team-leaves/review';
  static const String teamCalendar = '$_base/team-calendar';

  static const String teamAttendance = _teamAttendance;
  static const String teamAttendanceFilters = '$_teamAttendance/filters';
  static const String teamAttendanceDetails = '$_teamAttendance/details';
  static const String teamAttendanceEdit = '$_teamAttendance/edit';
  static const String teamAttendanceEditSave = '$_teamAttendance/edit/save';

  static const String locations = _locations;
  static const String addLocation = _locations;

  static String location(Object locationId) => getLocation(locationId).path;

  static String locationSchedule(Object locationId) =>
      putLocationSchedule(locationId).path;

  static String locationStatus(Object locationId) =>
      patchLocationStatus(locationId).path;

  static String locationMembers(Object locationId) =>
      postLocationMembers(locationId).path;

  static const String employees = _employees;
  static const String addEmployee = _employees;
  static const String inviteEmployees = '$_employees/invite';
  static const String employeesCreate = '$_employees/create';

  static String employee(Object employeeId) => getEmployee(employeeId).path;

  static String employeeEdit(Object employeeId) =>
      getEmployeeEdit(employeeId).path;

  static String employeeUpdate(Object employeeId) =>
      '${_employee(employeeId)}/update';

  static String employeeAttendance(Object employeeId) =>
      getEmployeeAttendance(employeeId).path;

  static String employeeAttendanceDetails(Object employeeId) =>
      getEmployeeAttendanceDetails(employeeId).path;

  static String employeeSalary(Object employeeId) =>
      getEmployeeSalary(employeeId).path;

  static String employeeAppraisals(Object employeeId) =>
      getEmployeeAppraisals(employeeId).path;

  static String employeeLeaves(Object employeeId) =>
      getEmployeeLeaves(employeeId).path;

  static String employeeLeaveBalances(Object employeeId) =>
      getEmployeeLeaveBalances(employeeId).path;

  static String employeeLeaveQuota(Object employeeId) =>
      getEmployeeLeaveQuota(employeeId).path;

  static String employeeHolidays(Object employeeId) =>
      getEmployeeHolidays(employeeId).path;

  static String employeeCalendar(Object employeeId) =>
      getEmployeeCalendar(employeeId).path;

  static String employeePermissions(Object employeeId) =>
      getEmployeePermissions(employeeId).path;

  static String employeeLocations(Object employeeId) =>
      getEmployeeLocations(employeeId).path;

  static String employeeSchedule(Object employeeId) =>
      getEmployeeSchedule(employeeId).path;

  static String employeeDevices(Object employeeId) =>
      getEmployeeDevices(employeeId).path;

  static String employeeDevice(Object employeeId, Object deviceId) =>
      getEmployeeDevice(employeeId, deviceId).path;

  static String employeeDeviceReview(Object employeeId, Object deviceId) =>
      postEmployeeDeviceReview(employeeId, deviceId).path;

  static String employeeDeviceAction(
    Object employeeId,
    Object deviceId,
    String action,
  ) => postEmployeeDeviceAction(employeeId, deviceId, action).path;

  static String employeePhoto(Object employeeId) =>
      getEmployeePhoto(employeeId).path;

  static const String legacyEmployeeProfile = '$_legacyEmployee/profile';
  static const String legacyEmployeeUpdate = '$_legacyEmployee/update';
  static const String legacyEmployeeAttendance = '$_legacyEmployee/attendance';
  static const String legacyEmployeeSalary = '$_legacyEmployee/salary';
  static const String legacyEmployeeAppraisals = '$_legacyEmployee/appraisals';
  static const String legacyEmployeeLeaves = '$_legacyEmployee/leaves';
  static const String legacyEmployeeLeaveBalances =
      '$_legacyEmployee/leave-balances';
  static const String legacyEmployeeLeaveQuota = '$_legacyEmployee/leave-quota';
  static const String legacyEmployeeHolidays = '$_legacyEmployee/holidays';
  static const String legacyEmployeeCalendar = '$_legacyEmployee/calendar';
  static const String legacyEmployeePermissions =
      '$_legacyEmployee/permissions';
  static const String legacyEmployeePermissionsUpdate =
      '$_legacyEmployee/permissions/update';
  static const String legacyEmployeeDevices = '$_legacyEmployee/devices';
  static const String legacyEmployeePhoto = '$_legacyEmployee/photo';

  static const String subscriptions = '$_base/subscriptions';
  static const String payments = '$_base/payments';
}
