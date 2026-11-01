import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_details_data.dart';
import 'package:obecno/features/employee_module/attendance/domain/attendance_timeline_assembler.dart';
import 'package:obecno/features/employee_module/attendance/presentation/widgets/history_attendance_engine.dart';

/// Real portal payload for employee2@thedemo.com on 2026-10-13.
void main() {
  test('Oct 13 overnight orphan check-out closes evening session', () {
    final data = AttendanceDetailsData.fromJson({
      'user_id': 30,
      'date': '2026-10-13',
      'attendance_id': 392,
      'attendance_details': [
        {
          'id': 1437,
          'type': 'check in',
          'attendance_date': '2026-10-13',
          'attendance_time': '00:12:00',
          'current_location': '37.4219983,-122.084',
          'change_requests': [
            {
              'id': 302,
              'detail_type': 'check in',
              'old_value': '00:12:41',
              'new_value': '00:12:00',
              'status': 'approved',
              'updated_by_name': 'Owner',
              'created_at': '2026-10-14 00:21:34',
              'updated_at': '2026-10-14 00:22:14',
            }
          ],
          'changes': [
            {
              'id': 302,
              'detail_type': 'check in',
              'old_value': '00:12:41',
              'new_value': '00:12:00',
              'status': 'approved',
              'updated_by_name': 'Owner',
              'created_at': '2026-10-14 00:21:34',
              'updated_at': '2026-10-14 00:22:14',
            }
          ],
        },
        {
          'id': 1452,
          'type': 'check out',
          'attendance_date': '2026-10-13',
          'attendance_time': '22:40:27',
          'current_location': '33.6844,73.0479',
          'change_requests': [],
          'changes': [],
        },
        {
          'id': 1453,
          'type': 'check in',
          'attendance_date': '2026-10-13',
          'attendance_time': '22:42:20',
          'current_location': '33.6844,73.0479',
          'change_requests': [],
          'changes': [],
        },
        {
          'id': 1454,
          'type': 'check out',
          'attendance_date': '2026-10-13',
          'attendance_time': '00:05:00',
          'current_location': '33.6844,73.0479',
          'change_requests': [
            {
              'id': 303,
              'detail_type': 'check out',
              'old_value': null,
              'new_value': '00:05:00',
              'status': 'approved',
              'updated_by_name': 'Owner',
              'created_at': '2026-10-14 00:21:34',
              'updated_at': '2026-10-14 00:22:12',
            }
          ],
          'changes': [
            {
              'id': 303,
              'detail_type': 'check out',
              'old_value': null,
              'new_value': '00:05:00',
              'status': 'approved',
              'updated_by_name': 'Owner',
              'created_at': '2026-10-14 00:21:34',
              'updated_at': '2026-10-14 00:22:12',
            }
          ],
        },
      ],
    });

    final assembled = AttendanceTimelineAssembler.history(
      events: data.toHistoryEvents(),
      day: DateTime(2026, 10, 13),
    );
    final summary = HistoryAttendanceEngine.compute([
      ...assembled.punches,
      ...assembled.pendingAdds,
    ]);

    // Keep the real 12:12 AM check-in (mint window, but not a pending-add stub).
    expect(summary.firstCheckIn, DateTime(2026, 10, 13, 0, 12));
    // Orphan 12:05 AM check-out closes 10:42 PM → next day 12:05 AM.
    expect(summary.lastCheckOut, DateTime(2026, 10, 14, 0, 5));
    expect(summary.isCheckedIn, isFalse);
    // Segments: 12:12 AM→10:40 PM + 10:42 PM→12:05 AM (gap ~2m unpaid).
    expect(
      summary.totalWorkingDuration,
      const Duration(hours: 23, minutes: 51, seconds: 7),
    );
  });
}
