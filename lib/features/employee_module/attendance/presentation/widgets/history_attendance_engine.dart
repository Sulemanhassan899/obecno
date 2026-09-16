import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart'
    show AttendanceFormat;
import 'package:obecno/features/employee_module/attendance/data/models/attendence_event.dart'
    hide AttendanceFormat;

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
          openWorkStart = null;
          isCheckedIn = false;
          isOnBreak = false;
          break;

        case AttendanceHisotryEventType.breakStart:
          openWorkStart = null;
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
    final sorted = [...events]
      ..sort((a, b) {
        final byTime = b.time.compareTo(a.time);
        if (byTime != 0) return byTime;
        return _typeOrder(b.type).compareTo(_typeOrder(a.type));
      });
    return sorted;
  }

  /// Events sorted oldest-first (chronological). Equal times keep
  /// check-in → break start → break end → check-out so paired punches
  /// at the same minute still read in work order.
  static List<HistoryAttendanceEvent> sortedOldestFirst(
    List<HistoryAttendanceEvent> events,
  ) {
    final sorted = [...events]
      ..sort((a, b) {
        final byTime = a.time.compareTo(b.time);
        if (byTime != 0) return byTime;
        return _typeOrder(a.type).compareTo(_typeOrder(b.type));
      });
    return sorted;
  }

  static int _typeOrder(AttendanceHisotryEventType type) {
    switch (type) {
      case AttendanceHisotryEventType.checkIn:
        return 0;
      case AttendanceHisotryEventType.breakStart:
        return 1;
      case AttendanceHisotryEventType.breakEnd:
        return 2;
      case AttendanceHisotryEventType.checkOut:
        return 3;
    }
  }
}
