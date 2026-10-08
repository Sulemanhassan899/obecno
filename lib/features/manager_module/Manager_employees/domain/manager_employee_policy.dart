import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:obecno/features/auth/data/models/permission_item_model.dart';

class ManagerEmployeePolicy {
  const ManagerEmployeePolicy({
    this.checkInTime,
    this.checkOutTime,
    this.gracePeriod,
    this.breakTime,
    this.breakLocationTracking = true,
    this.workingDays,
    this.locationName,
  });

  final String? checkInTime;
  final String? checkOutTime;
  final String? gracePeriod;
  final String? breakTime;
  final bool breakLocationTracking;
  final String? workingDays;
  final String? locationName;

  TimeOfDay get checkIn =>
      parseTime(checkInTime) ?? const TimeOfDay(hour: 8, minute: 0);

  TimeOfDay get checkOut =>
      parseTime(checkOutTime) ?? const TimeOfDay(hour: 17, minute: 0);

  int get graceMinutes => parseMinutes(gracePeriod) ?? 5;

  String get breakLabel {
    final minutes = parseMinutes(breakTime) ?? 60;
    return '${minutes.toString().padLeft(2, '0')}:00 mins';
  }

  factory ManagerEmployeePolicy.fromItems(List<PermissionItemModel> items) {
    String? value(String section, String key) {
      PermissionItemModel? match;
      for (final item in items) {
        if (item.section == section && item.key == key) {
          match = item;
          break;
        }
      }
      if (match == null) {
        for (final item in items) {
          if (item.key == key) {
            match = item;
            break;
          }
        }
      }
      if (match == null) return null;
      final override = match.employeeValue?.trim();
      if (override != null && override.isNotEmpty) return override;
      return match.value;
    }

    String? locationName;
    for (final item in items) {
      final name = item.locationName?.trim();
      if (name != null && name.isNotEmpty) {
        locationName = name;
        break;
      }
    }

    final tracking =
        value('attendance', 'break_location_tracking') ??
        value('break_timing', 'break_location_tracking');

    return ManagerEmployeePolicy(
      checkInTime: value('attendance', 'check_in_time'),
      checkOutTime: value('attendance', 'check_out_time'),
      gracePeriod: value('attendance', 'grace_period'),
      breakTime:
          value('attendance', 'break_time') ??
          value('break_timing', 'break_time'),
      breakLocationTracking: tracking == null
          ? true
          : tracking.trim().toLowerCase() != '0' &&
                tracking.trim().toLowerCase() != 'false' &&
                tracking.trim().toLowerCase() != 'off',
      workingDays: value('attendance', 'working_days'),
      locationName: locationName,
    );
  }

