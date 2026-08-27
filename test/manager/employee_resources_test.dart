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
