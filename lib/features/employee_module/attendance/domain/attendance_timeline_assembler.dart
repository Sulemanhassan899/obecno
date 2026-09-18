import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:obecno/features/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_event.dart'
    hide AttendanceFormat;
import 'package:obecno/features/employee_module/attendance/presentation/widgets/history_attendance_engine.dart';
import 'package:obecno/features/more/data/models/reminder_log.dart';

/// Builds Clock / Attendance timelines without dummy midnight punches.
///
/// Example (18 Sep):
/// check-in 3:02 with request 12:25, pending add break 1:00 / 2:30,
/// later real break 6:00 / 7:49.
/// Dummy 12:01 / 12:02 AM cards are hidden. The 1:00 / 2:30 request stays
/// under the live 6:00 / 7:49 cards.
class AttendanceTimelineAssembler {
  AttendanceTimelineAssembler._();

  static const pendingAddIdPrefix = 'pending_add_';

  static bool isPendingAddId(String? id) =>
      id != null && id.startsWith(pendingAddIdPrefix);

  static bool isHiddenPlaceholder(DateTime time) =>
      AttendanceEditRequest.isPlaceholderMint(time);

  static ClockTimelineAssembly clock({
    required List<AttendanceEvent> events,
    required DateTime day,
    List<AttendanceEditRequest> stored = const [],
  }) {
    final location = _firstClockLocation(events);
    final bound = _bind(
      punches: [
        for (final event in events)
          if (!isHiddenPlaceholder(event.time))
            (type: event.type.name, time: event.time, requests: event.editRequests),
      ],
      hiddenRequests: [
        for (final event in events)
          if (isHiddenPlaceholder(event.time))
            for (final request in event.editRequests)
              request.copyWith(
                eventType:
                    AttendanceEditRequest.normalizedEventType(request.eventType) ??
                    event.type.name,
              ),
      ],
      stored: stored,
      day: day,
    );

    final punches = <AttendanceEvent>[];
    var punchIndex = 0;
    for (final event in events) {
      if (isHiddenPlaceholder(event.time)) continue;
      punches.add(event.copyWith(editRequests: bound.forPunch[punchIndex]));
      punchIndex++;
    }

    final pendingAdds = [
      for (final add in bound.pendingAdds)
        AttendanceEvent(
          id: '$pendingAddIdPrefix${add.eventType}',
          type: _clockType(add.eventType),
          time: add.time,
          location: location,
          editRequests: add.requests,
        ),
    ];

    return ClockTimelineAssembly(punches: punches, pendingAdds: pendingAdds);
  }

  static HistoryTimelineAssembly history({
    required List<HistoryAttendanceEvent> events,
    required DateTime day,
    List<AttendanceEditRequest> stored = const [],
  }) {
    final location = _firstHistoryLocation(events);
    final bound = _bind(
      punches: [
        for (final event in events)
          if (!isHiddenPlaceholder(event.time))
            (type: event.type.name, time: event.time, requests: event.editRequests),
      ],
      hiddenRequests: [
        for (final event in events)
          if (isHiddenPlaceholder(event.time))
            for (final request in event.editRequests)
              request.copyWith(
                eventType:
                    AttendanceEditRequest.normalizedEventType(request.eventType) ??
                    event.type.name,
              ),
      ],
      stored: stored,
      day: day,
    );

    final punches = <HistoryAttendanceEvent>[];
    var punchIndex = 0;
    for (final event in events) {
      if (isHiddenPlaceholder(event.time)) continue;
      punches.add(event.copyWith(editRequests: bound.forPunch[punchIndex]));
      punchIndex++;
    }

    final pendingAdds = [
      for (final add in bound.pendingAdds)
        HistoryAttendanceEvent(
          id: '$pendingAddIdPrefix${add.eventType}',
          type: _historyType(add.eventType),
          time: add.time,
          location: location,
          editRequests: add.requests,
        ),
    ];

    return HistoryTimelineAssembly(punches: punches, pendingAdds: pendingAdds);
  }

