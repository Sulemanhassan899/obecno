import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/api/manager_api_endpoints.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_resources.dart';

void main() {
  group('Manager employee endpoints', () {
    test('covers REST create/edit and legacy update paths', () {
      expect(
        ManagerEmployeeApiEndpoints.employeesCreate,
        '/manager/employees/create',
      );
      expect(
        ManagerEmployeeApiEndpoints.employeeEdit(12),
        '/manager/employees/12/edit',
      );
      expect(
        ManagerEmployeeApiEndpoints.employeeUpdate(12),
        '/manager/employees/12/update',
      );
      expect(
        ManagerEmployeeApiEndpoints.legacyEmployeeUpdate,
        '/manager/employee/update',
      );
      expect(
        ManagerEmployeeApiEndpoints.legacyEmployeePermissions,
        '/manager/employee/permissions',
      );
      expect(
        ManagerEmployeeApiEndpoints.legacyEmployeePermissionsUpdate,
        '/manager/employee/permissions/update',
      );
      expect(
        ManagerEmployeeApiEndpoints.addLocation,
        '/manager/locations',
      );
      expect(
        ManagerEmployeeApiEndpoints.location(9),
        '/manager/locations/9',
      );
      expect(
        ManagerEmployeeApiEndpoints.employeeSalary(12),
        '/manager/employees/12/salary',
      );
      expect(
        ManagerEmployeeApiEndpoints.employeeAppraisals(12),
        '/manager/employees/12/appraisals',
      );
      expect(
        ManagerEmployeeApiEndpoints.employeeLeaves(12),
        '/manager/employees/12/leaves',
      );
      expect(
        ManagerEmployeeApiEndpoints.employeeLeaveBalances(12),
        '/manager/employees/12/leave-balances',
      );
      expect(
        ManagerEmployeeApiEndpoints.employeeLeaveQuota(12),
        '/manager/employees/12/leave-quota',
      );
      expect(
        ManagerEmployeeApiEndpoints.employeeCalendar(12),
        '/manager/employees/12/calendar',
      );
      expect(
        ManagerEmployeeApiEndpoints.legacyEmployeeSalary,
        '/manager/employee/salary',
      );
      expect(
        ManagerEmployeeApiEndpoints.legacyEmployeeCalendar,
        '/manager/employee/calendar',
      );
    });

    test('binds GET/POST/PUT/PATCH separately on shared paths', () {
      expect(ManagerEmployeeApiEndpoints.getEmployees.method, 'GET');
      expect(ManagerEmployeeApiEndpoints.postEmployees.method, 'POST');
      expect(
        ManagerEmployeeApiEndpoints.getEmployees.path,
        ManagerEmployeeApiEndpoints.postEmployees.path,
      );
      expect(
        ManagerEmployeeApiEndpoints.getEmployees,
        isNot(ManagerEmployeeApiEndpoints.postEmployees),
      );

      expect(ManagerEmployeeApiEndpoints.getEmployee(12).method, 'GET');
      expect(ManagerEmployeeApiEndpoints.putEmployee(12).method, 'PUT');
      expect(ManagerEmployeeApiEndpoints.patchEmployee(12).method, 'PATCH');
      expect(ManagerEmployeeApiEndpoints.getEmployee(12).path, '/manager/employees/12');
      expect(
        ManagerEmployeeApiEndpoints.putEmployee(12).path,
        ManagerEmployeeApiEndpoints.getEmployee(12).path,
      );
      expect(
        ManagerEmployeeApiEndpoints.patchEmployee(12).path,
        ManagerEmployeeApiEndpoints.getEmployee(12).path,
      );

      expect(
        ManagerEmployeeApiEndpoints.getEmployeePermissions(12).method,
        'GET',
      );
      expect(
        ManagerEmployeeApiEndpoints.putEmployeePermissions(12).method,
        'PUT',
      );
      expect(
        ManagerEmployeeApiEndpoints.patchEmployeePermissions(12).method,
        'PATCH',
      );
      expect(
        ManagerEmployeeApiEndpoints.getEmployeePermissions(12).path,
        '/manager/employees/12/permissions',
      );
      expect(
        ManagerEmployeeApiEndpoints.patchEmployeeStatus(12).method,
        'PATCH',
      );
      expect(
        ManagerEmployeeApiEndpoints.patchEmployeeStatus(12).path,
        '/manager/employees/12/status',
      );
      expect(
        ManagerEmployeeApiEndpoints.employeeStatus(12),
        '/manager/employees/12/status',
      );
      expect(ManagerEmployeeApiEndpoints.putEmployeeStatus(12).method, 'PUT');
      expect(ManagerEmployeeApiEndpoints.postEmployeeStatus(12).method, 'POST');

      expect(ManagerEmployeeApiEndpoints.getLocations.method, 'GET');
      expect(ManagerEmployeeApiEndpoints.postLocations.method, 'POST');
      expect(
        ManagerEmployeeApiEndpoints.getLocations.path,
        ManagerEmployeeApiEndpoints.postLocations.path,
      );
      expect(ManagerEmployeeApiEndpoints.getLocation(9).method, 'GET');
      expect(
        ManagerEmployeeApiEndpoints.getLocation(9).path,
        '/manager/locations/9',
      );
      expect(ManagerEmployeeApiEndpoints.putLocation(9).method, 'PUT');
      expect(
        ManagerEmployeeApiEndpoints.putLocation(9).path,
        '/manager/locations/9',
      );
      expect(
        ManagerEmployeeApiEndpoints.putLocationSchedule(9).method,
        'PUT',
      );
      expect(
        ManagerEmployeeApiEndpoints.getLocationSchedule(9).method,
        'GET',
      );
      expect(
        ManagerEmployeeApiEndpoints.getLocationSchedule(9).path,
        '/manager/locations/9/schedule',
      );
      expect(
        ManagerEmployeeApiEndpoints.putLocationSchedule(9).path,
        '/manager/locations/9/schedule',
      );
      expect(
        ManagerEmployeeApiEndpoints.patchLocationStatus(9).method,
        'PATCH',
      );
      expect(
        ManagerEmployeeApiEndpoints.patchLocationStatus(9).path,
        '/manager/locations/9/status',
      );
      expect(ManagerEmployeeApiEndpoints.deleteLocation(9).method, 'DELETE');
      expect(
        ManagerEmployeeApiEndpoints.deleteLocation(9).path,
        '/manager/locations/9',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLocationMembers(9).method,
        'POST',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLocationMembers(9).path,
        '/manager/locations/9/members',
      );
      expect(
        ManagerEmployeeApiEndpoints.locationSchedule(9),
        '/manager/locations/9/schedule',
      );
      expect(
        ManagerEmployeeApiEndpoints.locationMembers(9),
        '/manager/locations/9/members',
      );

      expect(ManagerEmployeeApiEndpoints.postTeamLeavesReview.method, 'POST');
      expect(
        ManagerEmployeeApiEndpoints.postTeamAttendanceEditSave.method,
        'POST',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLegacyEmployeeUpdate.method,
        'POST',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLegacyEmployeePermissionsUpdate.method,
        'POST',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLocationDelete(9).method,
        'POST',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLocationDelete(9).path,
        '/manager/locations/9/delete',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLocationsDelete.method,
        'POST',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLocationsDelete.path,
        '/manager/locations/delete',
      );
      expect(
        ManagerEmployeeApiEndpoints.getLocationPermissions(9).method,
        'GET',
      );
      expect(
        ManagerEmployeeApiEndpoints.putLocationPermissions(9).method,
        'PUT',
      );
      expect(
        ManagerEmployeeApiEndpoints.patchLocationPermissions(9).method,
        'PATCH',
      );
      expect(
        ManagerEmployeeApiEndpoints.deleteLocationPermissions(9).method,
        'DELETE',
      );
      expect(
        ManagerEmployeeApiEndpoints.getLocationPermissions(9).path,
        '/manager/locations/9/permissions',
      );
      expect(
        ManagerEmployeeApiEndpoints.getLocationPermission(9).path,
        '/manager/locations/9/permission',
      );
      expect(
        ManagerEmployeeApiEndpoints.putLocationPermission(9).method,
        'PUT',
      );
      expect(
        ManagerEmployeeApiEndpoints.patchLocationPermission(9).method,
        'PATCH',
      );
      expect(
        ManagerEmployeeApiEndpoints.patchLocationPermission(9).path,
        '/manager/locations/9/permission',
      );
      expect(
        ManagerEmployeeApiEndpoints.deleteLocationPermission(9).method,
        'DELETE',
      );
      expect(
        ManagerEmployeeApiEndpoints.deleteLocationPermission(9).path,
        '/manager/locations/9/permission',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLegacyLocationDelete.method,
        'POST',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLegacyLocationDelete.path,
        '/manager/location/delete',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLocationInactive(9).method,
        'POST',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLocationInactive(9).path,
        '/manager/locations/9/inactive',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLegacyLocationPermissionsUpdate.path,
        '/manager/location/permissions/update',
      );
      expect(
        ManagerEmployeeApiEndpoints.deleteLegacyLocationPermissions.method,
        'DELETE',
      );
      expect(
        ManagerEmployeeApiEndpoints.deleteLegacyLocationPermissions.path,
        '/manager/location/permissions/delete',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLegacyLocationInactive.path,
        '/manager/location/inactive',
      );
      expect(
        ManagerEmployeeApiEndpoints.putEmployeeDeviceReview(12, 3).method,
        'PUT',
      );
      expect(
        ManagerEmployeeApiEndpoints.patchEmployeeDeviceReview(12, 3).method,
        'PATCH',
      );
      expect(
        ManagerEmployeeApiEndpoints.deleteEmployeeDevice(12, 3).method,
        'DELETE',
      );
      expect(
        ManagerEmployeeApiEndpoints.deleteEmployeeDevice(12, 3).path,
        '/manager/employees/12/devices/3',
      );
      expect(
        ManagerEmployeeApiEndpoints.postEmployeeDeviceDelete(12, 3).path,
        '/manager/employees/12/devices/3/delete',
      );
      expect(
        ManagerEmployeeApiEndpoints.postEmployeeDeviceStatus(12, 3).method,
        'POST',
      );
      expect(
        ManagerEmployeeApiEndpoints.putEmployeeDeviceStatus(12, 3).method,
        'PUT',
      );
      expect(
        ManagerEmployeeApiEndpoints.patchEmployeeDeviceStatus(12, 3).method,
        'PATCH',
      );
      expect(
        ManagerEmployeeApiEndpoints.postEmployeeDeviceStatus(12, 3).path,
        '/manager/employees/12/devices/3/status',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLegacyEmployeeDeviceReview.path,
        '/manager/employee/device/review',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLegacyEmployeeDeviceDelete.path,
        '/manager/employee/device/delete',
      );
      expect(
        ManagerEmployeeApiEndpoints.postLegacyEmployeeDeviceStatus.path,
        '/manager/employee/device/status',
      );
      expect(
        ManagerEmployeeApiEndpoints.locationPermissions(9),
        '/manager/locations/9/permissions',
      );
      expect(
        ManagerEmployeeApiEndpoints.employeeDeviceDelete(12, 3),
        '/manager/employees/12/devices/3/delete',
      );
      expect(
        ManagerEmployeeApiEndpoints.legacyEmployeeDeviceReview,
        '/manager/employee/device/review',
      );
      expect(
        ManagerEmployeeApiEndpoints.legacyLocationDelete,
        '/manager/location/delete',
      );
      expect(
        ManagerEmployeeApiEndpoints.legacyLocationInactive,
        '/manager/location/inactive',
      );
    });
  });

  group('ManagerEmployeeFormData', () {
    test('reads nested lookups and employee from a create/edit envelope', () {
      final form = ManagerEmployeeFormData.fromJson({
        'employee': {'id': '12', 'name': 'Ava Montgomery', 'role': 'CEO'},
        'departments': [
          {'id': 4, 'name': 'Operations'},
        ],
        'countries': [
          {'id': 1, 'title': 'UAE'},
        ],
        'locations': [
          {'id': '9', 'label': 'Head Office'},
        ],
      });

      expect(form.employee?.id, '12');
      expect(form.employee?.name, 'Ava Montgomery');
      expect(form.departments.single.name, 'Operations');
      expect(form.countries.single.name, 'UAE');
      expect(form.locations.single.id, '9');
    });
  });

  group('Manager employee resource parsers', () {
    test('reads salary history from nested data.salary', () {
      final records = ManagerEmployeeSalaryRecord.listFrom({
        'success': true,
        'data': {
          'salary': [
            {
              'id': 1,
              'net_salary': 8500,
              'currency': 'AED',
              'effective_date': '2026-01-01',
              'type': 'basic',
            },
          ],
        },
      });
      expect(records, hasLength(1));
      expect(records.first.amount, '8500');
      expect(records.first.currency, 'AED');
    });

    test('reads appraisals, leaves, balances, and quota overrides', () {
      final appraisals = ManagerEmployeeAppraisal.listFrom({
        'appraisals': [
          {
            'id': '7',
            'increment': 500,
            'percentage': '5',
            'date': '2026-06-01',
            'reason': 'promotion',
          },
        ],
      });
      expect(appraisals.first.amount, '500');
      expect(appraisals.first.reason, 'promotion');

      final leaves = ManagerEmployeeLeaveRequest.listFrom({
        'data': {
          'leaves': [
            {
              'id': 3,
              'leave_type': 'Annual',
              'status': 'approved',
              'from_date': '2026-08-01',
              'to_date': '2026-08-05',
              'days': 5,
            },
          ],
        },
      });
      expect(leaves.first.type, 'Annual');
      expect(leaves.first.fromDate, '2026-08-01');

      final balances = ManagerEmployeeLeaveBalance.listFrom({
        'balances': [
          {
            'leave_type': 'Annual',
            'allocated': 21,
            'used': 5,
            'remaining': 16,
            'year': 2026,
          },
        ],
      });
      expect(balances.first.remaining, '16');

      final quotas = ManagerEmployeeLeaveQuota.listFrom({
        'leave_quota': [
          {'type': 'sick', 'days': 10, 'is_override': true, 'year': 2026},
        ],
      });
      expect(quotas.first.isOverride, isTrue);
      expect(quotas.first.days, '10');
    });
  });

  group('AttendanceCalendarData', () {
    test('reads manager calendar month dots', () {
      final calendar = AttendanceCalendarData.fromJson({
        'month': '2026-08',
        'month_label': 'August 2026',
        'attendance_dates': ['2026-08-03', '2026-08-19'],
      });
      expect(calendar.monthLabel, 'August 2026');
      expect(calendar.attendanceDates, hasLength(2));
      expect(calendar.attendanceDates.first.day, 3);
    });
  });
}
