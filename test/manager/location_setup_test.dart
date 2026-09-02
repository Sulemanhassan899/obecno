import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/auth/data/models/permission_item_model.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/manager_location_model.dart';

void main() {
  group('LocationSchedule', () {
    test('parses location detail schedule from the manager spec', () {
      final schedule = LocationSchedule.fromJson({
        'schedule': {
          'check_in': '08:00:00',
          'check_out': '17:00:00',
          'grace_minutes': 5,
          'working_days': [
            'monday',
            'tuesday',
            'wednesday',
            'thursday',
            'friday',
          ],
          'week_start_day': 'monday',
          'hours_per_day': '08:00',
          'hours_per_week': '40:00',
          'working_week_enabled': true,
          'max_break_minutes': 60,
          'break_location_tracking': true,
        },
      });

      expect(schedule.checkIn, const TimeOfDay(hour: 8, minute: 0));
      expect(schedule.checkOut, const TimeOfDay(hour: 17, minute: 0));
      expect(schedule.graceMinutes, 5);
      expect(schedule.workingDays, {
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
      });
      expect(schedule.weekStartDay, 'Monday');
      expect(schedule.hoursPerDay, '08:00');
      expect(schedule.hoursPerWeek, '40:00');
      expect(schedule.workingWeekEnabled, isTrue);
      expect(schedule.maxBreakMinutes, 60);
      expect(schedule.breakLabel, '60:00 mins');
      expect(schedule.breakLocationTracking, isTrue);
    });

    test('parses web location attendance overrides like 09:00 / 18:00', () {
      final schedule = LocationSchedule.fromJson({
        'attendance': {
          'check_in_time': '09:00',
          'check_out_time': '18:00',
          'grace_period': '5 minutes',
        },
        'working_days': {
          'monday': true,
          'tuesday': true,
          'wednesday': true,
          'thursday': true,
          'friday': true,
          'saturday': false,
          'sunday': false,
        },
        'break_timing': {
          'max_break_duration': 45,
          'break_location_tracking': true,
        },
      });

      expect(schedule.checkIn, const TimeOfDay(hour: 9, minute: 0));
      expect(schedule.checkOut, const TimeOfDay(hour: 18, minute: 0));
      expect(schedule.graceMinutes, 5);
      expect(schedule.workingDays, {
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
      });
      expect(schedule.maxBreakMinutes, 45);
      expect(schedule.breakLocationTracking, isTrue);
    });

    test('falls back to company permission values when location is empty', () {
      final company = LocationSchedule.fromPermissionItems([
        const PermissionItemModel(
          section: 'attendance',
          sectionLabel: 'Attendance',
          key: 'check_in_time',
          label: 'Check in time',
          value: '09:00 AM',
          companyValue: '09:00 AM',
        ),
        const PermissionItemModel(
          section: 'attendance',
          sectionLabel: 'Attendance',
          key: 'check_out_time',
          label: 'Check out time',
          value: '06:00 PM',
          companyValue: '06:00 PM',
        ),
        const PermissionItemModel(
          section: 'attendance',
          sectionLabel: 'Attendance',
          key: 'grace_period',
          label: 'Grace period',
          value: '5',
        ),
      ]);

      expect(company.checkIn, const TimeOfDay(hour: 9, minute: 0));
      expect(company.checkOut, const TimeOfDay(hour: 18, minute: 0));
      expect(company.graceMinutes, 5);

      final location = LocationSchedule.fromJson(const {}, fallback: company);
      expect(location.checkIn, company.checkIn);
      expect(location.checkOut, company.checkOut);
    });

    test('round-trips to the schedule write payload', () {
      const original = LocationSchedule(
        checkIn: TimeOfDay(hour: 9, minute: 30),
        checkOut: TimeOfDay(hour: 18, minute: 0),
        graceMinutes: 15,
        workingDays: {'Monday', 'Tuesday'},
        weekStartDay: 'Tuesday',
        hoursPerDay: '07:30',
        hoursPerWeek: '37:30',
        workingWeekEnabled: false,
        maxBreakMinutes: 45,
        breakLocationTracking: false,
      );

      final encoded = original.toJson();
      expect(encoded['check_in'], '09:30:00');
      expect(encoded['check_out'], '18:00:00');
      expect(encoded['grace_minutes'], 15);
      expect(
        encoded['working_days'],
        unorderedEquals(['monday', 'tuesday']),
      );
      expect(encoded['week_start_day'], 'tuesday');
      expect(encoded['max_break_minutes'], 45);
      expect(encoded['break_location_tracking'], isFalse);

      final parsed = LocationSchedule.fromJson(encoded);
      expect(parsed.checkIn, original.checkIn);
      expect(parsed.checkOut, original.checkOut);
      expect(parsed.graceMinutes, original.graceMinutes);
      expect(parsed.workingDays, original.workingDays);
      expect(parsed.weekStartDay, original.weekStartDay);
      expect(parsed.hoursPerDay, original.hoursPerDay);
      expect(parsed.hoursPerWeek, original.hoursPerWeek);
      expect(parsed.workingWeekEnabled, isFalse);
      expect(parsed.maxBreakMinutes, 45);
      expect(parsed.breakLocationTracking, isFalse);
    });

    test('prefers employee_value over location_value when asked', () {
      final location = LocationSchedule.fromPermissionItems(const [
        PermissionItemModel(
          section: 'attendance',
          sectionLabel: 'Attendance',
          key: 'check_in_time',
          label: 'Check in',
          value: '09:00 AM',
          locationValue: '08:00 AM',
          employeeValue: '10:00 AM',
        ),
      ]);
      expect(location.checkIn, const TimeOfDay(hour: 8, minute: 0));

      final employee = LocationSchedule.fromPermissionItems(const [
        PermissionItemModel(
          section: 'attendance',
          sectionLabel: 'Attendance',
          key: 'check_in_time',
          label: 'Check in',
          value: '09:00 AM',
          locationValue: '08:00 AM',
          employeeValue: '10:00 AM',
        ),
      ], preferEmployeeValue: true);
      expect(employee.checkIn, const TimeOfDay(hour: 10, minute: 0));
    });

    test('employee-level permission values override the profile schedule', () {
      final merged = LocationSchedule.fromEmployeeSources(
        schedule: {
          'check_in': '08:00:00',
          'working_days': ['monday', 'tuesday'],
        },
        permissionItems: const [
          PermissionItemModel(
            section: 'attendance',
            sectionLabel: 'Attendance',
            key: 'grace_period',
            label: 'Grace',
            employeeValue: '15',
            locationValue: '5',
          ),
          PermissionItemModel(
            section: 'attendance',
            sectionLabel: 'Attendance',
            key: 'check_in_time',
            label: 'Check in',
            employeeValue: '10:00 AM',
          ),
        ],
      );
      expect(merged.checkIn, const TimeOfDay(hour: 10, minute: 0));
      expect(merged.graceMinutes, 15);
      expect(merged.workingDays, {'Monday', 'Tuesday'});
    });
  });

  group('ManagerLocationModel', () {
    test('reads lat/long, created by object, and nested schedule', () {
      final location = ManagerLocationModel.fromJson({
        'id': '1',
        'name': 'bhara khou house',
        'address': 'HIBBAH Homeopathic Clinic',
        'latitude': 33.6844,
        'longitude': 73.0479,
        'allow_checkin_anywhere': true,
        'created_by': {'name': 'Ava Montgomery'},
        'created_at': '2026-01-20',
        'schedule': {
          'check_in': '08:00:00',
          'check_out': '17:00:00',
          'grace_minutes': 10,
          'working_days': ['monday', 'friday'],
          'max_break_minutes': 30,
          'break_location_tracking': false,
        },
      });

      expect(location.id, '1');
      expect(location.latitude, 33.6844);
      expect(location.longitude, 73.0479);
      expect(location.allowCheckinAnywhere, isTrue);
      expect(location.createdBy, 'Ava Montgomery');
      expect(location.createdAt, '20 Jan 2026');
      expect(location.policy.graceMinutes, 10);
      expect(location.policy.workingDays, {'Monday', 'Friday'});
      expect(location.policy.maxBreakMinutes, 30);
      expect(location.policy.breakLocationTracking, isFalse);
    });
  });
}
