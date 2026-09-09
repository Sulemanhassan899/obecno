import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/more/services/reminder_notification_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('8:00 AM reminder stays 8:00 in Karachi, not UTC-shifted', () {
    final karachi = tz.getLocation('Asia/Karachi');
    final fireAt = DateTime(2026, 9, 9, 8);
    final scheduled = ReminderNotificationService.localScheduleTime(
      fireAt,
      location: karachi,
    );
    expect(scheduled.hour, 8);
    expect(scheduled.minute, 0);
    expect(scheduled.location.name, 'Asia/Karachi');
  });

  test('5:00 PM reminder stays 5:00 in Karachi', () {
    final karachi = tz.getLocation('Asia/Karachi');
    final fireAt = DateTime(2026, 9, 9, 17);
    final scheduled = ReminderNotificationService.localScheduleTime(
      fireAt,
      location: karachi,
    );
    expect(scheduled.hour, 17);
    expect(scheduled.minute, 0);
  });
}
