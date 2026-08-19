import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:Obecno/features/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendance_details_data.dart';
import 'package:Obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 8, 17);
  final original = DateTime(2026, 8, 17, 8, 55);
  final approved = DateTime(2026, 8, 17, 7, 55);
  final checkOut = DateTime(2026, 8, 17, 12, 30);

  AttendanceEditRequest approvedEdit() => AttendanceEditRequest(
        status: AttendanceEditRequestStatus.approved,
        requestedAt: DateTime(2026, 8, 17, 12, 40),
        originalTime: '08:55 AM',
        newTime: '07:55 AM',
        actionedBy: 'Naveed Ramzan',
        actionedAt: DateTime(2026, 8, 17, 12, 40),
      );

  test('effectiveTime uses the latest approved new time', () {
    final event = AttendanceEvent(
      id: '511',
      type: AttendanceEventType.checkIn,
      time: original,
      editRequests: [approvedEdit()],
    );

    expect(event.effectiveTime.hour, 7);
    expect(event.effectiveTime.minute, 55);
  });

  test('clock card duration uses approved check-in / check-out', () {
    final events = [
      AttendanceEvent(
        id: '511',
        type: AttendanceEventType.checkIn,
        time: original,
        editRequests: [approvedEdit()],
      ),
      AttendanceEvent(
        id: '512',
        type: AttendanceEventType.checkOut,
        time: checkOut,
      ),
    ];

    final summary = AttendanceEngine.compute(events);
    expect(summary.firstCheckIn, approved);
    expect(summary.lastCheckOut, checkOut);
    expect(summary.totalWorkingDuration, checkOut.difference(approved));
  });

  test('local original punch is treated as the same event as approved server punch', () {
    final local = AttendanceEvent(
      id: 'local_1',
      type: AttendanceEventType.checkIn,
      time: original,
    );
    final server = AttendanceEvent(
      id: '511',
      type: AttendanceEventType.checkIn,
      time: approved,
      editRequests: [approvedEdit()],
    );

    expect(local.isSamePunchAs(server), isTrue);
    final chosen = AttendanceEvent.preferAuthoritative(local, server);
    expect(chosen.id, '511');
    expect(chosen.effectiveTime, approved);
  });

  test('details parser overlays approved new_value onto event time', () {
    final item = AttendanceDetailItem.fromJson({
      'id': 511,
      'type': 'check in',
      'occurred_at_iso': '2026-08-17T08:55:00+05:00',
      'attendance_time': '08:55:00',
      'attendance_date': '2026-08-17',
      'changes': [
        {
          'id': 6,
          'old_value_label': '08:55 AM',
          'new_value_label': '07:55 AM',
          'status': 'approved',
          'updated_by_name': 'Naveed Ramzan',
          'created_at': '2026-08-17 12:40:26',
          'updated_at': '2026-08-17 12:40:26',
        },
      ],
      'change_requests': [],
    });

    expect(item.time.hour, 7);
    expect(item.time.minute, 55);
    expect(item.toClockEvent()!.effectiveTime.hour, 7);
  });

  test('parseClockTime reads 12-hour labels onto the given date', () {
    final parsed = AttendanceEditRequest.parseClockTime(
      '07:55 AM',
      date: day,
    );
    expect(parsed, DateTime(2026, 8, 17, 7, 55));
  });
}
