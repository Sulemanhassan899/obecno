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
    if (!isCheckedIn || isOnBreak || openSessionStart == null) {
      return totalWorkingDuration;
    }
    final current = now ?? DateTime.now();
    return totalWorkingDuration + current.difference(openSessionStart!);
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

  static AttendanceSummary compute(List<AttendanceEvent> events) {
    if (events.isEmpty) return AttendanceSummary.empty;

    final sorted = [...events]
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

    Duration working = Duration.zero;
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
          if (openWorkStart != null) {
            working += at.difference(openWorkStart);
            openWorkStart = null;
          }
          isCheckedIn = false;
          isOnBreak = false;
          break;

        case AttendanceEventType.breakStart:
          // Pause the running work session, if any.
          if (openWorkStart != null) {
            working += at.difference(openWorkStart);
            openWorkStart = null;
          }
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
      ..sort((a, b) => b.effectiveTime.compareTo(a.effectiveTime));
    return sorted;
  }

  /// Events sorted oldest-first (chronological), for attendance timelines.
  static List<AttendanceEvent> sortedOldestFirst(List<AttendanceEvent> events) {
    final sorted = [...events]
      ..sort((a, b) => a.effectiveTime.compareTo(b.effectiveTime));
    return sorted;
  }
}
