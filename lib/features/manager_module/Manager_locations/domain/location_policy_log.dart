import 'package:flutter/material.dart';
import 'package:obecno/features/manager_module/Manager_locations/data/models/location_schedule.dart';
import 'package:obecno/features/manager_module/Manager_locations/domain/add_location_log.dart';

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
    String? api,
    Object? apiNeeds,
    Object? userSending,
    Object? fieldErrors,
  }) {
    AddLocationLog.dump(
      sheet: sheet,
      phase: _phaseLabel(phase),
      api: api,
      apiNeeds: apiNeeds,
      userSending: userSending ??
          ((phase == 'current' || phase == 'changed') && schedule != null
              ? schedule.toJson()
              : null),
      success: success,
      statusCode: statusCode,
      message: message,
      fieldErrors: fieldErrors,
      extra: {
        'locationId': locationId ?? 'n/a',
        if (schedule != null) ...{
          'checkIn': _time(schedule.checkIn),
          'checkOut': _time(schedule.checkOut),
          'graceMinutes': schedule.graceMinutes,
          'break': schedule.breakLabel,
          'breakTracking': schedule.breakLocationTracking,
          'workingDays': schedule.workingDays.join(','),
          'weekStart': schedule.weekStartDay,
          'hoursDay': schedule.hoursPerDay,
          'hoursWeek': schedule.hoursPerWeek,
        },
        ...?extra,
      },
    );
  }

  static String _phaseLabel(String phase) {
    switch (phase) {
      case 'open':
        return 'sheet open';
      case 'current':
        return 'current data';
      case 'changed':
        return 'user sending';
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
