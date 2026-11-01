import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:obecno/features/shared_attendance/attendance_display_times.dart';

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

  /// Closed segments in [totalWorkingDuration], plus live open work only
  /// (not first-check-in → now across gaps after an earlier checkout).
  Duration liveWorkingDuration({DateTime? now}) {
    final clock = now ?? DateTime.now();
    var live = totalWorkingDuration;
    if (isOnBreak) return live;
    if (isCheckedIn && openSessionStart != null) {
      final extra = clock.difference(openSessionStart!);
      if (!extra.isNegative) live += extra;
    }
    return live;
  }

  /// Shared rule with Attendance history — see [AttendanceDisplayTimes].
  DateTime? get displayCheckIn =>
      AttendanceDisplayTimes.displayCheckIn(firstCheckIn: firstCheckIn);

  /// Shared rule: hide checkout while the day is still open.
  DateTime? get displayCheckOut => AttendanceDisplayTimes.displayCheckOut(
    dayStillOpen: isCheckedIn || isOnBreak,
    lastCheckOut: lastCheckOut,
  );

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
    // Closed work only — open segment is added by [liveWorkingDuration].
    var working = Duration.zero;
    final orphanEarlyCheckOuts = <DateTime>[];

    DateTime spanEnd(DateTime start, DateTime rawEnd) {
      if (rawEnd.isAfter(start)) return rawEnd;
      return rawEnd.add(const Duration(days: 1));
    }

    void considerCheckOut(DateTime raw, {required DateTime openStart}) {
      final out = spanEnd(openStart, raw);
      if (lastCheckOut == null || out.isAfter(lastCheckOut!)) {
        lastCheckOut = out;
      }
    }

    void closeWork(DateTime rawEnd) {
      final start = openWorkStart;
      if (start == null) return;
      working += spanEnd(start, rawEnd).difference(start);
      openWorkStart = null;
    }

    for (final e in sorted) {
      final at = e.effectiveTime;
      switch (e.type) {
        case AttendanceEventType.checkIn:
          if (firstCheckIn == null || at.isBefore(firstCheckIn)) {
            firstCheckIn = at;
          }
          isCheckedIn = true;
          // An approved check-in edit can land inside an already-open break
          // (break start is earlier on the timeline). Keep that break so the
          // full break duration still counts.
          if (openBreakStart != null && openBreakStart.isBefore(at)) {
            isOnBreak = true;
            openWorkStart = null;
          } else {
            openWorkStart = at;
            isOnBreak = false;
            openBreakStart = null;
          }
          break;

        case AttendanceEventType.checkOut:
          final workStart = openWorkStart;
          if (workStart != null) {
            considerCheckOut(at, openStart: workStart);
            closeWork(at);
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
          closeWork(at);
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

    final orphanOpen = openWorkStart;
    if (orphanOpen != null && orphanEarlyCheckOuts.isNotEmpty) {
      final rawOut = orphanEarlyCheckOuts.removeLast();
      considerCheckOut(rawOut, openStart: orphanOpen);
      closeWork(rawOut);
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

    // Single closed shift whose check-in was edited into a break window:
    // prefer (checkout − check-in − breaks) so working time matches the card.
    final closedIn = firstCheckIn;
    final closedOut = lastCheckOut;
    if (closedIn != null &&
        closedOut != null &&
        !isCheckedIn &&
        !isOnBreak &&
        breaks > Duration.zero) {
      final span = spanEnd(closedIn, closedOut).difference(closedIn);
      if (breaks < span) {
        working = span - breaks;
      }
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
