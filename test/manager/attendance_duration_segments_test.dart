import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/attendance_duration.dart';
import 'package:obecno/features/manager_module/Manager_attendance/domain/employee_attendance_mapper.dart';
import 'package:obecno/shared/bottom_sheets/detail_sheets/manager_attendance_details_sheet.dart';

void main() {
  final day = DateTime(2026, 10, 19);
  final now = DateTime(2026, 10, 19, 22, 7); // 10:07 PM

  test('fromWorkSegments sums closed + live open, skips gap', () {
    final label = AttendanceDuration.fromWorkSegments(
      day: day,
      now: now,
      punches: [
        (kind: AttendancePunchKind.checkIn, time: DateTime(2026, 10, 19, 14, 38)),
        (kind: AttendancePunchKind.checkOut, time: DateTime(2026, 10, 19, 15, 32)),
        (kind: AttendancePunchKind.checkIn, time: DateTime(2026, 10, 19, 20, 22)),
      ],
    );
    // 54m closed + 1h 45m open (8:22 → 10:07) = 2h 39m
    expect(label, '2h 39m');
  });

  test('durationFromTimeline parses AM/PM labels onto the day', () {
    final label = EmployeeAttendanceMapper.durationFromTimeline(
      day: day,
      now: now,
      timeline: [
        ManagerAttendanceTimelineEvent(
          type: ManagerAttendanceEventType.checkIn,
          timeLabel: '2:38 PM',
          sortTime: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        ManagerAttendanceTimelineEvent(
          type: ManagerAttendanceEventType.checkOut,
          timeLabel: '3:32 PM',
          sortTime: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        ManagerAttendanceTimelineEvent(
          type: ManagerAttendanceEventType.checkIn,
          timeLabel: '8:22 PM',
          sortTime: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ],
    );
    expect(label, '2h 39m');
  });

}
