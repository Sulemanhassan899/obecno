import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/clock/clocks/clocks.dart';
import 'package:obecno/features/clock/domain/trusted_time_models.dart';
import 'package:obecno/features/clock/services/trusted_time_session.dart';
import 'package:obecno/features/clock/services/trusted_time_store.dart';

void main() {
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
    expect(result.error, contains('reboot'));
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
}

/// Behaves like the `system_clock` stub: elapsed realtime is wall-clock epoch.
class _WallTrackingMonotonicClock implements MonotonicClock {
  _WallTrackingMonotonicClock(this._wall);

  final FakeWallClock _wall;

  @override
  Duration elapsedRealtime() =>
      Duration(milliseconds: _wall.now().millisecondsSinceEpoch);
}