  static List<ReminderPunch> reminderPunchesFromClock(
    Iterable<AttendanceEvent> events,
  ) {
    final punches = <ReminderPunch>[];
    for (final event in events) {
      if (isHiddenPlaceholder(event.time) || isPendingAddId(event.id)) {
        continue;
      }
      final kind = ReminderPunchKind.fromName(event.type.name);
      if (kind == null) continue;
      punches.add(ReminderPunch(kind: kind, time: event.effectiveTime));
    }
    return punches;
  }

  static List<ReminderPunch> reminderPunchesFromHistory(
    Iterable<HistoryAttendanceEvent> events,
  ) {
    final punches = <ReminderPunch>[];
    for (final event in events) {
      if (isHiddenPlaceholder(event.time) || isPendingAddId(event.id)) {
        continue;
      }
      final kind = ReminderPunchKind.fromName(event.type.name);
      if (kind == null) continue;
      punches.add(ReminderPunch(kind: kind, time: event.time));
    }
    return punches;
  }

  static _BoundRequests _bind({
    required List<({String type, DateTime time, List<AttendanceEditRequest> requests})>
        punches,
    required List<AttendanceEditRequest> hiddenRequests,
    required List<AttendanceEditRequest> stored,
    required DateTime day,
  }) {
    final candidates = <AttendanceEditRequest>[];
    final seen = <String>{};

    void addAll(Iterable<AttendanceEditRequest> requests, {String? fallbackType}) {
      for (final request in requests) {
        final normalized = AttendanceEditRequest.normalizedEventType(
          request.eventType,
        );
        // Do not stamp a punch's type onto an untyped pending add. The API
        // sometimes nests every day's change_requests on the check-in row.
        final type = normalized ??
            (_isPendingAddStyle(request) ? null : fallbackType);
        final typed = type != request.eventType
            ? request.copyWith(eventType: type)
            : request;
        if (!seen.add(_key(typed))) continue;
        candidates.add(typed);
      }
    }

    for (final punch in punches) {
      addAll(punch.requests, fallbackType: punch.type);
    }
    addAll(hiddenRequests);
    addAll(stored);

    final forPunch = <List<AttendanceEditRequest>>[
      for (final punch in punches)
        [
          for (final request in candidates)
            if (_belongsToPunch(request, punchTime: punch.time, eventType: punch.type))
              request,
        ],
    ];

    final boundKeys = {
      for (final requests in forPunch)
        for (final request in requests) _key(request),
    };

    // Pending add-break (1:00 / 2:30) stays under the live punch of that
    // type (6:00 / 7:49). Only mint a standalone card when that punch is missing.
    final claimedTypes = <String>{};
    for (var i = 0; i < punches.length; i++) {
      final type = punches[i].type;
      if (!claimedTypes.add(type)) continue;
      for (final request in candidates) {
        if (boundKeys.contains(_key(request))) continue;
        if (!_isPendingAddStyle(request)) continue;
        if (AttendanceEditRequest.normalizedEventType(request.eventType) !=
            type) {
          continue;
        }
        if (forPunch[i].any(
          (existing) =>
              _isPendingAddStyle(existing) && existing.newTime == request.newTime,
        )) {
          boundKeys.add(_key(request));
          continue;
        }
        forPunch[i] = [...forPunch[i], request];
        boundKeys.add(_key(request));
      }
    }

    final pendingAdds = <_PendingAdd>[];
    final pendingTypes = <String>{};
    for (final request in candidates) {
      if (boundKeys.contains(_key(request))) continue;
      if (!_isPendingAddStyle(request)) continue;
      final type = AttendanceEditRequest.normalizedEventType(request.eventType);
      if (type == null || type.isEmpty || !pendingTypes.add(type)) continue;
      final time = AttendanceEditRequest.parseClockTime(request.newTime, date: day);
      if (time == null || isHiddenPlaceholder(time)) continue;
      if (punches.any((punch) => punch.type == type)) continue;
      pendingAdds.add(
        _PendingAdd(
          eventType: type,
          time: time,
          requests: [
            for (final match in candidates)
              if (AttendanceEditRequest.normalizedEventType(match.eventType) ==
                      type &&
                  _isPendingAddStyle(match))
                match,
          ],
        ),
      );
    }

    return _BoundRequests(forPunch: forPunch, pendingAdds: pendingAdds);
  }

