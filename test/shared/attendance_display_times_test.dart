import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/shared_attendance/attendance_display_times.dart';

void main() {
  group('AttendanceDisplayTimes', () {
    final first = DateTime(2026, 10, 23, 9);
    final lastOut = DateTime(2026, 10, 23, 18);

    test('check-in is always first of day', () {
      expect(
        AttendanceDisplayTimes.displayCheckIn(firstCheckIn: first),
        first,
      );
      expect(
        AttendanceDisplayTimes.displayCheckIn(firstCheckIn: null),
        isNull,
      );
    });

    test('check-out hidden while day open', () {
      expect(
        AttendanceDisplayTimes.displayCheckOut(
          dayStillOpen: true,
          lastCheckOut: lastOut,
        ),
        isNull,
      );
    });

    test('check-out shows last out when day closed', () {
      expect(
        AttendanceDisplayTimes.displayCheckOut(
          dayStillOpen: false,
          lastCheckOut: lastOut,
        ),
        lastOut,
      );
    });
  });
}
