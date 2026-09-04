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

    test('write payload includes location permission items', () {
      const original = LocationSchedule(
        checkIn: TimeOfDay(hour: 9, minute: 0),
        checkOut: TimeOfDay(hour: 18, minute: 0),
        graceMinutes: 30,
        workingDays: {'Monday', 'Friday'},
        weekStartDay: 'Monday',
        hoursPerDay: '08:00',
        hoursPerWeek: '40:00',
        workingWeekEnabled: true,
        maxBreakMinutes: 60,
        breakLocationTracking: true,
      );

      final payload = original.writePayload();
      expect(payload['check_in_time'], '09:00');
      expect(payload['attendance']['grace_period'], 30);
      expect(payload['break_timing']['max_break_minutes'], 60);

      final items = payload['permission_items'] as List;
      Map<String, dynamic> item(String section, String key) {
        return items.cast<Map<String, dynamic>>().firstWhere(
          (row) => row['section'] == section && row['key'] == key,
        );
      }

      expect(item('attendance', 'check_in_time')['value'], '09:00 AM');
      expect(item('attendance', 'check_in_time')['location_value'], '09:00 AM');
      expect(item('attendance', 'check_out_time')['value'], '06:00 PM');
      expect(item('attendance', 'grace_period')['value'], '30');
      expect(item('attendance', 'break_time')['value'], '60:00 mins');
      expect(item('break_timing', 'break_location_tracking')['value'], '1');
      expect(item('working_days', 'working_days')['source_level'], 'location');
    });

    test('permissions API payload uses location_setting for PUT/PATCH', () {
      const original = LocationSchedule(
        checkIn: TimeOfDay(hour: 9, minute: 0),
        checkOut: TimeOfDay(hour: 18, minute: 0),
        graceMinutes: 15,
        workingDays: {'Monday'},
        maxBreakMinutes: 60,
        breakLocationTracking: true,
      );

      final payload = original.permissionsApiPayload(locationId: '12');
      expect(payload['location_id'], 12);
      expect(payload['section'], 'attendance');
      expect(payload['permission_section'], 'attendance');
      expect(payload['field'], 'check_in_time');
      expect(payload['value'], '09:00');
      expect(payload['import_company_settings'], isFalse);
      expect(payload['location_setting']['check_in_time'], '09:00');
      expect(payload['location_setting']['check_out_time'], '18:00');
      expect(payload['location_setting']['grace_period'], '15-min');
      expect(payload['location_setting']['break_time'], '60:00 mins');
      expect(payload['permissions']['attendance']['check_in_time'], '09:00');
    });

    test('GET location_setting envelope overlays check in and break', () {
      final items = PermissionItemModel.listFromEnvelope({
        'location_id': 12,
        'field': 'check_in_time',
        'value': '09:00',
        'section': 'attendance',
        'permission_section': 'attendance',
        'location_setting': {
          'check_in_time': '09:00',
          'grace_period': '15-min',
          'casual_leaves': 12,
        },
      });
      expect(items, isNotEmpty);
      final schedule = LocationSchedule.fromPermissionItems(items);
      expect(schedule.checkIn, const TimeOfDay(hour: 9, minute: 0));
      expect(schedule.graceMinutes, 15);
    });

    test('PUT is used before a location has permissions, PATCH after', () {
      expect(
        PermissionItemModel.locationWriteMethod(hasLocationPermissions: false),
        'PUT',
      );
      expect(
        PermissionItemModel.locationWriteMethod(hasLocationPermissions: true),
        'PATCH',
      );
      expect(
        PermissionItemModel.hasLocationLevelPermissions(const []),
        isFalse,
      );
      expect(
        PermissionItemModel.hasLocationLevelPermissions(const [
          PermissionItemModel(
            section: 'attendance',
            sectionLabel: 'Attendance',
            key: 'check_in_time',
            label: 'Check in',
            value: '09:00',
            sourceLevel: 'company',
          ),
        ]),
        isFalse,
      );
      expect(
        PermissionItemModel.hasLocationLevelPermissions(const [
          PermissionItemModel(
            section: 'attendance',
            sectionLabel: 'Attendance',
            key: 'check_in_time',
            label: 'Check in',
            value: '09:00',
            locationValue: '09:00',
            sourceLevel: 'location',
          ),
        ]),
        isTrue,
      );
    });

    test('location permission items overlay a schedule fallback', () {
      const base = LocationSchedule(
        checkIn: TimeOfDay(hour: 8, minute: 0),
        checkOut: TimeOfDay(hour: 17, minute: 0),
        graceMinutes: 5,
        workingDays: {'Monday'},
        maxBreakMinutes: 30,
      );
      final merged = LocationSchedule.fromPermissionItems(const [
        PermissionItemModel(
          section: 'attendance',
          sectionLabel: 'Attendance',
          key: 'check_in_time',
          label: 'Check in',
          locationValue: '10:00 AM',
        ),
        PermissionItemModel(
          section: 'break_timing',
          sectionLabel: 'Break',
          key: 'break_time',
          label: 'Break',
          locationValue: '90',
        ),
      ], fallback: base);

      expect(merged.checkIn, const TimeOfDay(hour: 10, minute: 0));
      expect(merged.checkOut, base.checkOut);
      expect(merged.graceMinutes, 5);
      expect(merged.workingDays, {'Monday'});
      expect(merged.maxBreakMinutes, 90);
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

    test('parses working_days lists from nested permission maps', () {
      final items = PermissionItemModel.listFromEnvelope({
        'working_days': {
          'working_days': ['monday', 'saturday'],
          'week_start_day': 'sunday',
          'hours_per_week': '35:00',
        },
      });
      expect(items, isNotEmpty);
      final schedule = LocationSchedule.fromPermissionItems(items);
      expect(schedule.workingDays, {'Monday', 'Saturday'});
      expect(schedule.weekStartDay, 'Sunday');
      expect(schedule.hoursPerWeek, '35:00');
    });

    test('locationOnly ignores company inherited values', () {
      const base = LocationSchedule(
        checkIn: TimeOfDay(hour: 8, minute: 0),
        graceMinutes: 10,
        workingDays: {'Monday', 'Saturday'},
        maxBreakMinutes: 30,
      );
      final merged = LocationSchedule.fromPermissionItems(
        const [
          PermissionItemModel(
            section: 'attendance',
            sectionLabel: 'Attendance',
            key: 'grace_period',
            label: 'Grace',
            value: '5',
            companyValue: '5',
            sourceLevel: 'company',
          ),
        ],
        locationOnly: true,
        fallback: base,
      );
      expect(merged.graceMinutes, 10);
      expect(merged.workingDays, {'Monday', 'Saturday'});
      expect(merged.maxBreakMinutes, 30);
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

    test('create payload always includes address and coordinates', () {
      final payload = ManagerLocationModel.createPayload(name: '  new office  ');
      expect(payload['name'], 'new office');
      expect(payload['title'], 'new office');
      expect(payload['address'], 'new office');
      expect(payload['latitude'], ManagerLocationModel.defaultLatitude);
      expect(payload['longitude'], ManagerLocationModel.defaultLongitude);
      expect(payload['radius_meters'], ManagerLocationModel.defaultRadiusMeters);
      expect(payload['city'], ManagerLocationModel.defaultCity);
      expect(payload['city_name'], ManagerLocationModel.defaultCity);
      expect(payload['country'], ManagerLocationModel.defaultCountry);
      expect(payload['country_name'], ManagerLocationModel.defaultCountry);
      expect(payload['timezone'], ManagerLocationModel.defaultTimezone);
      expect(payload['time_zone'], ManagerLocationModel.defaultTimezone);
      expect(payload['timezone_id'], ManagerLocationModel.defaultTimezone);
      expect(payload['timezone_name'], ManagerLocationModel.defaultTimezone);

      final withMap = ManagerLocationModel.createPayload(
        name: 'Warehouse B',
        address: 'Kurang, Islamabad',
        latitude: 33.68,
        longitude: 73.05,
        radiusMeters: 150,
        city: 'Islamabad',
        country: 'Pakistan',
        cityId: 9,
        countryId: 1,
        timezoneId: 4,
      );
      expect(withMap['address'], 'Kurang, Islamabad');
      expect(withMap['latitude'], 33.68);
      expect(withMap['longitude'], 73.05);
      expect(withMap['radius_meters'], 150);
      expect(withMap['city'], 'Islamabad');
      expect(withMap['city_id'], 9);
      expect(withMap['country_id'], 1);
      expect(withMap['timezone'], 4);
      expect(withMap['time_zone'], 4);
      expect(withMap['timezone_id'], 4);
      expect(withMap['time_zone_id'], 4);
      expect(withMap['timezone_name'], 'Asia/Karachi');
    });

    test('timezone id is extracted from objects and not from IANA names', () {
      expect(ManagerLocationModel.timezoneIdFrom('Europe/London'), isNull);
      expect(ManagerLocationModel.timezoneIdFrom(7), 7);
      expect(ManagerLocationModel.timezoneIdFrom('7'), 7);
      expect(
        ManagerLocationModel.timezoneIdFrom({'id': 12, 'name': 'Europe/London'}),
        12,
      );
    });

    test('timezone catalog matches IANA names used by create', () {
      const options = [
        TimezoneLookup(id: 1, label: 'UTC'),
        TimezoneLookup(id: 4, label: '(UTC+05:00) Asia/Karachi'),
        TimezoneLookup(id: 8, label: '(UTC+00:00) Europe/London'),
      ];
      expect(
        TimezoneLookup.matchId(options, iana: 'Europe/London'),
        8,
      );
      expect(
        TimezoneLookup.matchId(
          options,
          iana: 'Asia/Karachi',
          city: 'Islamabad',
          country: 'Pakistan',
        ),
        4,
      );
    });
  });
}
