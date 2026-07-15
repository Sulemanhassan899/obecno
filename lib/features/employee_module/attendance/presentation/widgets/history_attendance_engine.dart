import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendence_event.dart';
import 'package:Obecno/features/employee_module/clock/data/models/clock_attendence_event.dart';

class HistoryAttendanceSummary {
  final DateTime? firstCheckIn;
  final DateTime? lastCheckOut;
  final Duration totalWorkingDuration;
  final Duration totalBreakDuration;
  final bool isCheckedIn;
  final bool isOnBreak;

  /// Start time of whichever session (work or break) is currently
  /// open/running. Null if nothing is currently open (checked out).
  final DateTime? openSessionStart;

  const HistoryAttendanceSummary({
    required this.firstCheckIn,
    required this.lastCheckOut,
    required this.totalWorkingDuration,
    required this.totalBreakDuration,
    required this.isCheckedIn,
    required this.isOnBreak,
    required this.openSessionStart,
  });

  static const empty = HistoryAttendanceSummary(
    firstCheckIn: null,
    lastCheckOut: null,
    totalWorkingDuration: Duration.zero,
    totalBreakDuration: Duration.zero,
    isCheckedIn: false,
    isOnBreak: false,
    openSessionStart: null,
  );

  /// Live working duration "as of now" -- adds the still-running
  /// work session (if any) on top of the completed sessions.
  Duration liveWorkingDuration({DateTime? now}) {
    if (!isCheckedIn || isOnBreak || openSessionStart == null) {
      return totalWorkingDuration;
    }
    final current = now ?? DateTime.now();
    return totalWorkingDuration + current.difference(openSessionStart!);
  }

  /// Live break duration "as of now" -- adds the still-running
  /// break (if any) on top of completed breaks.
  Duration liveBreakDuration({DateTime? now}) {
    if (!isOnBreak || openSessionStart == null) {
      return totalBreakDuration;
    }
    final current = now ?? DateTime.now();
    return totalBreakDuration + current.difference(openSessionStart!);
  }
}

class HistoryAttendanceEngine {
  HistoryAttendanceEngine._();

  static HistoryAttendanceSummary compute(List<HistoryAttendanceEvent> events) {
    if (events.isEmpty) return HistoryAttendanceSummary.empty;

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
        case AttendanceHisotryEventType.checkIn:
          firstCheckIn ??= e.time;
          openWorkStart = e.time;
          isCheckedIn = true;
          isOnBreak = false;
          break;

        case AttendanceHisotryEventType.checkOut:
          lastCheckOut = e.time;
          if (openWorkStart != null) {
            working += e.time.difference(openWorkStart);
            openWorkStart = null;
          }
          isCheckedIn = false;
          isOnBreak = false;
          break;

        case AttendanceHisotryEventType.breakStart:
          // Pause the running work session, if any.
          if (openWorkStart != null) {
            working += e.time.difference(openWorkStart);
            openWorkStart = null;
          }
          openBreakStart = e.time;
          isOnBreak = true;
          break;

        case AttendanceHisotryEventType.breakEnd:
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

    return HistoryAttendanceSummary(
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
  static List<HistoryAttendanceEvent> sortedNewestFirst(
    List<HistoryAttendanceEvent> events,
  ) {
    final sorted = [...events]..sort((a, b) => b.time.compareTo(a.time));
    return sorted;
  }
}
