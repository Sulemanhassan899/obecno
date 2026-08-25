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

    final tracking = value('attendance', 'break_location_tracking') ??
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

    final tracking = read(const [
      'break_location_tracking',
      'track_location',
    ]);

    return ManagerEmployeePolicy(
      checkInTime: read(const ['check_in', 'check_in_time']),
      checkOutTime: read(const ['check_out', 'check_out_time']),
      gracePeriod: read(const ['grace_minutes', 'grace_period']),
      breakTime: read(const [
        'max_break_minutes',
        'break_time',
        'max_break',
      ]),
      breakLocationTracking: tracking == null
          ? true
          : tracking.toLowerCase() != '0' &&
                tracking.toLowerCase() != 'false' &&
                tracking.toLowerCase() != 'off',
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
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (ampm != null) {
      var hour = int.parse(ampm.group(1)!);
      final minute = int.parse(ampm.group(2)!);
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
    return TimeOfDay(hour: hour, minute: minute);
  }

  static int? parseMinutes(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;
    final leading = RegExp(r'^(\d+)').firstMatch(value);
    if (leading != null) return int.tryParse(leading.group(1)!);
    return null;
  }
}
