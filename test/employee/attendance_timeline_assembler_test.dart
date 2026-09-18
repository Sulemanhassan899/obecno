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

  test(
    '18 Sep: dummy midnight cards stay hidden; 6:00/7:49 keep the request',
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
      expect(liveStart.editRequests.single.newTime, '1:00 PM');
      expect(liveEnd.editRequests.single.newTime, '2:30 PM');
      expect(liveStart.time.hour, 18);
      expect(liveEnd.time.hour, 19);

      final checkIn = assembled.punches.singleWhere(
        (e) => e.type == AttendanceEventType.checkIn,
      );
      expect(checkIn.editRequests.single.newTime, '12:25 PM');

      expect(assembled.pendingAdds, isEmpty);
      expect(
        assembled.timeline.map((e) => '${e.type.name} ${e.time.hour}:${e.time.minute}'),
        [
          'breakEnd 19:49',
          'breakStart 18:0',
          'checkIn 15:2',
        ],
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

  test('history sheet uses the same 18 Sep binding', () {
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
      assembled.punches.where((e) => e.type == AttendanceHisotryEventType.breakStart).single.editRequests.single.newTime,
      '1:00 PM',
    );
    expect(
      assembled.pendingAdds.map((e) => e.time),
      [DateTime(2026, 9, 18, 14, 30)],
    );
  });

  test('break-in request stays under Break End, break-out under Break Start', () {
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
          .editRequests
          .single
          .newTime,
      '1:00 PM',
    );
    expect(
      assembled.punches
          .singleWhere((e) => e.type == AttendanceEventType.breakEnd)
          .editRequests
          .single
          .newTime,
      '2:30 PM',
    );
    expect(assembled.pendingAdds, isEmpty);
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
      assembled.punches
          .singleWhere((e) => e.type == AttendanceEventType.breakStart)
          .editRequests
          .single
          .newTime,
      '1:00 PM',
    );
    expect(
      assembled.punches
          .singleWhere((e) => e.type == AttendanceEventType.breakEnd)
          .editRequests
          .single
          .newTime,
      '2:30 PM',
    );
  });
}
