import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';

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

    final sorted = [...events]..sort((a, b) => a.time.compareTo(b.time));

    DateTime? firstCheckIn;
    DateTime? lastCheckOut;
    Duration working = Duration.zero;
    Duration breaks = Duration.zero;

    DateTime? openWorkStart;
    DateTime? openBreakStart;
    bool isCheckedIn = false;
    bool isOnBreak = false;

    for (final e in sorted) {
      switch (e.type) {
        case AttendanceEventType.checkIn:
          firstCheckIn ??= e.time;
          openWorkStart = e.time;
          isCheckedIn = true;
          isOnBreak = false;
          break;

        case AttendanceEventType.checkOut:
          lastCheckOut = e.time;
          if (openWorkStart != null) {
            working += e.time.difference(openWorkStart);
            openWorkStart = null;
          }
          isCheckedIn = false;
          isOnBreak = false;
          break;

        case AttendanceEventType.breakStart:
          // Pause the running work session, if any.
          if (openWorkStart != null) {
            working += e.time.difference(openWorkStart);
            openWorkStart = null;
          }
          openBreakStart = e.time;
          isOnBreak = true;
          break;

        case AttendanceEventType.breakEnd:
          if (openBreakStart != null) {
            breaks += e.time.difference(openBreakStart);
            openBreakStart = null;
          }
          // Resume working.
          openWorkStart = e.time;
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
    final sorted = [...events]..sort((a, b) => b.time.compareTo(a.time));
    return sorted;
  }
}
