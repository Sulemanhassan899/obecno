import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_day.dart';

void main() {
  group('AttendanceHistoryData.fromJson', () {
    test('keeps every history day instead of only today', () {
      final data = AttendanceHistoryData.fromJson({
        'today': '2026-09-14',
        'today_attendance': {'date': '2026-09-14', 'checkin': '12:28:00'},
        'history': [
          {'date': '2026-09-11', 'checkin': '09:01:00', 'checkout': '18:05:00'},
          {'date': '2026-09-10', 'checkin': '08:55:00', 'checkout': '17:40:00'},
        ],
      });

      expect(data.history, hasLength(3));
      expect(data.history.map((day) => day.date.day).toSet(), {14, 11, 10});
      expect(
        data.history.firstWhere((day) => day.date.day == 11).firstCheckIn,
        '09:01:00',
      );
    });

    test('merges today_attendance when history omits today', () {
      final data = AttendanceHistoryData.fromJson({
        'today': '2026-09-14',
        'today_attendance': {'date': '2026-09-14', 'checkin': '12:28:00'},
        'history': [
          {'date': '2026-09-11', 'checkin': '09:01:00', 'checkout': '18:05:00'},
        ],
      });

      final today = data.history.firstWhere((day) => day.date.day == 14);
      expect(today.firstCheckIn, '12:28:00');
    });

    test('reads days from attendances when history is missing', () {
      final data = AttendanceHistoryData.fromJson({
        'attendances': [
          {
            'date': '2026-09-09',
            'check_in': '10:00:00',
            'check_out': '19:00:00',
          },
        ],
      });

      expect(data.history, hasLength(1));
      expect(data.history.single.firstCheckIn, '10:00:00');
      expect(data.history.single.lastCheckOut, '19:00:00');
    });
  });

  group('AttendanceDay.fromApiHistoryItem', () {
    test('accepts check_in type aliases in attendance_details', () {
      final day = AttendanceDay.fromApiHistoryItem({
        'date': '2026-09-11',
        'attendance_details': [
          {'type': 'check_in', 'attendance_time': '09:15:00'},
          {'type': 'check_out', 'attendance_time': '18:00:00'},
        ],
      });

      expect(day.firstCheckIn, '09:15:00');
      expect(day.lastCheckOut, '18:00:00');
    });

    test('falls back to flattened check_in when details types are unknown', () {
      final day = AttendanceDay.fromApiHistoryItem({
        'date': '2026-09-10',
        'check_in': '08:40:00',
        'check_out': '17:10:00',
        'attendance_details': [
          {'type': 'unknown', 'attendance_time': '08:40:00'},
        ],
      });

      expect(day.firstCheckIn, '08:40:00');
      expect(day.lastCheckOut, '17:10:00');
    });

    test('reads punches from a nested attendance object', () {
      final day = AttendanceDay.fromApiHistoryItem({
        'date': '2026-09-08',
        'attendance': {
          'attendance_id': 163,
          'checkin': '11:33:44',
          'checkout': '18:12:00',
        },
      });

      expect(day.recordId, 163);
      expect(day.firstCheckIn, '11:33:44');
      expect(day.lastCheckOut, '18:12:00');
    });
  });
}
