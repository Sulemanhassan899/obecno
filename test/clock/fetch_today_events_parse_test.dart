import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/employee_module/attendance/data/models/attendance_details_data.dart';

void main() {
  group('Attendance details parse aliases (clock sync)', () {
    test('parses check_in action + time field used by portal payloads', () {
      final item = AttendanceDetailItem.tryParse({
        'id': 99,
        'action': 'check_in',
        'attendance_date': '2026-10-13',
        'time': '12:12 AM',
      });

      expect(item, isNotNull);
      expect(item!.type, AttendanceHisotryEventType.checkIn);
      expect(item.time, DateTime(2026, 10, 13, 0, 12));
    });

    test('parses punch_time with type clockin', () {
      final item = AttendanceDetailItem.tryParse({
        'id': 100,
        'type': 'clockin',
        'attendance_date': '2026-10-13',
        'punch_time': '00:12:00',
      });

      expect(item, isNotNull);
      expect(item!.type, AttendanceHisotryEventType.checkIn);
      expect(item.time.hour, 0);
      expect(item.time.minute, 12);
    });

    test('toClockEvents keeps a real 12:12 AM check-in', () {
      final data = AttendanceDetailsData.fromJson({
        'date': '2026-10-13',
        'attendance_details': [
          {
            'id': 1,
            'type': 'Check In',
            'attendance_date': '2026-10-13',
            'attendance_time': '12:12 AM',
          },
        ],
      });

      final events = data.toClockEvents();
      expect(events, hasLength(1));
      expect(events.single.type.name, 'checkIn');
      expect(events.single.time, DateTime(2026, 10, 13, 0, 12));
    });
  });
}
