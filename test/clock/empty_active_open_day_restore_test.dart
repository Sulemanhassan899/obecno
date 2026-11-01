import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/constants/app_enums.dart'
    hide AttendanceActionResult;
import 'package:obecno/features/clock/clocks/clocks.dart';
import 'package:obecno/features/clock/domain/controllers/clock_controller.dart';
import 'package:obecno/features/clock/services/employee_trusted_time.dart';
import 'package:obecno/features/clock/services/trusted_time_session.dart';
import 'package:obecno/features/clock/services/trusted_time_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = '28';
  final wallNow = DateTime(2026, 10, 19, 15, 0);

  Future<ClockScreenController> bootWithPrefs(
    Map<String, Object> prefs,
  ) async {
    SharedPreferences.setMockInitialValues(prefs);
    final monotonic = FakeMonotonicClock(const Duration(hours: 10));
    final wall = FakeWallClock(wallNow);
    final session = TrustedTimeSession(
      monotonicClock: monotonic,
      wallClock: wall,
      store: InMemoryTrustedTimeStore(),
    );
    await session.restore();
    await session.login();
    final trusted = EmployeeTrustedTime(session: session);
    await trusted.init();
    final controller = ClockScreenController(
      userId: userId,
      trustedTime: trusted,
    );
    await controller.ensureEventsRestored();
    return controller;
  }

  test('empty active does not revive open day mirror', () async {
    final controller = await bootWithPrefs({
      'clock_events_${userId}_active': '[]',
      'clock_events_${userId}_2026-10-19': jsonEncode([
        {
          'id': '1486',
          'type': 'checkIn',
          'time': '2026-10-19T14:38:49.000',
          'location': 'islamabad blue area',
          'is_valid_location': true,
        },
      ]),
    });
    addTearDown(controller.dispose);

    expect(
      controller.effectiveStatus,
      AttendanceDayStatus.checkedOut,
      reason: 'empty active must stay Check In; server align restores open days',
    );
  });

  test('empty active does not revive closed day mirror', () async {
    final controller = await bootWithPrefs({
      'clock_events_${userId}_active': '[]',
      'clock_events_${userId}_2026-10-19': jsonEncode([
        {
          'id': '1486',
          'type': 'checkIn',
          'time': '2026-10-19T09:00:00.000',
        },
        {
          'id': '1487',
          'type': 'checkOut',
          'time': '2026-10-19T14:00:00.000',
        },
      ]),
    });
    addTearDown(controller.dispose);

    expect(
      controller.effectiveStatus,
      AttendanceDayStatus.checkedOut,
      reason: 'closed day must stay Check In after empty active',
    );
  });
}
