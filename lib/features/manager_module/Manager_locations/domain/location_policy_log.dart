import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';

class LocationPolicyLog {
  LocationPolicyLog._();

  static void dump({
    required String sheet,
    required String phase,
    String? locationId,
    LocationSchedule? schedule,
    Map<String, Object?>? extra,
    bool? success,
    String? message,
    int? statusCode,
  }) {
    final buffer = StringBuffer()
      ..writeln('[LOCATION_POLICY]')
      ..writeln('sheet=$sheet')
      ..writeln('phase=${_phaseLabel(phase)}')
      ..writeln('locationId=${locationId ?? "n/a"}');
    if (success != null) buffer.writeln('response=${success ? "success" : "failed"}');
    if (statusCode != null) buffer.writeln('statusCode=$statusCode');
    if (message != null && message.trim().isNotEmpty) {
      buffer.writeln('message=$message');
    }
    if (schedule != null) {
      buffer.writeln('checkIn=${_time(schedule.checkIn)}');
      buffer.writeln('checkOut=${_time(schedule.checkOut)}');
      buffer.writeln('graceMinutes=${schedule.graceMinutes}');
      buffer.writeln('break=${schedule.breakLabel}');
      buffer.writeln('breakTracking=${schedule.breakLocationTracking}');
      buffer.writeln('workingDays=${schedule.workingDays.join(",")}');
      buffer.writeln('weekStart=${schedule.weekStartDay}');
      buffer.writeln('hoursDay=${schedule.hoursPerDay}');
      buffer.writeln('hoursWeek=${schedule.hoursPerWeek}');
    }
    extra?.forEach((key, value) {
      if (value != null) buffer.writeln('$key=$value');
    });
    debugPrint(buffer.toString().trimRight());
  }

  static String _phaseLabel(String phase) {
    switch (phase) {
      case 'current':
        return 'current data';
      case 'changed':
        return 'changed data';
      case 'fetched':
        return 'data fetched';
      case 'response':
        return 'response';
      default:
        return phase;
    }
  }

  static String _time(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
