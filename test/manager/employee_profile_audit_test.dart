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
            {
              'id': '10',
              'name': 'TECNO-CD7',
              'approval_status': 'pending',
            },
            {
              'id': '11',
              'name': 'emu64xa16k',
              'approval_status': 'pending',
            },
          ],
          'current_device': {
            'id': '12',
            'name': 'a36xq',
            'is_current': 1,
            'approval_status': 'pending',
          },
        },
      });

      expect(devices.map((d) => d.name), containsAll(['TECNO-CD7', 'emu64xa16k', 'a36xq']));
      expect(devices.firstWhere((d) => d.name == 'a36xq').isCurrent, isTrue);
    });

    test('does not treat not-approved as approved just because it contains approved', () {
      final device = DeviceModel.fromJson({
        'id': '3',
        'name': 'TECNO-CD7',
        'approval_status': 'Not approved',
        'is_approved': 0,
      });
      expect(device.isApproved, isFalse);
      expect(device.statusLabel, 'Pending');
    });
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
}