  factory ManagerEmployeePolicy.fromSchedule(Map<String, dynamic> schedule) {
    String? read(List<String> keys) {
      for (final key in keys) {
        final value = schedule[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    final tracking = read(const ['break_location_tracking', 'track_location']);

    return ManagerEmployeePolicy(
      checkInTime: read(const ['check_in', 'check_in_time']),
      checkOutTime: read(const ['check_out', 'check_out_time']),
      gracePeriod: read(const ['grace_minutes', 'grace_period']),
      breakTime: read(const ['max_break_minutes', 'break_time', 'max_break']),
      breakLocationTracking: tracking == null
          ? true
          : tracking.toLowerCase() != '0' &&
                tracking.toLowerCase() != 'false' &&
                tracking.toLowerCase() != 'off',
      workingDays: _workingDaysText(schedule['working_days']) ??
          read(const ['working_days']),
    );
  }

  bool get hasTimings =>
      (checkInTime != null && checkInTime!.trim().isNotEmpty) ||
      (checkOutTime != null && checkOutTime!.trim().isNotEmpty);

  static TimeOfDay? parseTime(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    final ampm = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?(?::(\d{2}))?\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (ampm != null) {
      var hour = int.parse(ampm.group(1)!);
      final minute = int.parse(ampm.group(2) ?? '0');
      final period = ampm.group(4)!.toUpperCase();
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static int? parseMinutes(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;
    // Portal display + select values for "No grace".
    if (value == 'no-grace' ||
        value == 'no grace' ||
        value == 'none' ||
        value == 'off' ||
        value == 'no') {
      return 0;
    }
    final leading = RegExp(r'^(\d+)').firstMatch(value);
    if (leading != null) return int.tryParse(leading.group(1)!);
    return null;
  }

  static Map<String, dynamic> _permissionItem(
    String section,
    String key,
    String value,
  ) {
    return {
      'section': section,
      'key': key,
      'value': value,
      'employee_value': value,
    };
  }

  /// HH:mm for machine-facing bodies; keeps AM/PM display labels as-is.
  static String _hhmmLabel(String label) {
    final time = parseTime(label);
    if (time == null) return label;
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Portal location/employee attendance form values:
  /// `no-grace`, `5-min`, `10-min`, `15-min`, `30-min`.
  static String graceWireValue(int graceMinutes) {
    final minutes = graceMinutes < 0 ? 0 : graceMinutes;
    if (minutes == 0) return 'no-grace';
    return '$minutes-min';
  }

  /// Human label matching GET employee permissions (`5 minutes`, `No grace`).
  static String graceDisplayValue(int graceMinutes) {
    final minutes = graceMinutes < 0 ? 0 : graceMinutes;
    if (minutes == 0) return 'No grace';
    return '$minutes minutes';
  }

  static String _graceLabel(int graceMinutes) => graceWireValue(graceMinutes);

  /// Check-in / check-out only — grace is written separately.
  static Map<String, dynamic> timingPermissionPayload({
    required String checkInLabel,
    required String checkOutLabel,
    required int graceMinutes,
  }) {
    final checkInValue = _hhmmLabel(checkInLabel);
    final checkOutValue = _hhmmLabel(checkOutLabel);
    final graceValue = _graceLabel(graceMinutes);
    final attendance = {
      'check_in_time': checkInValue,
      'check_out_time': checkOutValue,
      'grace_period': graceValue,
      'grace_minutes': graceMinutes < 0 ? 0 : graceMinutes,
    };
    final employeeSetting = {
      'check_in_time': checkInValue,
      'check_out_time': checkOutValue,
    };
    return {
      'field': 'check_in_time',
      'value': checkInValue,
      'section': 'attendance',
      'permission_section': 'attendance',
      'write_fields': const ['check_in_time', 'check_out_time'],
      'employee_setting': employeeSetting,
      'settings': {'attendance': attendance},
      'permission_items': [
        _permissionItem('attendance', 'check_in_time', checkInLabel),
        _permissionItem('attendance', 'check_out_time', checkOutLabel),
      ],
      'permissions': {'attendance': attendance},
      'attendance': attendance,
    };
  }

  /// Candidate wire values for employee `grace_period` (portal accepts several).
  static List<Object> graceWireCandidates(int graceMinutes) {
    final minutes = graceMinutes < 0 ? 0 : graceMinutes;
    return [
      minutes, // OpenAPI example: number
      graceDisplayValue(minutes), // GET shape: "5 minutes" / "No grace"
      graceWireValue(minutes), // select: no-grace / 5-min
      if (minutes == 0) '0 minutes',
      if (minutes == 0) '0',
    ];
  }

  static Map<String, dynamic> gracePermissionPayload(Object graceValue) {
    return {
      'field': 'grace_period',
      'value': graceValue,
      'section': 'attendance',
      'permission_section': 'attendance',
      'is_override': true,
      'source_level': 'employee',
      'write_fields': const ['grace_period'],
      'employee_setting': {'grace_period': graceValue},
      'settings': {
        'attendance': {'grace_period': graceValue},
      },
      'permissions': {
        'attendance': {'grace_period': graceValue},
      },
      'attendance': {'grace_period': graceValue},
      'permission_items': [
        _permissionItem('attendance', 'grace_period', graceValue.toString()),
      ],
    };
  }

  static Map<String, dynamic> breakPermissionPayload({
    required String breakLabel,
    required bool trackLocation,
  }) {
    final breakMinutes = parseMinutes(breakLabel) ?? 60;
    // Employee permissions only expose break_time on the portal Break timing
    // tab. break_location_tracking returns "That field cannot be edited here."
    final employeeSetting = {'break_time': breakMinutes};
    final attendance = {
      'break_time': breakMinutes,
      'break_location_tracking': trackLocation,
    };
    return {
      'field': 'break_time',
      'value': breakMinutes,
      'section': 'attendance',
      'permission_section': 'attendance',
      'write_fields': const ['break_time'],
      'employee_setting': employeeSetting,
      'settings': {'attendance': attendance, 'break_timing': attendance},
      'permission_items': [
        _permissionItem('attendance', 'break_time', breakLabel),
      ],
      'permissions': {'attendance': attendance, 'break_timing': attendance},
      'attendance': attendance,
      'break_timing': attendance,
    };
  }

  /// Manager API §5.4 — working days live on employee schedule, not
  /// `/permissions` (portal permissions/field returns Saved but never
  /// leaves `source_level=company` for this field).
  static Map<String, dynamic> workingDaysSchedulePayload({
    required Iterable<String> workingDays,
    required String weekStartDay,
    required String hoursPerDay,
    required String hoursPerWeek,
    required bool workingWeekEnabled,
    String? checkInHms,
    String? checkOutHms,
    int? graceMinutes,
    int? maxBreakMinutes,
    bool? breakLocationTracking,
  }) {
    final days = _orderedLowerDayNames(workingDays);
    final start = weekStartDay.trim().toLowerCase();
    final body = <String, dynamic>{
      'working_days': days,
      'week_start_day': start.isEmpty ? 'monday' : start,
      'hours_per_day': hoursPerDay,
      'hours_per_week': hoursPerWeek,
      'working_week_enabled': workingWeekEnabled,
      if (checkInHms != null && checkInHms.trim().isNotEmpty)
        'check_in': checkInHms,
      if (checkOutHms != null && checkOutHms.trim().isNotEmpty)
        'check_out': checkOutHms,
      if (graceMinutes != null) 'grace_minutes': graceMinutes,
      if (maxBreakMinutes != null) 'max_break_minutes': maxBreakMinutes,
      if (breakLocationTracking != null)
        'break_location_tracking': breakLocationTracking,
    };
    return {
      ...body,
      'schedule': Map<String, dynamic>.from(body),
    };
  }

  /// Portal Working days panel POSTs to `/employees/permissions/field` with:
  /// `field=working_days` and `value=JSON.stringify(["mon","tue","wed"])`
  /// (Thursday code is `thr`).
  static List<String> workingDayCodes(Iterable<String> workingDays) {
    const dayOrder = <(String, String)>[
      ('monday', 'mon'),
      ('tuesday', 'tue'),
      ('wednesday', 'wed'),
      ('thursday', 'thr'),
      ('friday', 'fri'),
      ('saturday', 'sat'),
      ('sunday', 'sun'),
    ];
    final selected = {
      for (final day in workingDays)
        if (day.trim().isNotEmpty) day.trim().toLowerCase(),
    };
    return [
      for (final entry in dayOrder)
        if (selected.contains(entry.$1)) entry.$2,
    ];
  }

  /// Exact portal wire value: `["mon","tue","wed"]` as a JSON string.
  static String workingDaysFieldValue(Iterable<String> workingDays) {
    return jsonEncode(workingDayCodes(workingDays));
  }

  /// GET `/manager/employees/{id}/permissions` returns attendance.working_days
  /// as a Title Case list, e.g. `"Monday, Tuesday, Wednesday, Thursday, Friday"`.
  static String workingDaysDisplayValue(Iterable<String> workingDays) {
    return _orderedTitleDayNames(workingDays).join(', ');
  }

  static List<String> _orderedTitleDayNames(Iterable<String> workingDays) {
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final selected = {
      for (final day in workingDays)
        if (day.trim().isNotEmpty) day.trim().toLowerCase(),
    };
    return [
      for (final name in dayNames)
        if (selected.contains(name.toLowerCase())) name,
    ];
  }

  /// Manager employee permissions API (user-provided contract):
  /// PUT|PATCH `/manager/employees/{id}/permissions`
  /// with `section: attendance` and Title Case `working_days` display value.
  ///
  /// Location portal uses a separate `working_days` section + day codes; that
  /// path does not create employee overrides.
  static List<Map<String, dynamic>> workingDaysPermissionPayloads({
    required Iterable<String> workingDays,
    required String weekStartDay,
    required String hoursPerDay,
    required String hoursPerWeek,
    required bool workingWeekEnabled,
  }) {
    final display = workingDaysDisplayValue(workingDays);
    final codes = workingDayCodes(workingDays);
    final codesJson = workingDaysFieldValue(workingDays);
    final startDay = weekStartDay.trim().toLowerCase();

    Map<String, dynamic> attendanceBody({
      required Object value,
      required Object settingValue,
      String forceMethod = 'PUT',
    }) {
      final setting = <String, dynamic>{'working_days': settingValue};
      return {
        'field': 'working_days',
        'value': value,
        'section': 'attendance',
        'permission_section': 'attendance',
        'force_method': forceMethod,
        'is_override': true,
        'source_level': 'employee',
        'also_legacy_post': true,
        'write_fields': const ['working_days'],
        'employee_setting': setting,
        'attendance': setting,
        'settings': {'attendance': setting},
        'permissions': {'attendance': setting},
      };
    }

    return [
      // Primary: matches GET attendance.working_days display string.
      attendanceBody(value: display, settingValue: display, forceMethod: 'PUT'),
      attendanceBody(
        value: display,
        settingValue: display,
        forceMethod: 'PATCH',
      ),
      // Secondary: day-code shapes some builds accept.
      attendanceBody(
        value: codesJson,
        settingValue: codesJson,
        forceMethod: 'PUT',
      ),
      attendanceBody(
        value: codes.join(','),
        settingValue: codes,
        forceMethod: 'PUT',
      ),
      // Week meta (best-effort; some builds reject these on employee).
      {
        'field': 'week_start_day',
        'value': startDay,
        'section': 'attendance',
        'permission_section': 'attendance',
        'force_method': 'PUT',
        'also_legacy_post': true,
        'write_fields': const ['week_start_day'],
        'employee_setting': {'week_start_day': startDay},
        'attendance': {'week_start_day': startDay},
        'settings': {
          'attendance': {'week_start_day': startDay},
        },
        'permissions': {
          'attendance': {'week_start_day': startDay},
        },
      },
      {
        'field': 'hours_per_day',
        'value': hoursPerDay,
        'section': 'attendance',
        'permission_section': 'attendance',
        'force_method': 'PUT',
        'also_legacy_post': true,
        'write_fields': const ['hours_per_day'],
        'employee_setting': {'hours_per_day': hoursPerDay},
        'attendance': {'hours_per_day': hoursPerDay},
        'settings': {
          'attendance': {'hours_per_day': hoursPerDay},
        },
        'permissions': {
          'attendance': {'hours_per_day': hoursPerDay},
        },
      },
      {
        'field': 'hours_per_week',
        'value': hoursPerWeek,
        'section': 'attendance',
        'permission_section': 'attendance',
        'force_method': 'PUT',
        'also_legacy_post': true,
        'write_fields': const ['hours_per_week'],
        'employee_setting': {'hours_per_week': hoursPerWeek},
        'attendance': {'hours_per_week': hoursPerWeek},
        'settings': {
          'attendance': {'hours_per_week': hoursPerWeek},
        },
        'permissions': {
          'attendance': {'hours_per_week': hoursPerWeek},
        },
      },
      {
        'field': 'working_week_enabled',
        'value': workingWeekEnabled,
        'section': 'attendance',
        'permission_section': 'attendance',
        'force_method': 'PUT',
        'also_legacy_post': true,
        'write_fields': const ['working_week_enabled'],
        'employee_setting': {'working_week_enabled': workingWeekEnabled},
        'attendance': {'working_week_enabled': workingWeekEnabled},
        'settings': {
          'attendance': {'working_week_enabled': workingWeekEnabled},
        },
        'permissions': {
          'attendance': {'working_week_enabled': workingWeekEnabled},
        },
      },
    ];
  }

  static Map<String, dynamic> workingDaysPermissionPayload({
    required Iterable<String> workingDays,
    required String weekStartDay,
    required String hoursPerDay,
    required String hoursPerWeek,
    required bool workingWeekEnabled,
  }) {
    return workingDaysPermissionPayloads(
      workingDays: workingDays,
      weekStartDay: weekStartDay,
      hoursPerDay: hoursPerDay,
      hoursPerWeek: hoursPerWeek,
      workingWeekEnabled: workingWeekEnabled,
    ).first;
  }

  static List<String> _orderedLowerDayNames(Iterable<String> workingDays) {
    const dayNames = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final selected = {
      for (final day in workingDays)
        if (day.trim().isNotEmpty) day.trim().toLowerCase(),
    };
    return [
      for (final name in dayNames)
        if (selected.contains(name)) name,
    ];
  }
}

String? _workingDaysText(dynamic raw) {
  if (raw == null) return null;
  if (raw is List) {
    final days = raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return days.isEmpty ? null : days.join(', ');
  }
  final text = raw.toString().trim();
  return text.isEmpty ? null : text;
}
