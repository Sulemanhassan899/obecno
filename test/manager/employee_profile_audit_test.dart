import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/auth/data/models/permission_item_model.dart';
import 'package:obecno/features/employee_module/more/data/models/device_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_policy.dart';

void main() {
  group('DeviceModel manager envelopes', () {
    test('treats "Not approved" and is_approved=1 correctly', () {
      final pending = DeviceModel.fromJson({
        'id': '1',
        'device': 'TECNO-CD7',
        'status': 'Not approved',
      });
      expect(pending.name, 'TECNO-CD7');
      expect(pending.isApproved, isFalse);
      expect(pending.isPending, isTrue);

      final approved = DeviceModel.fromJson({
        'id': '2',
        'name': 'TECNO-CD7',
        'is_approved': 1,
        'approval_status': 'approved',
      });
      expect(approved.isApproved, isTrue);
      expect(approved.isPending, isFalse);
    });

    test('collects nested current_device without dropping the list', () {
      final devices = DeviceModel.listFromEnvelope({
        'success': true,
        'data': {
          'devices': [
            {'id': '10', 'name': 'TECNO-CD7', 'approval_status': 'pending'},
            {'id': '11', 'name': 'emu64xa16k', 'approval_status': 'pending'},
          ],
          'current_device': {
            'id': '12',
            'name': 'a36xq',
            'is_current': 1,
            'approval_status': 'pending',
          },
        },
      });

      expect(
        devices.map((d) => d.name),
        containsAll(['TECNO-CD7', 'emu64xa16k', 'a36xq']),
      );
      expect(devices.firstWhere((d) => d.name == 'a36xq').isCurrent, isTrue);
    });

    test(
      'does not treat not-approved as approved just because it contains approved',
      () {
        final device = DeviceModel.fromJson({
          'id': '3',
          'name': 'TECNO-CD7',
          'approval_status': 'Not approved',
          'is_approved': 0,
        });
        expect(device.isApproved, isFalse);
        expect(device.statusLabel, 'Pending');
      },
    );
  });

  group('ManagerEmployeePolicy', () {
    test('prefers employee_value over inherited value', () {
      final policy = ManagerEmployeePolicy.fromItems([
        const PermissionItemModel(
          section: 'attendance',
          sectionLabel: 'Attendance',
          key: 'check_in_time',
          label: 'Check in',
          value: '09:00 AM',
          employeeValue: '08:00 AM',
        ),
      ]);
      expect(policy.checkIn, const TimeOfDay(hour: 8, minute: 0));
    });

    test('parses schedule payload used by PUT /schedule', () {
      final policy = ManagerEmployeePolicy.fromSchedule({
        'check_in': '08:15:00',
        'check_out': '17:30:00',
        'grace_minutes': 10,
        'max_break_minutes': 45,
        'break_location_tracking': true,
      });
      expect(policy.checkIn, const TimeOfDay(hour: 8, minute: 15));
      expect(policy.checkOut, const TimeOfDay(hour: 17, minute: 30));
      expect(policy.graceMinutes, 10);
      expect(policy.breakLabel, '45:00 mins');
    });

    test('builds permission payload for check-in/out timing', () {
      final payload = ManagerEmployeePolicy.timingPermissionPayload(
        checkInLabel: '08:00 AM',
        checkOutLabel: '05:00 PM',
        graceMinutes: 10,
      );
      expect(payload['attendance'], {
        'check_in_time': '08:00 AM',
        'check_out_time': '05:00 PM',
        'grace_period': '10',
      });
      final items = payload['permission_items'] as List<dynamic>;
      expect(items.map((item) => (item as Map)['key']), [
        'check_in_time',
        'check_out_time',
        'grace_period',
      ]);
    });

    test('builds permission payload for break timing', () {
      final payload = ManagerEmployeePolicy.breakPermissionPayload(
        breakLabel: '60:00 mins',
        trackLocation: false,
      );
      expect(payload['break_timing'], {
        'break_time': '60:00 mins',
        'break_location_tracking': '0',
      });
      expect((payload['permission_items'] as List).length, 4);
    });
  });

  group('ManagerEmployeeModel locations', () {
    test('uses is_default from nested locations as the default office', () {
      final employee = ManagerEmployeeModel.fromJson({
        'id': '31',
        'name': 'Employee3',
        'locations': [
          {'id': '5', 'name': 'i-10 cowork', 'is_default': false},
          {'id': '9', 'name': 'Head Office', 'is_default': true},
        ],
        'schedule': {
          'check_in': '08:00:00',
          'check_out': '17:00:00',
          'grace_minutes': 5,
        },
      });
      expect(employee.locationId, '9');
      expect(employee.schedule?['check_in'], '08:00:00');
    });
  });

  group('ManagerEmployeeModel account fields', () {
    test('keeps address and employee code when nested user has nulls', () {
      final employee = ManagerEmployeeModel.fromApiJson({
        'success': true,
        'data': {
          'id': '12',
          'name': 'Mesulemanhassan',
          'email': 'testemployee@gmail.com',
          'phone': '1234567777',
          'employee_code': '1',
          'address': 'asdasdas',
          'user': {
            'id': '12',
            'email': 'testemployee@gmail.com',
            'phone': '1234567777',
            'address': null,
            'employee_code': null,
            'company_id': null,
          },
        },
      });
      expect(employee.email, 'testemployee@gmail.com');
      expect(employee.phone, '1234567777');
      expect(employee.employeeCode, '1');
      expect(employee.address, 'asdasdas');
    });

    test('reads home_address when address is omitted', () {
      final employee = ManagerEmployeeModel.fromApiJson({
        'employee': {
          'id': '12',
          'name': 'Ava',
          'home_address': 'Al Wasl Road, Dubai',
          'staff_id': 'EMP-31',
        },
      });
      expect(employee.address, 'Al Wasl Road, Dubai');
      expect(employee.employeeCode, 'EMP-31');
    });

    test('does not let a nested address map wipe a saved street string', () {
      final employee = ManagerEmployeeModel.fromApiJson({
        'data': {
          'id': '12',
          'address': 'street 1',
          'employee_code': '35',
          'profile': {
            'address': {'lat': 25.2, 'lng': 55.2, 'city': 'Dubai'},
          },
        },
      });
      expect(employee.address, 'street 1');
      expect(employee.employeeCode, '35');
    });

    test('reads formatted text from a nested address object', () {
      final employee = ManagerEmployeeModel.fromApiJson({
        'id': '12',
        'address': {'formatted_address': 'street 1', 'lat': 25.2},
      });
      expect(employee.address, 'street 1');
    });

    test('reads address from attributes and profile_fields', () {
      final fromAttributes = ManagerEmployeeModel.fromApiJson({
        'data': {
          'id': '12',
          'attributes': {'home_address': 'qweqweqwe', 'employee_code': '35'},
        },
      });
      expect(fromAttributes.address, 'qweqweqwe');
      expect(fromAttributes.employeeCode, '35');

      final fromFields = ManagerEmployeeModel.fromApiJson({
        'id': '12',
        'profile_fields': [
          {'label': 'Address', 'value': 'qweqweqwe'},
        ],
      });
      expect(fromFields.address, 'qweqweqwe');
    });
  });
}
