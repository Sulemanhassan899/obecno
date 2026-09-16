import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';

class AttendanceSummary {
  final DateTime? firstCheckIn;
  final DateTime? lastCheckOut;
  final Duration totalWorkingDuration;
  final Duration totalBreakDuration;
  final bool isCheckedIn;
  final bool isOnBreak;
  final DateTime? openSessionStart;

  const AttendanceSummary({
    required this.firstCheckIn,
    required this.lastCheckOut,
    required this.totalWorkingDuration,
    required this.totalBreakDuration,
    required this.isCheckedIn,
    required this.isOnBreak,
    required this.openSessionStart,
  });

  static const empty = AttendanceSummary(
    firstCheckIn: null,
    lastCheckOut: null,
    totalWorkingDuration: Duration.zero,
    totalBreakDuration: Duration.zero,
    isCheckedIn: false,
    isOnBreak: false,
    openSessionStart: null,
  );

  Duration liveWorkingDuration({DateTime? now}) {
    return AttendanceFormat.workedDuration(
      start: firstCheckIn,
      end: isOnBreak
          ? openSessionStart
          : isCheckedIn
          ? (now ?? DateTime.now())
          : lastCheckOut,
      breaks: totalBreakDuration,
    );
  }

  Duration liveBreakDuration({DateTime? now}) {
    if (!isOnBreak || openSessionStart == null) {
      return totalBreakDuration;
    }
    final current = now ?? DateTime.now();
    return totalBreakDuration + current.difference(openSessionStart!);
  }
}

class AttendanceEngine {
  AttendanceEngine._();

  static List<AttendanceEvent> collapseDuplicatePunches(
    List<AttendanceEvent> events,
  ) {
    final collapsed = <AttendanceEvent>[];
    for (final event in events) {
      final index = collapsed.indexWhere((e) => e.isSamePunchAs(event));
      if (index >= 0) {
        collapsed[index] = AttendanceEvent.preferAuthoritative(
          collapsed[index],
          event,
        );
      } else {
        collapsed.add(event);
      }
    }
    return collapsed;
  }

  static AttendanceSummary compute(List<AttendanceEvent> events) {
    if (events.isEmpty) return AttendanceSummary.empty;

    final sorted = collapseDuplicatePunches(events)
      ..sort((a, b) => a.effectiveTime.compareTo(b.effectiveTime));

    // Explicit earliest check-in / latest check-out — never overwritten by
    // later re-check-ins or intermediate check-outs.
    DateTime? firstCheckIn;
    DateTime? lastCheckOut;
    for (final e in sorted) {
      if (e.type == AttendanceEventType.checkIn) {
        firstCheckIn ??= e.effectiveTime;
      } else if (e.type == AttendanceEventType.checkOut) {
        lastCheckOut = e.effectiveTime;
      }
    }

    Duration breaks = Duration.zero;

    DateTime? openWorkStart;
    DateTime? openBreakStart;
    bool isCheckedIn = false;
    bool isOnBreak = false;

    for (final e in sorted) {
      final at = e.effectiveTime;
      switch (e.type) {
        case AttendanceEventType.checkIn:
          // Do not touch firstCheckIn — already locked to earliest above.
          openWorkStart = at;
          isCheckedIn = true;
          isOnBreak = false;
          break;

        case AttendanceEventType.checkOut:
          openWorkStart = null;
          isCheckedIn = false;
          isOnBreak = false;
          break;

        case AttendanceEventType.breakStart:
          openWorkStart = null;
          openBreakStart = at;
          isOnBreak = true;
          break;

        case AttendanceEventType.breakEnd:
          if (openBreakStart != null) {
            breaks += at.difference(openBreakStart);
            openBreakStart = null;
          }
          // Resume working.
          openWorkStart = at;
          isOnBreak = false;
          isCheckedIn = true;
          break;
      }
    }

    final openSessionStart = openBreakStart ?? openWorkStart;

    // Working hours = (check-out or now) − first check-in − breaks.
    // 12:25 AM is hour 0; 8:00 PM is hour 20 — never 12-hour arithmetic.
    var working = Duration.zero;
    if (firstCheckIn != null) {
      working = AttendanceFormat.workedDuration(
        start: firstCheckIn,
        end: isOnBreak
            ? openBreakStart
            : isCheckedIn
            ? openWorkStart
            : lastCheckOut,
        breaks: breaks,
      );
    }

    return AttendanceSummary(
      firstCheckIn: firstCheckIn,
      lastCheckOut: lastCheckOut,
      totalWorkingDuration: working,
      totalBreakDuration: breaks,
      isCheckedIn: isCheckedIn,
      isOnBreak: isOnBreak,
      openSessionStart: openSessionStart,
    );
  }

  /// Events sorted newest-first, for the details timeline UI.
  static List<AttendanceEvent> sortedNewestFirst(List<AttendanceEvent> events) {
    final sorted = [...events]
      ..sort((a, b) {
        final byTime = b.effectiveTime.compareTo(a.effectiveTime);
        if (byTime != 0) return byTime;
        return _typeOrder(b.type).compareTo(_typeOrder(a.type));
      });
    return sorted;
  }

  /// Events sorted oldest-first (chronological), for attendance timelines.
  static List<AttendanceEvent> sortedOldestFirst(List<AttendanceEvent> events) {
    final sorted = [...events]
      ..sort((a, b) => a.effectiveTime.compareTo(b.effectiveTime));
    return sorted;
  }

  static int _typeOrder(AttendanceEventType type) {
    switch (type) {
      case AttendanceEventType.checkIn:
        return 0;
      case AttendanceEventType.breakStart:
        return 1;
      case AttendanceEventType.breakEnd:
        return 2;
      case AttendanceEventType.checkOut:
        return 3;
    }
  }
}
