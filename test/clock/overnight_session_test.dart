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

  late FakeMonotonicClock monotonic;
  late FakeWallClock wall;

  final checkInAt = DateTime(2026, 10, 8, 21); // 8 Oct 9:00 PM

  Future<ClockScreenController> bootAt(DateTime now) async {
    SharedPreferences.setMockInitialValues({});
    monotonic = FakeMonotonicClock(const Duration(hours: 8));
    wall = FakeWallClock(now);
    final session = TrustedTimeSession(
      monotonicClock: monotonic,
      wallClock: wall,
      store: InMemoryTrustedTimeStore(),
    );
    await session.restore();
    await session.login();

    final trusted = EmployeeTrustedTime(session: session);
    await trusted.init();
    return ClockScreenController(userId: 'emp-overnight', trustedTime: trusted);
  }

  void advance(Duration duration) {
    monotonic.advance(duration);
    wall.advance(duration);
  }

  Future<void> waitCooldown() => Future<void>.delayed(
        ClockScreenController.actionCooldown + const Duration(milliseconds: 50),
      );

  test('open overnight session stays checked in past midnight', () async {
    final controller = await bootAt(checkInAt);
    addTearDown(controller.dispose);

    expect(await controller.handleMainTap(), AttendanceActionResult.checkedIn);
    expect(controller.effectiveStatus, AttendanceDayStatus.checkedIn);

    // 8 Oct 9 PM → 9 Oct 1 AM
    advance(const Duration(hours: 4));
    expect(controller.clockNow, DateTime(2026, 10, 9, 1));
    expect(controller.effectiveStatus, AttendanceDayStatus.checkedIn);
    expect(
      controller.events.map((e) => e.type),
      [AttendanceEventType.checkIn],
    );
  });

  test('overnight break and check-out stay on the open session', () async {
    final controller = await bootAt(checkInAt);
    addTearDown(controller.dispose);

    expect(await controller.handleMainTap(), AttendanceActionResult.checkedIn);

    advance(const Duration(hours: 4)); // 9 Oct 1 AM
    await waitCooldown();
    expect(await controller.handleBreakTap(), AttendanceActionResult.breakStarted);
    expect(controller.effectiveStatus, AttendanceDayStatus.onBreak);

    advance(const Duration(hours: 1)); // 9 Oct 2 AM
    await waitCooldown();
    expect(await controller.handleMainTap(), AttendanceActionResult.breakEnded);

    advance(const Duration(hours: 4)); // 9 Oct 6 AM
    await waitCooldown();
    expect(await controller.handleMainTap(), AttendanceActionResult.checkedOut);
    expect(controller.effectiveStatus, AttendanceDayStatus.checkedOut);

    // Closed overnight session is owned by check-in day (8 Oct), so the
    // live clock on 9 Oct is ready for a new Check In.
    expect(controller.events, isEmpty);
    expect(controller.hasAnyEventToday, isFalse);
  });

  test('button resets to Check In 24h after check-in if never checked out',
      () async {
    final controller = await bootAt(checkInAt);
    addTearDown(controller.dispose);

    expect(await controller.handleMainTap(), AttendanceActionResult.checkedIn);
    controller.selectLocation('HQ', inRange: true);

    advance(const Duration(hours: 23, minutes: 59));
    expect(controller.effectiveStatus, AttendanceDayStatus.checkedIn);

    advance(const Duration(minutes: 1)); // exactly 24h
    expect(controller.clockNow, DateTime(2026, 10, 9, 21));

    // Auto check-out punches time + location, then button resets.
    expect(
      await controller.ensureMaxSessionAutoCheckout(),
      AttendanceActionResult.checkedOut,
    );
    expect(controller.effectiveStatus, AttendanceDayStatus.checkedOut);
    expect(controller.events, isEmpty);

    // Session (incl. auto check-out) is kept under the check-in calendar day.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('clock_events_emp-overnight_2026-10-8');
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as List<dynamic>;
    final types = decoded
        .whereType<Map>()
        .map((e) => e['type'] as String?)
        .toList();
    expect(types, containsAll(['checkIn', 'checkOut']));
    final checkOut = decoded.whereType<Map>().firstWhere(
      (e) => e['type'] == 'checkOut',
    );
    expect(checkOut['location'], 'HQ');
  });

  test('same-day completed session still shows on the check-in calendar day',
      () async {
    final morning = DateTime(2026, 10, 9, 10);
    final controller = await bootAt(morning);
    addTearDown(controller.dispose);

    expect(await controller.handleMainTap(), AttendanceActionResult.checkedIn);
    advance(const Duration(hours: 4)); // 2 PM
    await waitCooldown();
    expect(await controller.handleMainTap(), AttendanceActionResult.checkedOut);

    expect(controller.effectiveStatus, AttendanceDayStatus.checkedOut);
    expect(
      controller.events.map((e) => e.type),
      [AttendanceEventType.checkIn, AttendanceEventType.checkOut],
    );
  });

  test('persists open overnight session across controller recreate', () async {
    final first = await bootAt(checkInAt);
    expect(await first.handleMainTap(), AttendanceActionResult.checkedIn);
    // Let persist finish.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    first.dispose();

    advance(const Duration(hours: 4)); // 9 Oct 1 AM

    final session = TrustedTimeSession(
      monotonicClock: monotonic,
      wallClock: wall,
      store: InMemoryTrustedTimeStore(),
    );
    await session.restore();
    await session.login();
    final trusted = EmployeeTrustedTime(session: session);
    await trusted.init();

    final second = ClockScreenController(
      userId: 'emp-overnight',
      trustedTime: trusted,
    );
    addTearDown(second.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(second.effectiveStatus, AttendanceDayStatus.checkedIn);
    expect(
      second.events.map((e) => e.type),
      [AttendanceEventType.checkIn],
    );
  });
}
