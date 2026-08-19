import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendence_event.dart';
import 'package:Obecno/features/clock/data/models/clock_attendence_event.dart';

class HistoryAttendanceSummary {
  final DateTime? firstCheckIn;
  final DateTime? lastCheckOut;
  final Duration totalWorkingDuration;
  final Duration totalBreakDuration;
  final bool isCheckedIn;
  final bool isOnBreak;

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

class HistoryAttendanceEngine {
  HistoryAttendanceEngine._();

  static HistoryAttendanceSummary compute(List<HistoryAttendanceEvent> events) {
    if (events.isEmpty) return HistoryAttendanceSummary.empty;

    final sorted = [...events]..sort((a, b) => a.time.compareTo(b.time));

    // Explicit earliest check-in / latest check-out — never overwritten by
    // later re-check-ins or intermediate check-outs.
    DateTime? firstCheckIn;
    DateTime? lastCheckOut;
    for (final e in sorted) {
      if (e.type == AttendanceHisotryEventType.checkIn) {
        firstCheckIn ??= e.time;
      } else if (e.type == AttendanceHisotryEventType.checkOut) {
        lastCheckOut = e.time;
      }
    }

    Duration working = Duration.zero;
    Duration breaks = Duration.zero;

    DateTime? openWorkStart;
    DateTime? openBreakStart;
    bool isCheckedIn = false;
    bool isOnBreak = false;

    for (final e in sorted) {
      switch (e.type) {
        case AttendanceHisotryEventType.checkIn:
          // Do not touch firstCheckIn — already locked to earliest above.
          openWorkStart = e.time;
          isCheckedIn = true;
          isOnBreak = false;
          break;

        case AttendanceHisotryEventType.checkOut:
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

  /// Events sorted oldest-first (chronological), for attendance timelines.
  static List<HistoryAttendanceEvent> sortedOldestFirst(
    List<HistoryAttendanceEvent> events,
  ) {
    final sorted = [...events]..sort((a, b) => a.time.compareTo(b.time));
    return sorted;
  }
}
