import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/more/services/native_reminder_scheduler.dart';
import 'package:obecno/features/more/services/reminder_notification_plan.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';

void main() {
  test('health fromMap treats missing exact/battery as allowed', () {
    final health = ReminderHealth.fromMap({
      'notificationsAllowed': true,
      'nextFireAt': DateTime(2026, 9, 17, 8, 55).millisecondsSinceEpoch,
      'nextTitle': 'Time to check in',
      'sdk': 23,
    });
    expect(health.notificationsAllowed, isTrue);
    expect(health.exactAlarmsAllowed, isTrue);
    expect(health.batteryUnrestricted, isTrue);
    expect(health.needsFix, isFalse);
    expect(health.nextTitle, 'Time to check in');
    expect(health.nextFireAt, DateTime(2026, 9, 17, 8, 55));
  });

  test('health needsFix when battery is restricted', () {
    final health = ReminderHealth.fromMap({
      'notificationsAllowed': true,
      'exactAlarmsAllowed': true,
      'batteryUnrestricted': false,
    });
    expect(health.needsFix, isTrue);
    expect(health.batteryUnrestricted, isFalse);
  });

  test('typeForId uses the 14-day id stride', () {
    final today = ReminderNotificationPlan.idFor(ReminderType.checkIn);
    final weekOut = ReminderNotificationPlan.idFor(
      ReminderType.checkIn,
      dayOffset: 13,
    );
    expect(ReminderNotificationPlan.typeForId(today), ReminderType.checkIn);
    expect(ReminderNotificationPlan.typeForId(weekOut), ReminderType.checkIn);
    expect(today, isNot(weekOut));
  });
}
