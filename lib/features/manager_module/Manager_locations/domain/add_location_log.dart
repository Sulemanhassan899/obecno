import 'package:flutter/foundation.dart';

/// Debug console logs for the add-location module.
///
/// Default / errors print in red. Success prints in green.
class AddLocationLog {
  AddLocationLog._();

  static const _red = '\x1B[31m';
  static const _green = '\x1B[32m';
  static const _reset = '\x1B[0m';

  static const createApiNeeds =
      'name, address, latitude, longitude, radius_meters, '
      'city, country, timezone_id';

  static const updatePinApiNeeds =
      'name, address, latitude, longitude, radius_meters, '
      'allow_checkin_anywhere';

  static const membersApiNeeds = 'location_id, employee_ids';

  static const scheduleApiNeeds =
      'check_in, check_out, grace_minutes, working_days, week_start_day, '
      'hours_per_day, hours_per_week, max_break_minutes, '
      'break_location_tracking';

  static void dump({
    required String sheet,
    String phase = 'info',
    String? api,
    Object? apiNeeds,
    Object? userSending,
    bool? success,
    int? statusCode,
    String? message,
    Object? fieldErrors,
    Map<String, Object?>? extra,
  }) {
    if (kReleaseMode) return;

    final isSuccess = success == true;
    final color = isSuccess ? _green : _red;
    final buffer = StringBuffer()
      ..writeln('[ADD LOCATION]')
      ..writeln('sheet=$sheet')
      ..writeln('phase=$phase');
    if (apiNeeds != null) buffer.writeln('apiNeeds=$apiNeeds');
    if (userSending != null) buffer.writeln('userSending=$userSending');
    if (api != null && api.trim().isNotEmpty) buffer.writeln('api=$api');
    if (success != null) {
      buffer.writeln('result=${isSuccess ? 'SUCCESS' : 'ERROR'}');
    }
    if (statusCode != null) buffer.writeln('statusCode=$statusCode');
    if (message != null && message.trim().isNotEmpty) {
      buffer.writeln('message=$message');
    }
    if (fieldErrors != null) buffer.writeln('fieldErrors=$fieldErrors');
    extra?.forEach((key, value) {
      if (value != null) buffer.writeln('$key=$value');
    });

    for (final line in buffer.toString().trimRight().split('\n')) {
      debugPrint('$color$line$_reset');
    }
  }
}
