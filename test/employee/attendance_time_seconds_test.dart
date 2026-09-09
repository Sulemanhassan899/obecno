import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_edit_request.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/team_attendance_mapper.dart';
import 'package:obecno/shared/location/service/attendance_payload_model.dart';

void main() {
  test('stores 12:29:10 with seconds but displays 12:29', () {
    final punched = DateTime(2026, 9, 7, 12, 29, 10);
    expect(AttendanceFormat.time(punched), '12:29 PM');
    expect(TeamAttendanceMapper.formatTime('12:29:10'), '12:29 PM');
    expect(TeamAttendanceMapper.formatTime('09:00:33'), '09:00 AM');

    final payload = AttendancePayloadModel(
      action: 'checkin',
      capturedAt: punched,
    );
    expect(payload.time, '12:29:10');
    expect(payload.datetime, '2026-09-07 12:29:10');

    final request = AttendanceEditRequest.fromJson({
      'old_value': '12:29:10',
      'new_value': '12:29:10',
      'status': 'pending',
      'requested_at': '2026-09-07T12:29:10',
    });
    expect(request.originalTime, '12:29 PM');
    expect(request.newTime, '12:29 PM');
    expect(
      AttendanceEditRequest.parseClockTime(
        '12:29:10 PM',
        date: DateTime(2026, 9, 7),
      ),
      DateTime(2026, 9, 7, 12, 29, 10),
    );
  });
}
