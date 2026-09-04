import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/auth/data/models/permission_item_model.dart';
import 'package:obecno/features/employee_module/more/data/models/device_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/data/models/manager_employee_model.dart';
import 'package:obecno/features/manager_module/Manager_employees/domain/manager_employee_policy.dart';
import 'package:obecno/shared/bottom_sheets/employee_sheet/manager_linked_devices_sheet.dart';

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

    test('treats blocked and rejected as distinct from pending', () {
      final blocked = DeviceModel.fromJson({
        'id': '4',
        'name': 'Pixel',
        'approval_status': 'blocked',
      });
      expect(blocked.isBlocked, isTrue);
      expect(blocked.isApproved, isFalse);
      expect(blocked.statusLabel, 'Blocked');

      final rejected = DeviceModel.fromJson({
        'id': '5',
        'name': 'iPhone',
        'approval_status': 'rejected',
      });
      expect(rejected.isRejected, isTrue);
      expect(rejected.isBlocked, isFalse);
      expect(rejected.statusLabel, 'Rejected');
    });

    test('uses approver name instead of a numeric id', () {
      final byId = DeviceModel.fromJson({
        'id': '1',
        'name': 'Emulator',
        'approval_status': 'approved',
        'is_approved': 1,
        'actioned_by': 28,
        'actioned_by_name': 'owner',
      });
      expect(byId.actionedBy, 'owner');
      expect(byId.actionedById, '28');
      expect(byId.actionedByLabel, 'Approved by: owner');
      expect(byId.showDeleteRequest, isFalse);

      final nested = DeviceModel.fromJson({
        'id': '2',
        'name': 'Emulator',
        'approval_status': 'approved',
        'approved_by': {'id': 28, 'name': 'owner'},
      });
      expect(nested.actionedBy, 'owner');
      expect(nested.actionedByLabel, 'Approved by: owner');

      final idOnly = DeviceModel.fromJson({
        'id': '3',
        'name': 'Emulator',
        'approval_status': 'approved',
        'actioned_by': 28,
      });
      expect(idOnly.actionedBy, isNull);
      expect(idOnly.actionedById, '28');
      expect(idOnly.actionedByLabel, isNull);
    });

    test('fills approver name from envelope users list', () {
      final devices = DeviceModel.listFromEnvelope({
        'devices': [
          {
            'id': '1',
            'name': 'Emulator',
            'approval_status': 'approved',
            'is_approved': 1,
            'actioned_by': 28,
          },
        ],
        'users': [
          {'id': 28, 'name': 'owner'},
        ],
      });
      expect(devices.single.actionedByLabel, 'Approved by: owner');
    });

    test('hides delete request on active devices and shows it on pending', () {
      final active = DeviceModel.fromJson({
        'id': '1',
        'name': 'Emulator',
        'approval_status': 'approved',
        'is_approved': 1,
      });
      expect(active.statusLabel, 'Active');
      expect(active.showDeleteRequest, isFalse);

      final pending = DeviceModel.fromJson({
        'id': '2',
        'name': 'Pixel',
        'approval_status': 'pending',
      });
      expect(pending.statusLabel, 'Pending');
      expect(pending.showDeleteRequest, isTrue);
    });

    test('pins the current device at the top of the list', () {
      final devices = DeviceModel.currentFirst([
        DeviceModel.fromJson({
          'id': '1',
          'name': 'Office phone',
          'approval_status': 'approved',
        }),
        DeviceModel.fromJson({
          'id': '2',
          'name': 'Emulator',
          'is_current': 1,
          'approval_status': 'approved',
        }),
      ]);
      expect(devices.first.name, 'Emulator');
      expect(devices.first.isCurrent, isTrue);
    });

    test(
      'DeviceListResponse keeps nested current_device and pending groups',
      () {
        final response = DeviceListResponse.fromJson({
          'success': true,
          'data': {
            'devices': [
              {'id': '10', 'name': 'TECNO-CD7', 'approval_status': 'pending'},
            ],
            'current_device': {
              'id': '12',
              'name': 'sdk_gphone64',
              'is_current': 1,
              'approval_status': 'pending',
              'mac_address': 'emu-uuid',
            },
            'pending': [
              {
                'id': '13',
                'device_name': 'Pixel',
                'approval_status': 'requested',
              },
            ],
          },
        });

        expect(
          response.devices.map((d) => d.displayName),
          containsAll(['TECNO-CD7', 'Emulator', 'Pixel']),
        );
        expect(
          response.devices
              .firstWhere((d) => d.name == 'sdk_gphone64')
              .isCurrent,
          isTrue,
        );
        expect(
          response.devices.firstWhere((d) => d.name == 'Pixel').isPending,
          isTrue,
        );
      },
    );

    test(
      'DeviceListResponse parses a single device object as a one-item list',
      () {
        final response = DeviceListResponse.fromJson({
          'id': '12',
          'device_name': 'emu64xa16k',
          'approval_status': 'pending',
          'mac_address': 'abc-uuid',
        });

        expect(response.devices, hasLength(1));
        expect(response.devices.first.isPending, isTrue);
        expect(response.devices.first.deviceId, 'abc-uuid');
      },
    );

    test('pretty-prints Samsung A-series and emulator names', () {
      expect(
        DeviceDisplayName.resolve(
          name: 'a36xq',
          model: 'SM-A366B',
          manufacturer: 'samsung',
        ),
        'A36',
      );
      expect(DeviceDisplayName.resolve(name: 'a36xq'), 'A36');
      expect(DeviceDisplayName.resolve(name: 'emu64xa16k'), 'Emulator');
      expect(
        DeviceDisplayName.resolve(name: 'sdk_gphone64_arm64', isEmulator: true),
        'Emulator',
      );
      expect(
        DeviceModel.fromJson({
          'id': '1',
          'name': 'a36xq',
          'model': 'SM-A366B',
        }).displayName,
        'A36',
      );
    });

    test('parses Laravel created_at as the request date', () {
      final device = DeviceModel.fromJson({
        'id': '1',
        'name': 'a36xq',
        'approval_status': 'pending',
        'created_at': '2026-09-02 15:37:51',
      });
      expect(device.requestedAt, isNotNull);
      expect(device.requestedAt!.year, 2026);
      expect(device.requestedAt!.month, 9);
      expect(device.requestedAt!.day, 2);
      expect(device.requestedAt!.hour, 15);
      expect(device.requestedAt!.minute, 37);
      expect(device.displayName, 'A36');
      expect(device.cardTimestamp, device.requestedAt);
    });
  });

  group('ManagerLinkedDevice list', () {
    ManagerLinkedDevice device({
      required String id,
      required String name,
      required ManagerDeviceStatus status,
      bool isCurrent = false,
    }) {
      return ManagerLinkedDevice(
        id: id,
        name: name,
        platform: 'android',
        status: status,
        detail: 'Last used: Today',
        isCurrent: isCurrent,
      );
    }

    test('keeps a blocked device on the list when GET omits it', () {
      final previous = [
        device(id: '1', name: 'A36', status: ManagerDeviceStatus.active),
        device(
          id: '2',
          name: 'Emulator',
          status: ManagerDeviceStatus.blocked,
        ),
      ];
      final incoming = [
        device(id: '1', name: 'A36', status: ManagerDeviceStatus.active),
      ];

      final merged = ManagerLinkedDevice.retainKnownDevices(
        incoming: incoming,
        previous: previous,
      );
      expect(merged.map((d) => d.id), ['1', '2']);
      expect(
        merged.firstWhere((d) => d.id == '2').status,
        ManagerDeviceStatus.blocked,
      );
    });

    test('keeps an unblocked device on the list when GET omits it', () {
      final previous = [
        device(id: '1', name: 'A36', status: ManagerDeviceStatus.active),
        device(
          id: '2',
          name: 'Emulator',
          status: ManagerDeviceStatus.active,
        ),
      ];
      final incoming = [
        device(id: '1', name: 'A36', status: ManagerDeviceStatus.active),
      ];

      final merged = ManagerLinkedDevice.retainKnownDevices(
        incoming: incoming,
        previous: previous,
      );
      expect(merged.map((d) => d.id), ['1', '2']);
      expect(
        merged.firstWhere((d) => d.id == '2').status,
        ManagerDeviceStatus.active,
      );
    });

    test('keeps a pending device request on the list when GET omits it', () {
      final previous = [
        device(id: '1', name: 'A36', status: ManagerDeviceStatus.active),
        device(
          id: '3',
          name: 'Pixel',
          status: ManagerDeviceStatus.pending,
        ),
      ];
      final incoming = [
        device(id: '1', name: 'A36', status: ManagerDeviceStatus.active),
      ];

      final merged = ManagerLinkedDevice.retainKnownDevices(
        incoming: incoming,
        previous: previous,
      );
      expect(merged.map((d) => d.id), ['1', '3']);
      expect(
        merged.firstWhere((d) => d.id == '3').status,
        ManagerDeviceStatus.pending,
      );
    });

    test('pins the current device at the top', () {
      final ordered = ManagerLinkedDevice.currentFirst([
        device(id: '1', name: 'A36', status: ManagerDeviceStatus.active),
        device(
          id: '2',
          name: 'Emulator',
          status: ManagerDeviceStatus.active,
          isCurrent: true,
        ),
      ]);
      expect(ordered.first.id, '2');
      expect(ordered.first.isCurrent, isTrue);
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

    test('builds permission payload for working days', () {
      final payload = ManagerEmployeePolicy.workingDaysPermissionPayload(
        workingDays: const ['Monday', 'Wednesday'],
        weekStartDay: 'Monday',
        hoursPerDay: '08:00',
        hoursPerWeek: '40:00',
        workingWeekEnabled: true,
      );
      expect(payload['working_week'], {
        'working_days': ['monday', 'wednesday'],
        'week_start_day': 'monday',
        'hours_per_day': '08:00',
        'hours_per_week': '40:00',
        'working_week_enabled': true,
      });
    });

    test('reads working days from a profile schedule list', () {
      final policy = ManagerEmployeePolicy.fromSchedule({
        'check_in': '08:00:00',
        'working_days': ['monday', 'friday'],
      });
      expect(policy.workingDays, 'monday, friday');
    });
  });

  group('Employee permission write method', () {
    test('uses PATCH for partial employee setting updates', () {
      expect(PermissionItemModel.writeMethod(hasEmployeeLevel: true), 'PATCH');
      expect(PermissionItemModel.writeMethod(hasEmployeeLevel: false), 'PATCH');
    });

    test('detects existing employee-level overrides', () {
      const items = [
        PermissionItemModel(
          section: 'attendance',
          sectionLabel: 'Attendance',
          key: 'check_in_time',
          label: 'Check in',
          value: '09:00 AM',
          employeeValue: '08:00 AM',
        ),
      ];
      expect(PermissionItemModel.hasEmployeeLevelPermissions(items), isTrue);
    });

    test(
      'treats source_level=employee as employee-level even without value',
      () {
        const item = PermissionItemModel(
          section: 'attendance',
          sectionLabel: 'Attendance',
          key: 'grace_period',
          label: 'Grace',
          value: '5',
          sourceLevel: 'employee',
        );
        expect(item.hasEmployeeLevel, isTrue);
      },
    );
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

  group('ManagerEmployeeStatus', () {
    test('maps disabled/deactivated to disabled and apiValue for PATCH', () {
      final disabled = ManagerEmployeeModel.fromJson({
        'id': '12',
        'name': 'Ava',
        'account_status': 'disabled',
      });
      expect(disabled.status, ManagerEmployeeStatus.disabled);
      expect(disabled.status.apiValue, 'disabled');
      expect(ManagerEmployeeStatus.active.apiValue, 'active');
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
