import 'package:obecno/features/clock/location_flags/data/models/location_flag_record.dart';

class LocationCycleVerdict {
  const LocationCycleVerdict({
    required this.status,
    required this.requiresServerSync,
  });

  final LocationFlagUiStatus status;
  final bool requiresServerSync;
}

class PolicyDayWindow {
  const PolicyDayWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get duration {
    final span = end.difference(start);
    return span.isNegative ? Duration.zero : span;
  }

  PolicyDayWindow padded({
    Duration before = const Duration(hours: 1),
    Duration after = const Duration(hours: 1),
  }) {
    return PolicyDayWindow(
      start: start.subtract(before),
      end: end.add(after),
    );
  }
}

class LocationFlagEvaluator {
  LocationFlagEvaluator._();

  static const int flagIntervalMinutes = 5;
  static const Duration flagInterval = Duration(minutes: flagIntervalMinutes);
  static const int flagsPerCycle = 60 ~/ flagIntervalMinutes;

  static bool isInsideRadius(double distance, double allowedRadius) {
    return distance <= allowedRadius;
  }

  static int flagNumberFor(DateTime at) {
    final minute = at.minute;
    if (minute < 0) return 1;
    return (minute ~/ flagIntervalMinutes) + 1;
  }

  static DateTime cycleStartFor(DateTime at) {
    return DateTime(at.year, at.month, at.day, at.hour);
  }

  static DateTime flagSlotStart(DateTime at) {
    final start = cycleStartFor(at);
    return start.add(
      Duration(minutes: (flagNumberFor(at) - 1) * flagIntervalMinutes),
    );
  }

  static DateTime nextAlignedCheck(DateTime now) {
    final slot = flagSlotStart(now);
    if (now.isBefore(slot)) return slot;
    return slot.add(flagInterval);
  }

  static String calendarDate(DateTime at) {
    final y = at.year.toString().padLeft(4, '0');
    final m = at.month.toString().padLeft(2, '0');
    final d = at.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String cycleIdFor({
    required String employeeId,
    required DateTime at,
  }) {
    final hour = at.hour.toString().padLeft(2, '0');
    return '$employeeId|${calendarDate(at)}|$hour';
  }

  static LocationCycleVerdict evaluate({
    required bool checkInStatus,
    required List<LocationFlagObservation> observations,
  }) {
    if (!checkInStatus) {
      return const LocationCycleVerdict(
        status: LocationFlagUiStatus.notCheckedIn,
        requiresServerSync: false,
      );
    }

    final working =
        observations.where((o) => o.isWorkingTime).toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    final hasFalse = working.any((o) => o.inside == false);
    final latest = working.isEmpty ? null : working.last;
    final latestInside = latest?.inside;

    final LocationFlagUiStatus status;
    if (latestInside == true) {
      status = LocationFlagUiStatus.inOffice;
    } else if (latestInside == false) {
      status = LocationFlagUiStatus.locationIssue;
    } else {
      status = LocationFlagUiStatus.locationUnavailable;
    }

    return LocationCycleVerdict(
      status: status,
      requiresServerSync: hasFalse,
    );
  }

  static List<bool?> cycleFlags(List<LocationFlagObservation> observations) {
    final flags = List<bool?>.filled(flagsPerCycle, null);
    for (final observation in observations) {
      final index = flagNumberFor(observation.at) - 1;
      if (index < 0 || index >= flagsPerCycle) continue;
      flags[index] = observation.inside;
    }
    return flags;
  }

  static ({int hour, int minute})? parsePolicyTime(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '—' || trimmed == '-') return null;

    final twelve = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])$',
    ).firstMatch(trimmed);
    if (twelve != null) {
      var hour = int.tryParse(twelve.group(1)!);
      final minute = int.tryParse(twelve.group(2)!);
      if (hour == null || minute == null) return null;
      if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return null;
      final isPm = twelve.group(3)!.toUpperCase() == 'PM';
      hour = hour == 12 ? (isPm ? 12 : 0) : (isPm ? hour + 12 : hour);
      return (hour: hour, minute: minute);
    }

    final twentyFour = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?$',
    ).firstMatch(trimmed);
    if (twentyFour != null) {
      final hour = int.tryParse(twentyFour.group(1)!);
      final minute = int.tryParse(twentyFour.group(2)!);
      if (hour == null || minute == null) return null;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return (hour: hour, minute: minute);
    }

    final iso = DateTime.tryParse(trimmed);
    if (iso != null) {
      return (hour: iso.hour, minute: iso.minute);
    }

    return null;
  }

  static PolicyDayWindow policyWindow({
    required DateTime day,
    String? checkInRaw,
    String? checkOutRaw,
    int fallbackStartHour = 9,
    int fallbackStartMinute = 0,
    int fallbackEndHour = 18,
    int fallbackEndMinute = 0,
  }) {
    final startParts =
        parsePolicyTime(checkInRaw) ??
        (hour: fallbackStartHour, minute: fallbackStartMinute);
    final endParts =
        parsePolicyTime(checkOutRaw) ??
        (hour: fallbackEndHour, minute: fallbackEndMinute);

    final start = DateTime(
      day.year,
      day.month,
      day.day,
      startParts.hour,
      startParts.minute,
    );
    var end = DateTime(
      day.year,
      day.month,
      day.day,
      endParts.hour,
      endParts.minute,
    );
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }
    return PolicyDayWindow(start: start, end: end);
  }


  static String formatClock(
    DateTime time, {
    bool compact = false,
    bool showPeriod = true,
  }) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    if (!showPeriod) {
      if (compact && time.minute == 0) return '$hour';
      return '$hour:$minute';
    }
    if (compact && time.minute == 0) {
      return '$hour ${ampm.toLowerCase()}';
    }
    if (compact) {
      return '$hour:$minute ${ampm.toLowerCase()}';
    }
    return '$hour:$minute $ampm';
  }
}
