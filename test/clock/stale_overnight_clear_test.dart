import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/constants/app_enums.dart'
    hide AttendanceActionResult;
import 'package:obecno/features/clock/clocks/clocks.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:obecno/features/clock/domain/controllers/clock_controller.dart';
import 'package:obecno/features/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:obecno/features/clock/services/employee_trusted_time.dart';
import 'package:obecno/features/clock/services/trusted_time_session.dart';
import 'package:obecno/features/clock/services/trusted_time_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final portalOct13 = [
    AttendanceEvent(
      id: '1437',
      type: AttendanceEventType.checkIn,
      time: DateTime(2026, 10, 13, 0, 12),
    ),
    AttendanceEvent(
      id: '1452',
      type: AttendanceEventType.checkOut,
      time: DateTime(2026, 10, 13, 22, 40, 27),
    ),
    AttendanceEvent(
      id: '1453',
      type: AttendanceEventType.checkIn,
      time: DateTime(2026, 10, 13, 22, 42, 20),
    ),
    AttendanceEvent(
      id: '1454',
      type: AttendanceEventType.checkOut,
      time: DateTime(2026, 10, 13, 0, 5),
    ),
  ];

  test('AttendanceEngine: portal Oct 13 is checked out', () {
    final y = AttendanceEngine.compute(portalOct13);
    expect(y.isCheckedIn, isFalse);
    expect(y.lastCheckOut, DateTime(2026, 10, 14, 0, 5));
  });

  test('Clock card on Oct 14 does not keep ghost 10:42 PM Check Out', () async {
    SharedPreferences.setMockInitialValues({});
    // Monotonic elapsed ≈ hours since a fixed epoch; wall = Oct 14 1:50 AM.
    final wallNow = DateTime(2026, 10, 14, 1, 50);
    final monotonic = FakeMonotonicClock(const Duration(hours: 30));
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
      userId: 'emp-ghost',
      trustedTime: trusted,
    );
    addTearDown(controller.dispose);

    // Server truth for yesterday landed in live events (after reconcile).
    controller.mergeTodayEvents(portalOct13);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.clockNow.day, 14);
    expect(
      controller.effectiveStatus,
      AttendanceDayStatus.checkedOut,
      reason: 'closed overnight session must not drive Check Out on next day',
    );
    expect(controller.events, isEmpty);
  });
}
