import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Writes manager-applied punch times into Clock SharedPreferences so the
/// Clock button does not stay on a stale open check-in after edit/restart.
class ClockLocalSessionSync {
  ClockLocalSessionSync._();

  static Future<void> applyManagerSave({
    required String? userId,
    required DateTime day,
    required TimeOfDay checkIn,
    TimeOfDay? checkOut,
    String? locationName,
  }) async {
    final id = (userId ?? '').trim();
    if (id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final dayKey =
        'clock_events_${id}_${day.year}-${day.month}-${day.day}';
    final activeKey = 'clock_events_${id}_active';
    final location = (locationName ?? '').trim();

    DateTime at(TimeOfDay t) =>
        DateTime(day.year, day.month, day.day, t.hour, t.minute);

    final events = <AttendanceEvent>[
      AttendanceEvent(
        id: 'mgr_checkIn_${at(checkIn).microsecondsSinceEpoch}',
        type: AttendanceEventType.checkIn,
        time: at(checkIn),
        location: location.isEmpty ? null : location,
        isValidLocation: true,
      ),
      if (checkOut != null)
        AttendanceEvent(
          id: 'mgr_checkOut_${at(checkOut).microsecondsSinceEpoch}',
          type: AttendanceEventType.checkOut,
          time: at(checkOut),
          location: location.isEmpty ? null : location,
          isValidLocation: true,
        ),
    ];

    final encoded = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(dayKey, encoded);
    // Closed day → empty active (Check In). Open day → active = open session.
    if (checkOut != null) {
      await prefs.setString(activeKey, '[]');
    } else {
      await prefs.setString(activeKey, encoded);
    }
  }
}