  static bool _belongsToPunch(
    AttendanceEditRequest request, {
    required DateTime punchTime,
    required String eventType,
  }) {
    final requestType = AttendanceEditRequest.normalizedEventType(
      request.eventType,
    );
    if (requestType != null && requestType != eventType) return false;
    if (_isPendingAddStyle(request)) return false;
    if (isHiddenPlaceholder(punchTime)) return false;

    final original = AttendanceEditRequest.parseClockTime(
      request.originalTime,
      date: punchTime,
    );
    if (original != null &&
        !isHiddenPlaceholder(original) &&
        _sameMinute(original, punchTime)) {
      return true;
    }
    if (request.isApproved) {
      final next = AttendanceEditRequest.parseClockTime(
        request.newTime,
        date: punchTime,
      );
      if (next != null && _sameMinute(next, punchTime)) return true;
    }
    return false;
  }

  static bool _isPendingAddStyle(AttendanceEditRequest request) {
    if (!request.isPending) return false;
    if (request.isPendingAdd) return true;
    final original = AttendanceEditRequest.parseClockTime(
      request.originalTime,
      date: DateTime(2000, 1, 1),
    );
    return original != null && isHiddenPlaceholder(original);
  }

  static bool _sameMinute(DateTime a, DateTime b) =>
      a.hour == b.hour && a.minute == b.minute;

  static String _key(AttendanceEditRequest request) =>
      '${request.eventType}|${request.status.name}|${request.originalTime}|${request.newTime}';

  static String? _firstClockLocation(List<AttendanceEvent> events) {
    for (final event in events) {
      if (event.type == AttendanceEventType.checkIn &&
          event.location != null &&
          event.location!.trim().isNotEmpty) {
        return event.location;
      }
    }
    return null;
  }

  static String? _firstHistoryLocation(List<HistoryAttendanceEvent> events) {
    for (final event in events) {
      if (event.type == AttendanceHisotryEventType.checkIn &&
          event.location != null &&
          event.location!.trim().isNotEmpty) {
        return event.location;
      }
    }
    return null;
  }

  static AttendanceEventType _clockType(String eventType) {
    return switch (AttendanceEditRequest.normalizedEventType(eventType)) {
      'checkOut' => AttendanceEventType.checkOut,
      'breakStart' => AttendanceEventType.breakStart,
      'breakEnd' => AttendanceEventType.breakEnd,
      _ => AttendanceEventType.checkIn,
    };
  }

  static AttendanceHisotryEventType _historyType(String eventType) {
    return switch (AttendanceEditRequest.normalizedEventType(eventType)) {
      'checkOut' => AttendanceHisotryEventType.checkOut,
      'breakStart' => AttendanceHisotryEventType.breakStart,
      'breakEnd' => AttendanceHisotryEventType.breakEnd,
      _ => AttendanceHisotryEventType.checkIn,
    };
  }
}

class ClockTimelineAssembly {
  const ClockTimelineAssembly({
    required this.punches,
    required this.pendingAdds,
  });

  final List<AttendanceEvent> punches;
  final List<AttendanceEvent> pendingAdds;

  List<AttendanceEvent> get timeline =>
      AttendanceEngine.sortedNewestFirst([...punches, ...pendingAdds]);
}

class HistoryTimelineAssembly {
  const HistoryTimelineAssembly({
    required this.punches,
    required this.pendingAdds,
  });

  final List<HistoryAttendanceEvent> punches;
  final List<HistoryAttendanceEvent> pendingAdds;

  List<HistoryAttendanceEvent> get timeline =>
      HistoryAttendanceEngine.sortedNewestFirst([...punches, ...pendingAdds]);
}

class _BoundRequests {
  const _BoundRequests({required this.forPunch, required this.pendingAdds});

  final List<List<AttendanceEditRequest>> forPunch;
  final List<_PendingAdd> pendingAdds;
}

class _PendingAdd {
  const _PendingAdd({
    required this.eventType,
    required this.time,
    required this.requests,
  });

  final String eventType;
  final DateTime time;
  final List<AttendanceEditRequest> requests;
}
