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

  /// Portal can store an overnight check-out on the same attendance_date with
  /// an early morning clock (e.g. 12:05 AM) even though it closes the evening
  /// open check-in (10:42 PM). Those orphans are rolled forward one day.
  static HistoryAttendanceSummary compute(List<HistoryAttendanceEvent> events) {
    if (events.isEmpty) return HistoryAttendanceSummary.empty;

    final sorted = sortedOldestFirst(events);

    DateTime? firstCheckIn;
    DateTime? lastCheckOut;
    DateTime? openWorkStart;
    DateTime? openBreakStart;
    bool isCheckedIn = false;
    bool isOnBreak = false;
    Duration breaks = Duration.zero;
    final orphanEarlyCheckOuts = <DateTime>[];

    void considerCheckOut(DateTime raw, {required DateTime openStart}) {
      var out = raw;
      if (!out.isAfter(openStart)) {
        out = out.add(const Duration(days: 1));
      }
      if (lastCheckOut == null || out.isAfter(lastCheckOut!)) {
        lastCheckOut = out;
      }
    }

    for (final e in sorted) {
      switch (e.type) {
        case AttendanceHisotryEventType.checkIn:
          if (firstCheckIn == null || e.time.isBefore(firstCheckIn)) {
            firstCheckIn = e.time;
          }
          openWorkStart = e.time;
          isCheckedIn = true;
          isOnBreak = false;
          openBreakStart = null;
          break;

        case AttendanceHisotryEventType.checkOut:
          if (openWorkStart != null) {
            considerCheckOut(e.time, openStart: openWorkStart);
            openWorkStart = null;
            isCheckedIn = false;
            isOnBreak = false;
            openBreakStart = null;
          } else if (isOnBreak) {
            if (lastCheckOut == null || e.time.isAfter(lastCheckOut!)) {
              lastCheckOut = e.time;
            }
            openBreakStart = null;
            isOnBreak = false;
            isCheckedIn = false;
          } else {
            orphanEarlyCheckOuts.add(e.time);
          }
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
          openWorkStart = e.time;
          isOnBreak = false;
          isCheckedIn = true;
          break;
      }
    }

    if (openWorkStart != null && orphanEarlyCheckOuts.isNotEmpty) {
      final rawOut = orphanEarlyCheckOuts.removeLast();
      considerCheckOut(rawOut, openStart: openWorkStart);
      openWorkStart = null;
      isCheckedIn = false;
      isOnBreak = false;
      openBreakStart = null;
    }

    for (final rawOut in orphanEarlyCheckOuts) {
      if (lastCheckOut == null || rawOut.isAfter(lastCheckOut!)) {
        lastCheckOut = rawOut;
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
  /// check-out → check-in → break start → break end so a segment boundary
  /// at the same minute (e.g. 11:30 out then 11:30 in) stays in work order.
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
      case AttendanceHisotryEventType.checkOut:
        return 0;
      case AttendanceHisotryEventType.checkIn:
        return 1;
      case AttendanceHisotryEventType.breakStart:
        return 2;
      case AttendanceHisotryEventType.breakEnd:
        return 3;
    }
  }
}
