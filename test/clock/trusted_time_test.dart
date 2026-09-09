import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/constants/app_enums.dart';
import 'package:obecno/features/clock/clocks/clocks.dart';
import 'package:obecno/features/clock/data/models/clock_attendence_event.dart';
import 'package:obecno/features/clock/domain/trusted_time_models.dart';
import 'package:obecno/features/clock/presentation/widgets/clock_attendance_engine.dart';
import 'package:obecno/features/clock/services/employee_trusted_time.dart';
import 'package:obecno/features/clock/services/trusted_time_session.dart';
import 'package:obecno/features/clock/services/trusted_time_store.dart';
import 'package:obecno/shared/location/service/attendance_payload_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeMonotonicClock monotonic;
  late FakeWallClock wall;
  late TrustedTimeSession session;

  final loginAt = DateTime(2026, 8, 30, 9, 0);

  Future<TrustedTimeSession> boot({
    DateTime? now,
    Duration elapsed = const Duration(hours: 8),
  }) async {
    monotonic = FakeMonotonicClock(elapsed);
    wall = FakeWallClock(now ?? loginAt);
    session = TrustedTimeSession(
      monotonicClock: monotonic,
      wallClock: wall,
      store: InMemoryTrustedTimeStore(),
    );
    await session.restore();
    return session;
  }

  DateTime t(int hour, [int minute = 0]) => DateTime(2026, 8, 30, hour, minute);

  test('login stores wall, utc, timezone, and monotonic; first app-open matches',
      () async {
    await boot();
    final login = await session.login();

    expect(login.wallClockLocal, loginAt);
    expect(login.wallClockUtc, loginAt.toUtc());
    expect(login.timezoneOffset, loginAt.timeZoneOffset);
    expect(login.timezoneName, loginAt.timeZoneName);
    expect(login.monotonicElapsed, const Duration(hours: 8));
    expect(session.latestAppOpen!.wallClockLocal, loginAt);
    expect(session.appOpens, hasLength(1));
  });

  test('app reopen does not replace the login timestamp', () async {
    await boot();
    await session.login();

    monotonic.advance(const Duration(hours: 1));
    wall.advance(const Duration(hours: 1));
    await session.recordAppOpen();

    monotonic.advance(const Duration(hours: 1, minutes: 25));
    wall.advance(const Duration(hours: 1, minutes: 25));
    await session.recordAppOpen();

    expect(session.loginAnchor!.wallClockLocal, loginAt);
    expect(session.appOpens, hasLength(3));
    expect(session.latestAppOpen!.wallClockLocal, t(11, 25));
  });

  test('session expire then login creates a NEW login timestamp', () async {
    await boot();
    await session.login();
    final first = session.loginAnchor!.wallClockLocal;

    monotonic.advance(const Duration(hours: 2));
    wall.advance(const Duration(hours: 2));
    await session.expireSession();
    await session.login();

    expect(session.loginAnchor!.wallClockLocal, isNot(first));
    expect(session.loginAnchor!.wallClockLocal, t(11));
    expect(session.appOpens, hasLength(1));
  });

  test('spec: phone 07:00 after actual 10:00 still punches at 10:00', () async {
    await boot();
    await session.login();

    monotonic.advance(const Duration(hours: 1));
    wall.advance(const Duration(hours: 1));
    wall.setNow(t(7));

    final result = await session.issuePunch(networkOnline: true);

    expect(result.isOk, isTrue);
    final punch = result.punch!;
    expect(punch.phoneWallClock, t(7));
    expect(punch.loginAnchor.wallClockLocal, loginAt);
    expect(punch.calculatedActualTime, t(10));
    expect(punch.actualEventTime, t(10));
    expect(punch.comparison, TimeComparisonResult.match);
    expect(punch.clockChanged, isTrue);
    expect(punch.timeSentToServer, t(10));
  });

  test('forward clock manipulation is ignored (phone 12:00 → punch 10:00)',
      () async {
    await boot();
    await session.login();

    monotonic.advance(const Duration(hours: 1));
    wall.advance(const Duration(hours: 1));
    wall.setNow(t(12));

    final punch = (await session.issuePunch(networkOnline: true)).punch!;

    expect(punch.phoneWallClock, t(12));
    expect(punch.calculatedActualTime, t(10));
    expect(punch.clockChanged, isTrue);
    expect(punch.timeSentToServer, t(10));
  });

  test('multiple wall-clock jumps do not move calculated actual time', () async {
    await boot();
    await session.login();
    monotonic.advance(const Duration(hours: 1));

    for (final hour in [8, 12, 7, 11]) {
      wall.setNow(t(hour));
      final snap = session.currentSnapshot(networkOnline: true);
      expect(snap.calculatedActualTime, t(10));
      expect(snap.clockChange.changed, isTrue);
    }
  });

  test('app-open after clock change does not reset the attendance timeline',
      () async {
    await boot();
    await session.login();

    monotonic.advance(const Duration(hours: 1));
    wall.advance(const Duration(hours: 1));
    wall.setNow(t(7));
    await session.recordAppOpen();

    final punch = (await session.issuePunch(networkOnline: true)).punch!;

    expect(session.loginAnchor!.wallClockLocal, loginAt);
    expect(session.latestAppOpen!.wallClockLocal, t(7));
    expect(punch.calculatedActualTime, t(10));
    expect(punch.timeSentToServer, t(10));
  });

  test('same calculation is used for every punch', () async {
    await boot();
    await session.login();
    monotonic.advance(const Duration(hours: 1));
    wall.setNow(t(7));

    for (var i = 0; i < 4; i++) {
      monotonic.advance(const Duration(minutes: 5));
      final punch = (await session.issuePunch(networkOnline: true)).punch!;
      expect(punch.timeSentToServer, punch.calculatedActualTime);
      expect(punch.phoneWallClock, isNot(punch.timeSentToServer));
    }
  });

  test('offline punch keeps original timestamp when clocks move later',
      () async {
    await boot();
    await session.login();
    monotonic.advance(const Duration(hours: 1));
    wall.advance(const Duration(hours: 1));
    wall.setNow(t(7));

    final created = (await session.issuePunch(networkOnline: false)).punch!;

    expect(created.timeSentToServer, t(10));
    expect(created.networkOnline, isFalse);

    wall.setNow(t(5));
    monotonic.advance(const Duration(hours: 1));
    wall.setNow(t(6));

    // Frozen: the issued time is not recalculated by later clock movement.
    expect(created.timeSentToServer, t(10));
  });

  test('reboot refuses to invent an authoritative timestamp', () async {
    await boot();
    await session.login();
    monotonic.advance(const Duration(hours: 1));
    monotonic.simulateReboot(elapsed: const Duration(seconds: 20));

    final snap = session.currentSnapshot(networkOnline: true);
    expect(snap.rebootDetected, isTrue);
    expect(snap.calculatedActualTime, isNull);
    expect(snap.canIssueAuthoritativeTime, isFalse);

    final result = await session.issuePunch(networkOnline: true);
    expect(result.isOk, isFalse);
    expect(result.error, TrustedTimeMessages.sessionEnded);
    expect(session.sessionActive, isFalse);
    expect(session.endedByReboot, isTrue);
    expect(session.loginAnchor, isNull);
  });

  test('restore after reboot ends session even with no punches', () async {
    monotonic = FakeMonotonicClock(const Duration(hours: 8));
    wall = FakeWallClock(loginAt);
    final store = InMemoryTrustedTimeStore();
    final first = TrustedTimeSession(
      monotonicClock: monotonic,
      wallClock: wall,
      store: store,
    );
    await first.login();
    monotonic.simulateReboot(elapsed: Duration.zero);

    final restored = TrustedTimeSession(
      monotonicClock: monotonic,
      wallClock: wall,
      store: store,
    );
    await restored.restore();
    expect(restored.sessionActive, isFalse);
    expect(restored.endedByReboot, isTrue);
    expect(restored.loginAnchor, isNull);
    expect(restored.currentSnapshot(networkOnline: true).canIssueAuthoritativeTime,
        isFalse);
  });

  test('restore after reboot ends session after check-in punch', () async {
    monotonic = FakeMonotonicClock(const Duration(hours: 8));
    wall = FakeWallClock(loginAt);
    final store = InMemoryTrustedTimeStore();
    final first = TrustedTimeSession(
      monotonicClock: monotonic,
      wallClock: wall,
      store: store,
    );
    await first.login();
    monotonic.advance(const Duration(minutes: 15));
    wall.advance(const Duration(minutes: 15));
    expect((await first.issuePunch(networkOnline: true)).isOk, isTrue);

    monotonic.simulateReboot(elapsed: const Duration(seconds: 5));
    wall.advance(const Duration(minutes: 1));

    final restored = TrustedTimeSession(
      monotonicClock: monotonic,
      wallClock: wall,
      store: store,
    );
    await restored.restore();
    expect(restored.endedByReboot, isTrue);
    expect(restored.sessionActive, isFalse);
    final result = await restored.issuePunch(networkOnline: true);
    expect(result.isOk, isFalse);
    expect(result.error, TrustedTimeMessages.sessionEnded);
  });

  test('ensureLogin after reboot logs out and does not create a new login',
      () async {
    await boot();
    await session.login(sessionId: EmployeeTrustedTime.sessionIdFor('1'));
    monotonic.simulateReboot(elapsed: Duration.zero);

    String? logoutMessage;
    final trusted = EmployeeTrustedTime(
      session: session,
      monotonicClock: monotonic,
      wallClock: wall,
    );
    trusted.onRebootSessionEnded = (message) async {
      logoutMessage = message;
    };
    await trusted.init();
    await trusted.ensureLogin(userId: '1');

    expect(logoutMessage, TrustedTimeMessages.sessionEnded);
    expect(session.sessionActive, isFalse);
    expect(session.loginAnchor, isNull);
    expect(trusted.attachedUserId, isNull);

    await trusted.ensureLogin(userId: '1', createIfMissing: true);
    expect(session.sessionActive, isFalse);

    await trusted.captureAuthenticatedLogin(userId: '1');
    expect(session.sessionActive, isTrue);
    expect(session.loginAnchor, isNotNull);
    trusted.dispose();
  });

  test('process restore keeps login and records a new app-open', () async {
    monotonic = FakeMonotonicClock(const Duration(hours: 8));
    wall = FakeWallClock(loginAt);
    final store = InMemoryTrustedTimeStore();
    final first = TrustedTimeSession(
      monotonicClock: monotonic,
      wallClock: wall,
      store: store,
    );
    await first.login();
    monotonic.advance(const Duration(minutes: 30));
    wall.advance(const Duration(minutes: 30));

    final restored = TrustedTimeSession(
      monotonicClock: monotonic,
      wallClock: wall,
      store: store,
    );
    await restored.restore();
    expect(restored.loginAnchor!.wallClockLocal, loginAt);
    await restored.recordAppOpen(reason: 'process_start');
    expect(restored.loginAnchor!.wallClockLocal, loginAt);
    expect(restored.appOpens.length, greaterThan(1));

    final snap = restored.currentSnapshot(networkOnline: true);
    expect(snap.calculatedActualTime, t(9, 30));
  });

  test('normal progression: wall and monotonic move together → no clock change',
      () async {
    await boot();
    await session.login();
    monotonic.advance(const Duration(minutes: 90));
    wall.advance(const Duration(minutes: 90));

    final snap = session.currentSnapshot(networkOnline: true);
    expect(snap.calculatedActualTime, t(10, 30));
    expect(snap.clockChange.changed, isFalse);
    expect(snap.clockChange.difference, Duration.zero);
  });

  test('app close does not replace the login timestamp', () async {
    await boot();
    await session.login();
    monotonic.advance(const Duration(hours: 4));
    wall.advance(const Duration(hours: 4));
    await session.recordAppClose();

    expect(session.loginAnchor!.wallClockLocal, loginAt);
    expect(session.latestAppClose!.wallClockLocal, t(13));
    expect(session.appCloses, hasLength(1));
  });

  test('close app, rewind phone, punch sends 1:00 PM not 9:00 AM', () async {
    await boot();
    await session.login(sessionId: 'emp_1');
    await session.recordAppClose();

    monotonic.advance(const Duration(hours: 4));
    wall.advance(const Duration(hours: 4));
    wall.setNow(loginAt);
    await session.recordAppOpen();

    final punch = (await session.issuePunch(networkOnline: true)).punch!;

    expect(punch.phoneWallClock, loginAt);
    expect(punch.calculatedActualTime, t(13));
    expect(punch.actualEventTime, t(13));
    expect(punch.comparison, TimeComparisonResult.match);
    expect(punch.clockChanged, isTrue);
    expect(punch.timeSentToServer, t(13));
  });

  test('mismatch uses trusted actual time, not calculated or phone', () async {
    monotonic = FakeMonotonicClock(const Duration(hours: 8));
    wall = FakeWallClock(loginAt);
    session = TrustedTimeSession(
      monotonicClock: monotonic,
      wallClock: wall,
      store: InMemoryTrustedTimeStore(),
      trustedActualTimeSource: () async => t(13),
    );
    await session.login();

    final punch = (await session.issuePunch(networkOnline: true)).punch!;

    expect(punch.phoneWallClock, loginAt);
    expect(punch.calculatedActualTime, loginAt);
    expect(punch.actualEventTime, t(13));
    expect(punch.comparison, TimeComparisonResult.mismatch);
    expect(punch.timeSentToServer, t(13));
  });

  test('displayNow uses calculated actual time, not the phone clock', () async {
    await boot();
    await session.login();
    monotonic.advance(const Duration(hours: 4));
    wall.setNow(t(7));

    expect(session.displayNow(), t(13));
  });

  test(
    'anchored monotonic clock does not follow a wall-tracking native clock',
    () {
      final wall = FakeWallClock(loginAt);
      final native = _WallTrackingMonotonicClock(wall);
      final anchored = AnchoredMonotonicClock(native);
      final start = anchored.elapsedRealtime();

      wall.setNow(t(21, 25));

      final elapsed = anchored.elapsedRealtime() - start;
      expect(elapsed.inHours, lessThan(1));
      expect(
        native.elapsedRealtime() - Duration(milliseconds: loginAt.millisecondsSinceEpoch),
        const Duration(hours: 12, minutes: 25),
      );
    },
  );

  test(
    'phone rewind after login still sends login+elapsed, never 9:25 phone time',
    () async {
      final wall = FakeWallClock(loginAt);
      session = TrustedTimeSession(
        monotonicClock: AnchoredMonotonicClock(_WallTrackingMonotonicClock(wall)),
        wallClock: wall,
        store: InMemoryTrustedTimeStore(),
      );
      await session.login();

      wall.setNow(t(12));
      final checkIn = (await session.issuePunch(networkOnline: true)).punch!;
      expect(checkIn.phoneWallClock, t(12));
      expect(checkIn.timeSentToServer.hour, 9);
      expect(checkIn.timeSentToServer.minute, 0);

      wall.setNow(t(21, 25));
      final breakIn = (await session.issuePunch(networkOnline: true)).punch!;
      expect(breakIn.phoneWallClock, t(21, 25));
      expect(breakIn.timeSentToServer.hour, isNot(21));
      expect(breakIn.timeSentToServer.hour, 9);
    },
  );

  test(
    'boot clock sleep is counted: 5:59 check-in then 36m elapsed → 6:35 punch',
    () async {
      monotonic = FakeMonotonicClock(const Duration(hours: 10, minutes: 59));
      wall = FakeWallClock(t(17, 59));
      session = TrustedTimeSession(
        monotonicClock: AnchoredMonotonicClock(monotonic),
        wallClock: wall,
        store: InMemoryTrustedTimeStore(),
      );
      await session.login();

      final checkIn = (await session.issuePunch(networkOnline: true)).punch!;
      expect(checkIn.timeSentToServer, t(17, 59));

      // Phone slept / app backgrounded: native boot clock keeps going.
      // Dart Stopwatch on the wrapper must not freeze punch time.
      monotonic.advance(const Duration(minutes: 36));
      wall.advance(const Duration(minutes: 36));

      final checkOut = (await session.issuePunch(networkOnline: true)).punch!;
      expect(checkOut.timeSentToServer, t(18, 35));
      expect(
        checkOut.timeSentToServer.difference(checkIn.timeSentToServer),
        const Duration(minutes: 36),
      );
    },
  );

  test(
    'anchored wrapper follows a real boot clock, not a frozen Stopwatch',
    () {
      final native = FakeMonotonicClock(const Duration(hours: 8));
      final anchored = AnchoredMonotonicClock(native);
      final atWrap = anchored.elapsedRealtime();

      native.advance(const Duration(minutes: 36));

      expect(
        anchored.elapsedRealtime() - atWrap,
        const Duration(minutes: 36),
      );
    },
  );

  test('check-in 5:59 PM / check-out 6:35 PM stamps both from login+elapsed',
      () async {
    await boot(now: t(9), elapsed: const Duration(hours: 8));
    await session.login();

    monotonic.advance(const Duration(hours: 8, minutes: 59));
    wall.advance(const Duration(hours: 8, minutes: 59));
    final checkIn = (await session.issuePunch(networkOnline: true)).punch!;
    expect(checkIn.timeSentToServer, t(17, 59));

    monotonic.advance(const Duration(minutes: 36));
    wall.advance(const Duration(minutes: 36));
    final checkOut = (await session.issuePunch(networkOnline: true)).punch!;
    expect(checkOut.timeSentToServer, t(18, 35));
    expect(session.displayNow(), t(18, 35));

    final summary = AttendanceEngine.compute([
      AttendanceEvent(
        id: 'in',
        type: AttendanceEventType.checkIn,
        time: checkIn.timeSentToServer,
      ),
      AttendanceEvent(
        id: 'out',
        type: AttendanceEventType.checkOut,
        time: checkOut.timeSentToServer,
      ),
    ]);
    expect(summary.firstCheckIn, t(17, 59));
    expect(summary.lastCheckOut, t(18, 35));
    expect(summary.totalWorkingDuration, const Duration(minutes: 36));
  });

  test('phone clock jump during a session does not move either punch',
      () async {
    await boot();
    await session.login();

    monotonic.advance(const Duration(hours: 8, minutes: 59));
    wall.setNow(t(21));
    final checkIn = (await session.issuePunch(networkOnline: true)).punch!;
    expect(checkIn.timeSentToServer, t(17, 59));
    expect(checkIn.phoneWallClock, t(21));
    expect(checkIn.clockChanged, isTrue);

    monotonic.advance(const Duration(minutes: 36));
    wall.setNow(t(7));
    final checkOut = (await session.issuePunch(networkOnline: true)).punch!;
    expect(checkOut.timeSentToServer, t(18, 35));
    expect(checkOut.phoneWallClock, t(7));
  });

  test('app close then open does not replace punch timeline', () async {
    await boot(now: t(17, 59), elapsed: const Duration(hours: 10, minutes: 59));
    await session.login();
    final checkIn = (await session.issuePunch(networkOnline: true)).punch!;

    await session.recordAppClose();
    monotonic.advance(const Duration(minutes: 24));
    wall.advance(const Duration(minutes: 24));
    await session.recordAppOpen();
    monotonic.advance(const Duration(minutes: 12));
    wall.advance(const Duration(minutes: 12));

    final checkOut = (await session.issuePunch(networkOnline: true)).punch!;
    expect(session.loginAnchor!.wallClockLocal, t(17, 59));
    expect(checkIn.timeSentToServer, t(17, 59));
    expect(checkOut.timeSentToServer, t(18, 35));
  });

  test('process restore after 36m still punches login + elapsed', () async {
    monotonic = FakeMonotonicClock(const Duration(hours: 10, minutes: 59));
    wall = FakeWallClock(t(17, 59));
    final store = InMemoryTrustedTimeStore();
    final first = TrustedTimeSession(
      monotonicClock: monotonic,
      wallClock: wall,
      store: store,
    );
    await first.login();
    await first.issuePunch(networkOnline: true);

    monotonic.advance(const Duration(minutes: 36));
    wall.advance(const Duration(minutes: 36));

    final restored = TrustedTimeSession(
      monotonicClock: monotonic,
      wallClock: wall,
      store: store,
    );
    await restored.restore();
    expect(restored.loginAnchor!.wallClockLocal, t(17, 59));

    final checkOut = (await restored.issuePunch(networkOnline: true)).punch!;
    expect(checkOut.timeSentToServer, t(18, 35));
  });

  test(
    'production wrap: new AnchoredMonotonicClock after process death still '
    'stamps 6:35 from boot elapsed, not Stopwatch zero',
    () async {
      monotonic = FakeMonotonicClock(const Duration(hours: 10, minutes: 59));
      wall = FakeWallClock(t(17, 59));
      final store = InMemoryTrustedTimeStore();
      final first = TrustedTimeSession(
        monotonicClock: AnchoredMonotonicClock(monotonic),
        wallClock: wall,
        store: store,
      );
      await first.login();
      final checkIn = (await first.issuePunch(networkOnline: true)).punch!;
      expect(checkIn.timeSentToServer, t(17, 59));

      monotonic.advance(const Duration(minutes: 36));
      wall.advance(const Duration(minutes: 36));

      // App killed and restarted: EmployeeTrustedTime.init() builds a NEW
      // AnchoredMonotonicClock around the same native boot clock.
      final restored = TrustedTimeSession(
        monotonicClock: AnchoredMonotonicClock(monotonic),
        wallClock: wall,
        store: store,
      );
      await restored.restore();
      expect(restored.displayNow(), t(18, 35));
      final checkOut = (await restored.issuePunch(networkOnline: true)).punch!;
      expect(checkOut.timeSentToServer, t(18, 35));
      expect(checkOut.timeSentToServer, restored.displayNow());
    },
  );

  test('login JSON roundtrip does not shift punch time by timezone', () async {
    await boot(now: t(17, 59), elapsed: const Duration(hours: 10, minutes: 59));
    await session.login();
    final raw = session.loginAnchor!.toJson();
    final restored = TimeAnchor.fromJson(raw);

    expect(restored.wallClockLocal, t(17, 59));
    expect(restored.wallClockLocal.isUtc, isFalse);
    expect(restored.monotonicElapsed, const Duration(hours: 10, minutes: 59));

    monotonic.advance(const Duration(minutes: 36));
    final calculated = restored.wallClockLocal.add(
      monotonic.elapsedRealtime() - restored.monotonicElapsed,
    );
    expect(calculated, t(18, 35));
  });

  test('displayNow and issuePunch use the same calculated instant', () async {
    await boot(now: t(17, 59), elapsed: const Duration(hours: 10, minutes: 59));
    await session.login();
    monotonic.advance(const Duration(minutes: 36));
    wall.advance(const Duration(minutes: 36));

    final shown = session.displayNow();
    final punch = (await session.issuePunch(networkOnline: true)).punch!;
    expect(shown, t(18, 35));
    expect(punch.timeSentToServer, shown);
    expect(punch.phoneWallClock, t(18, 35));
  });

  test('API datetime is local trusted punch time, not UTC and not phone',
      () async {
    await boot();
    await session.login();
    monotonic.advance(const Duration(hours: 8, minutes: 59));
    wall.setNow(t(7));

    final punch = (await session.issuePunch(networkOnline: true)).punch!;
    expect(punch.timeSentToServer, t(17, 59));
    expect(punch.phoneWallClock, t(7));

    final payload = AttendancePayloadModel(
      action: AttendanceAction.checkIn,
      capturedAt: punch.timeSentToServer,
    );
    expect(payload.datetime, '2026-08-30 17:59:00');
    expect(payload.time, '17:59:00');
  });

  test('rewind phone after sleep still sends 6:35, header matches punch',
      () async {
    await boot(now: t(17, 59), elapsed: const Duration(hours: 10, minutes: 59));
    await session.login();
    final checkIn = (await session.issuePunch(networkOnline: true)).punch!;

    monotonic.advance(const Duration(minutes: 36));
    wall.setNow(t(9, 25));

    expect(session.displayNow(), t(18, 35));
    final checkOut = (await session.issuePunch(networkOnline: true)).punch!;
    expect(checkIn.timeSentToServer, t(17, 59));
    expect(checkOut.timeSentToServer, t(18, 35));
    expect(checkOut.phoneWallClock, t(9, 25));
    expect(checkOut.clockChanged, isTrue);
  });

  test('system monotonic clock is boot-sized, not wall-epoch', () {
    final elapsed = const SystemMonotonicClock().elapsedRealtime();
    expect(
      AnchoredMonotonicClock.looksLikeWallClock(elapsed),
      isFalse,
      reason:
          'native=${elapsed.inMilliseconds}ms (${elapsed.inHours}h). '
          'A wall-epoch reading would make production use Stopwatch and '
          'lag after sleep / pick login time instead of real time.',
    );
  });
}

/// Behaves like the `system_clock` stub: elapsed realtime is wall-clock epoch.
class _WallTrackingMonotonicClock implements MonotonicClock {
  _WallTrackingMonotonicClock(this._wall);

  final FakeWallClock _wall;

  @override
  Duration elapsedRealtime() =>
      Duration(milliseconds: _wall.now().millisecondsSinceEpoch);
}
