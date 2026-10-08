import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendence_event.dart'
    hide AttendanceFormat;
import 'package:obecno/features/employee_module/attendance/domain/attendance_timeline_assembler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 9, 18);

  AttendanceEditRequest checkInFix() => AttendanceEditRequest(
    status: AttendanceEditRequestStatus.pending,
    requestedAt: DateTime(2026, 9, 18, 15, 3),
    originalTime: '3:02 PM',
    newTime: '12:25 PM',
    eventType: 'checkIn',
  );

  AttendanceEditRequest addBreakStart({String original = '--'}) =>
      AttendanceEditRequest(
        status: AttendanceEditRequestStatus.pending,
        requestedAt: DateTime(2026, 9, 18, 15, 3),
        originalTime: original,
        newTime: '1:00 PM',
        eventType: 'breakStart',
      );

  AttendanceEditRequest addBreakEnd({String original = '--'}) =>
      AttendanceEditRequest(
        status: AttendanceEditRequestStatus.pending,
        requestedAt: DateTime(2026, 9, 18, 15, 3),
        originalTime: original,
        newTime: '2:30 PM',
        eventType: 'breakEnd',
      );

  AttendanceEditRequest pendingAdd({
    required String eventType,
    required String newTime,
    DateTime? requestedAt,
  }) => AttendanceEditRequest(
    status: AttendanceEditRequestStatus.pending,
    requestedAt: requestedAt ?? DateTime(2026, 9, 18, 21, 19),
    originalTime: '--',
    newTime: newTime,
    eventType: eventType,
  );

  test(
    '18 Sep: dummy midnight cards stay hidden; mismatched add times get own cards',
    () {
      final events = [
        AttendanceEvent(
          id: 'checkin',
          type: AttendanceEventType.checkIn,
          time: DateTime(2026, 9, 18, 15, 2),
          location: 'Remote - Ahmed & Sulman',
          editRequests: [checkInFix()],
        ),
        AttendanceEvent(
          id: 'mint-start',
          type: AttendanceEventType.breakStart,
          time: DateTime(2026, 9, 18, 0, 1),
          location: 'Remote - Ahmed & Sulman',
          editRequests: [addBreakStart(original: '12:01 AM')],
        ),
        AttendanceEvent(
          id: 'mint-end',
          type: AttendanceEventType.breakEnd,
          time: DateTime(2026, 9, 18, 0, 2),
          location: 'Remote - Ahmed & Sulman',
          editRequests: [addBreakEnd(original: '12:02 AM')],
        ),
        AttendanceEvent(
          id: 'live-start',
          type: AttendanceEventType.breakStart,
          time: DateTime(2026, 9, 18, 18, 0),
          location: 'Remote - Ahmed & Sulman',
        ),
        AttendanceEvent(
          id: 'live-end',
          type: AttendanceEventType.breakEnd,
          time: DateTime(2026, 9, 18, 19, 49),
          location: 'Remote - Ahmed & Sulman',
        ),
      ];

      final assembled = AttendanceTimelineAssembler.clock(
        events: events,
        day: day,
        stored: [
          checkInFix(),
          addBreakStart(),
          addBreakEnd(),
        ],
      );

      expect(
        assembled.punches.map((e) => e.time),
        [
          DateTime(2026, 9, 18, 15, 2),
          DateTime(2026, 9, 18, 18, 0),
          DateTime(2026, 9, 18, 19, 49),
        ],
      );
      expect(
        assembled.punches.every(
          (e) => !AttendanceEditRequest.isPlaceholderMint(e.time),
        ),
        isTrue,
      );

      final liveStart = assembled.punches.singleWhere(
        (e) => e.type == AttendanceEventType.breakStart,
      );
      final liveEnd = assembled.punches.singleWhere(
        (e) => e.type == AttendanceEventType.breakEnd,
      );
      // Live punches at 6:00 / 7:49 do not absorb 1:00 / 2:30 add requests.
      expect(liveStart.editRequests, isEmpty);
      expect(liveEnd.editRequests, isEmpty);
      expect(liveStart.time.hour, 18);
      expect(liveEnd.time.hour, 19);

      final checkIn = assembled.punches.singleWhere(
        (e) => e.type == AttendanceEventType.checkIn,
      );
      expect(checkIn.editRequests.single.newTime, '12:25 PM');

      expect(
        assembled.pendingAdds.map((e) => '${e.type.name} ${e.time.hour}:${e.time.minute}'),
        containsAll(['breakStart 13:0', 'breakEnd 14:30']),
      );

      final reminderTimes = AttendanceTimelineAssembler.reminderPunchesFromClock(
        [...assembled.punches, ...assembled.pendingAdds],
      ).map((p) => '${p.kind.name} ${p.time.hour}:${p.time.minute}');
      expect(reminderTimes, [
        'checkIn 15:2',
        'breakStart 18:0',
        'breakEnd 19:49',
      ]);
    },
  );

  test('history sheet uses the same binding for mismatched add times', () {
    final events = [
      HistoryAttendanceEvent(
        id: 'checkin',
        type: AttendanceHisotryEventType.checkIn,
        time: DateTime(2026, 9, 18, 15, 2),
        editRequests: [checkInFix()],
      ),
      HistoryAttendanceEvent(
        id: 'mint-start',
        type: AttendanceHisotryEventType.breakStart,
        time: DateTime(2026, 9, 18, 0, 1),
        editRequests: [addBreakStart(original: '12:01 AM')],
      ),
      HistoryAttendanceEvent(
        id: 'live-start',
        type: AttendanceHisotryEventType.breakStart,
        time: DateTime(2026, 9, 18, 18, 0),
      ),
    ];

    final assembled = AttendanceTimelineAssembler.history(
      events: events,
      day: day,
      stored: [addBreakStart(), addBreakEnd()],
    );

    expect(
      assembled.punches
          .where((e) => e.type == AttendanceHisotryEventType.breakStart)
          .single
          .editRequests,
      isEmpty,
    );
    expect(
      assembled.pendingAdds.map((e) => e.time),
      containsAll([
        DateTime(2026, 9, 18, 13, 0),
        DateTime(2026, 9, 18, 14, 30),
      ]),
    );
  });

  test('break-in / break-out requests with different times get own cards', () {
    final assembled = AttendanceTimelineAssembler.clock(
      events: [
        AttendanceEvent(
          id: 'checkin',
          type: AttendanceEventType.checkIn,
          time: DateTime(2026, 9, 18, 15, 2),
        ),
        AttendanceEvent(
          id: 'live-start',
          type: AttendanceEventType.breakStart,
          time: DateTime(2026, 9, 18, 18, 0),
        ),
        AttendanceEvent(
          id: 'live-end',
          type: AttendanceEventType.breakEnd,
          time: DateTime(2026, 9, 18, 19, 49),
        ),
      ],
      day: day,
      stored: [
        AttendanceEditRequest(
          status: AttendanceEditRequestStatus.pending,
          requestedAt: DateTime(2026, 9, 18, 15, 3),
          originalTime: '--',
          newTime: '1:00 PM',
          eventType: 'break out',
        ),
        AttendanceEditRequest(
          status: AttendanceEditRequestStatus.pending,
          requestedAt: DateTime(2026, 9, 18, 15, 3),
          originalTime: '--',
          newTime: '2:30 PM',
          eventType: 'break in',
        ),
      ],
    );

    expect(
      assembled.punches
          .singleWhere((e) => e.type == AttendanceEventType.breakStart)
          .editRequests,
      isEmpty,
    );
    expect(
      assembled.punches
          .singleWhere((e) => e.type == AttendanceEventType.breakEnd)
          .editRequests,
      isEmpty,
    );
    expect(
      assembled.pendingAdds.map((e) => '${e.type.name} ${e.time.hour}:${e.time.minute}'),
      containsAll(['breakStart 13:0', 'breakEnd 14:30']),
    );
  });

  test('12:01 AM original is a pending add, not a real punch edit', () {
    final request = addBreakStart(original: '12:01 AM');
    expect(request.isPendingAdd, isTrue);
    expect(checkInFix().isPendingAdd, isFalse);
  });

  test('check-in card keeps only the check-in request', () {
    final assembled = AttendanceTimelineAssembler.clock(
      events: [
        AttendanceEvent(
          id: 'checkin',
          type: AttendanceEventType.checkIn,
          time: DateTime(2026, 9, 18, 15, 2),
          editRequests: [
            checkInFix(),
            addBreakStart(),
            addBreakEnd(),
          ],
        ),
        AttendanceEvent(
          id: 'live-start',
          type: AttendanceEventType.breakStart,
          time: DateTime(2026, 9, 18, 18, 0),
        ),
        AttendanceEvent(
          id: 'live-end',
          type: AttendanceEventType.breakEnd,
          time: DateTime(2026, 9, 18, 19, 49),
        ),
      ],
      day: day,
    );

    final checkIn = assembled.punches.singleWhere(
      (e) => e.type == AttendanceEventType.checkIn,
    );
    expect(checkIn.editRequests, hasLength(1));
    expect(checkIn.editRequests.single.newTime, '12:25 PM');
    expect(
      assembled.pendingAdds.map((e) => e.type),
      containsAll([
        AttendanceEventType.breakStart,
        AttendanceEventType.breakEnd,
      ]),
    );
  });

  test('different requested check-in / check-out times each get their own card', () {
    final assembled = AttendanceTimelineAssembler.history(
      events: [
        HistoryAttendanceEvent(
          id: 'checkin-live',
          type: AttendanceHisotryEventType.checkIn,
          time: DateTime(2026, 9, 30, 12, 0),
          location: 'islamabad blue area',
        ),
        HistoryAttendanceEvent(
          id: 'checkout-live',
          type: AttendanceHisotryEventType.checkOut,
          time: DateTime(2026, 9, 30, 13, 0),
          location: 'islamabad blue area',
        ),
      ],
      day: DateTime(2026, 9, 30),
      stored: [
        pendingAdd(eventType: 'checkIn', newTime: '12:00 PM'),
        pendingAdd(eventType: 'checkIn', newTime: '4:00 PM'),
        pendingAdd(eventType: 'checkOut', newTime: '1:00 PM'),
        pendingAdd(eventType: 'checkOut', newTime: '7:00 PM'),
        pendingAdd(eventType: 'breakStart', newTime: '1:00 PM'),
        pendingAdd(eventType: 'breakEnd', newTime: '1:30 PM'),
      ],
    );

    final checkInCard = assembled.punches.singleWhere(
      (e) => e.type == AttendanceHisotryEventType.checkIn,
    );
    expect(
      checkInCard.editRequests.map((r) => r.newTime),
      ['12:00 PM'],
    );

    final checkOutCard = assembled.punches.singleWhere(
      (e) => e.type == AttendanceHisotryEventType.checkOut,
    );
    expect(
      checkOutCard.editRequests.map((r) => r.newTime),
      ['1:00 PM'],
    );

    expect(
      assembled.pendingAdds.map(
        (e) => '${e.type.name} ${e.time.hour}:${e.time.minute}',
      ),
      containsAll([
        'checkIn 16:0',
        'checkOut 19:0',
        'breakStart 13:0',
        'breakEnd 13:30',
      ]),
    );
  });

  test('matching pending add stays on the live punch card', () {
    final assembled = AttendanceTimelineAssembler.clock(
      events: [
        AttendanceEvent(
          id: 'break',
          type: AttendanceEventType.breakStart,
          time: DateTime(2026, 9, 18, 13, 0),
        ),
      ],
      day: day,
      stored: [addBreakStart()],
    );

    expect(
      assembled.punches.single.editRequests.single.newTime,
      '1:00 PM',
    );
    expect(assembled.pendingAdds, isEmpty);
  });
}
