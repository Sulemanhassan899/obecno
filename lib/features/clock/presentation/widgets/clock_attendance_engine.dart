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

    final sorted = sortedOldestFirst(collapseDuplicatePunches(events));

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
      final at = e.effectiveTime;
      switch (e.type) {
        case AttendanceEventType.checkIn:
          if (firstCheckIn == null || at.isBefore(firstCheckIn)) {
            firstCheckIn = at;
          }
          openWorkStart = at;
          isCheckedIn = true;
          isOnBreak = false;
          openBreakStart = null;
          break;

        case AttendanceEventType.checkOut:
          if (openWorkStart != null) {
            considerCheckOut(at, openStart: openWorkStart);
            openWorkStart = null;
            isCheckedIn = false;
            isOnBreak = false;
            openBreakStart = null;
          } else if (isOnBreak) {
            if (lastCheckOut == null || at.isAfter(lastCheckOut!)) {
              lastCheckOut = at;
            }
            openBreakStart = null;
            isOnBreak = false;
            isCheckedIn = false;
          } else {
            orphanEarlyCheckOuts.add(at);
          }
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
          openWorkStart = at;
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
      ..sort((a, b) {
        final byTime = a.effectiveTime.compareTo(b.effectiveTime);
        if (byTime != 0) return byTime;
        return _typeOrder(a.type).compareTo(_typeOrder(b.type));
      });
    return sorted;
  }

  /// Equal-time order: check-out → check-in → break start → break end so a
  /// segment boundary at the same minute stays in work sequence.
  static int _typeOrder(AttendanceEventType type) {
    switch (type) {
      case AttendanceEventType.checkOut:
        return 0;
      case AttendanceEventType.checkIn:
        return 1;
      case AttendanceEventType.breakStart:
        return 2;
      case AttendanceEventType.breakEnd:
        return 3;
    }
  }
}
