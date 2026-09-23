import 'package:obecno/features/clock/location_flags/data/models/location_flag_record.dart';
import 'package:obecno/features/clock/location_flags/domain/location_flag_evaluator.dart';

enum LocationTimelineKind { inside, outside, unknown, onBreak }

class LocationTimelineSegment {
  const LocationTimelineSegment({
    required this.start,
    required this.end,
    required this.kind,
  });

  final DateTime start;
  final DateTime end;
  final LocationTimelineKind kind;

  Duration get duration => end.difference(start);
}

class LocationOutsideInterval {
  const LocationOutsideInterval({
    required this.wentOutsideAt,
    this.returnedAt,
  });

  final DateTime wentOutsideAt;
  final DateTime? returnedAt;
}

enum LocationTimelineMarkKind { start, leftOffice, returned, end }

class LocationTimelineAxisMark {
  const LocationTimelineAxisMark({
    required this.at,
    required this.kind,
  });

  final DateTime at;
  final LocationTimelineMarkKind kind;
}

class LocationFlagTimeline {
  LocationFlagTimeline._();

  static List<LocationTimelineSegment> segments({
    required PolicyDayWindow window,
    required List<LocationFlagObservation> observations,
    DateTime? until,
    bool fillMissing = false,
  }) {
    final cutoff = until ?? window.end;
    if (!cutoff.isAfter(window.start)) return const [];

    final bySlot = <int, LocationFlagObservation>{};
    for (final observation in observations) {
      final slot = LocationFlagEvaluator.flagSlotStart(observation.at);
      bySlot[slot.millisecondsSinceEpoch] = observation;
    }

    final segments = <LocationTimelineSegment>[];
    var cursor = LocationFlagEvaluator.flagSlotStart(window.start);
    if (cursor.isBefore(window.start)) {
      cursor = cursor.add(LocationFlagEvaluator.flagInterval);
    }

    while (cursor.isBefore(cutoff) && !cursor.isAfter(window.end)) {
      final slotEnd = cursor.add(LocationFlagEvaluator.flagInterval);
      final start = _clamp(cursor, window.start, window.end);
      final end = _clamp(
        slotEnd.isAfter(cutoff) ? cutoff : slotEnd,
        window.start,
        window.end,
      );
      if (!end.isAfter(start)) {
        cursor = slotEnd;
        continue;
      }

      final observation = bySlot[cursor.millisecondsSinceEpoch];
      LocationTimelineKind? kind;
      if (observation != null) {
        kind = _kindFor(observation);
      } else if (fillMissing) {
        kind = LocationTimelineKind.unknown;
      }

      if (kind != null) {
        if (segments.isNotEmpty &&
            segments.last.kind == kind &&
            !segments.last.end.isBefore(start)) {
          segments[segments.length - 1] = LocationTimelineSegment(
            start: segments.last.start,
            end: end.isAfter(segments.last.end) ? end : segments.last.end,
            kind: kind,
          );
        } else {
          segments.add(
            LocationTimelineSegment(start: start, end: end, kind: kind),
          );
        }
      }

      cursor = slotEnd;
    }

    return segments;
  }

  static List<LocationOutsideInterval> outsideIntervals({
    required List<LocationFlagObservation> observations,
  }) {
    final working =
        observations.where((o) => o.isWorkingTime && o.inside != null).toList()
          ..sort((a, b) => a.at.compareTo(b.at));

    final intervals = <LocationOutsideInterval>[];
    DateTime? outsideStart;

    for (final observation in working) {
      if (observation.inside == false) {
        outsideStart ??=
            LocationFlagEvaluator.flagSlotStart(observation.at);
        continue;
      }
      if (observation.inside == true && outsideStart != null) {
        intervals.add(
          LocationOutsideInterval(
            wentOutsideAt: outsideStart,
            returnedAt: LocationFlagEvaluator.flagSlotStart(observation.at),
          ),
        );
        outsideStart = null;
      }
    }

    if (outsideStart != null) {
      intervals.add(LocationOutsideInterval(wentOutsideAt: outsideStart));
    }
    return intervals;
  }

  /// Start/end of the window plus actual leave/return times — never filler ticks.
  static List<LocationTimelineAxisMark> axisMarks({
    required PolicyDayWindow window,
    required List<LocationOutsideInterval> intervals,
  }) {
    final marks = <LocationTimelineAxisMark>[
      LocationTimelineAxisMark(
        at: window.start,
        kind: LocationTimelineMarkKind.start,
      ),
    ];

    for (final interval in intervals) {
      if (!_sameClockMinute(interval.wentOutsideAt, window.start) &&
          !_sameClockMinute(interval.wentOutsideAt, window.end) &&
          !interval.wentOutsideAt.isBefore(window.start) &&
          !interval.wentOutsideAt.isAfter(window.end)) {
        marks.add(
          LocationTimelineAxisMark(
            at: interval.wentOutsideAt,
            kind: LocationTimelineMarkKind.leftOffice,
          ),
        );
      }
      final returned = interval.returnedAt;
      if (returned != null &&
          !_sameClockMinute(returned, window.start) &&
          !_sameClockMinute(returned, window.end) &&
          !returned.isBefore(window.start) &&
          !returned.isAfter(window.end)) {
        marks.add(
          LocationTimelineAxisMark(
            at: returned,
            kind: LocationTimelineMarkKind.returned,
          ),
        );
      }
    }

    marks.add(
      LocationTimelineAxisMark(
        at: window.end,
        kind: LocationTimelineMarkKind.end,
      ),
    );
    return marks;
  }

  static bool _sameClockMinute(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }

  static LocationTimelineKind _kindFor(LocationFlagObservation observation) {
    if (observation.breakStatus && observation.checkInStatus) {
      return LocationTimelineKind.onBreak;
    }
    if (observation.inside == true) return LocationTimelineKind.inside;
    if (observation.inside == false) return LocationTimelineKind.outside;
    return LocationTimelineKind.unknown;
  }

  static DateTime _clamp(DateTime value, DateTime start, DateTime end) {
    if (value.isBefore(start)) return start;
    if (value.isAfter(end)) return end;
    return value;
  }
}
