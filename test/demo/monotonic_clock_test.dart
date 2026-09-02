import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/demo/monotonic_clock/clocks/demo_clocks.dart';
import 'package:obecno/demo/monotonic_clock/domain/demo_time_models.dart';
import 'package:obecno/demo/monotonic_clock/services/demo_time_store.dart';
import 'package:obecno/demo/monotonic_clock/services/trusted_time_session.dart';

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
      store: InMemoryDemoTimeStore(),
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

  test('spec: phone 07:00 after actual 10:00 still checks in at 10:00', () async {
    await boot();
    await session.login();

    monotonic.advance(const Duration(hours: 1));
    wall.advance(const Duration(hours: 1));
    wall.setNow(t(7));

    final result = await session.recordEvent(
      type: DemoAttendanceEventType.checkIn,
      networkOnline: true,
    );

    expect(result.isOk, isTrue);
    final event = result.event!;
    expect(event.phoneWallClock, t(7));
    expect(event.loginAnchor.wallClockLocal, loginAt);
    expect(event.calculatedActualTime, t(10));
    expect(event.actualEventTime, t(10));
    expect(event.comparison, TimeComparisonResult.match);
    expect(event.clockChanged, isTrue);
    expect(event.authoritativeTime, t(10));
    expect(event.timeSentToServer, t(10));
    expect(event.synced, isTrue);
  });

  test('forward clock manipulation is ignored (phone 12:00 → check-in 10:00)',
      () async {
    await boot();
    await session.login();

    monotonic.advance(const Duration(hours: 1));
    wall.advance(const Duration(hours: 1));
    wall.setNow(t(12));

    final event = (await session.recordEvent(
      type: DemoAttendanceEventType.checkIn,
      networkOnline: true,
    )).event!;

    expect(event.phoneWallClock, t(12));
    expect(event.calculatedActualTime, t(10));
    expect(event.clockChanged, isTrue);
    expect(event.authoritativeTime, t(10));
    expect(event.timeSentToServer, t(10));
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

    final event = (await session.recordEvent(
      type: DemoAttendanceEventType.checkIn,
      networkOnline: true,
    )).event!;

    expect(session.loginAnchor!.wallClockLocal, loginAt);
    expect(session.latestAppOpen!.wallClockLocal, t(7));
    expect(event.calculatedActualTime, t(10));
    expect(event.authoritativeTime, t(10));
  });

  test('same calculation is used for break in/out and check out', () async {
    await boot();
    await session.login();
    monotonic.advance(const Duration(hours: 1));
    wall.setNow(t(7));

    for (final type in DemoAttendanceEventType.values) {
      monotonic.advance(const Duration(minutes: 5));
      final event = (await session.recordEvent(
        type: type,
        networkOnline: true,
      )).event!;
      expect(event.authoritativeTime, event.calculatedActualTime);
      expect(event.timeSentToServer, event.calculatedActualTime);
      expect(event.phoneWallClock, isNot(event.authoritativeTime));
    }
  });

  test('offline event keeps original timestamp through delayed sync', () async {
    await boot();
    await session.login();
    monotonic.advance(const Duration(hours: 1));
    wall.advance(const Duration(hours: 1));
    wall.setNow(t(7));

    final created = (await session.recordEvent(
      type: DemoAttendanceEventType.checkIn,
      networkOnline: false,
    )).event!;

    expect(created.synced, isFalse);
    expect(created.timeSentToServer, t(10));
    expect(session.pendingSync, hasLength(1));

    wall.setNow(t(5));
    monotonic.advance(const Duration(hours: 1));
    wall.setNow(t(6));

    final sync = await session.syncPending();
    expect(sync.synced, hasLength(1));
    expect(sync.preservedTimestamps.single, t(10));
    expect(sync.synced.single.timeSentToServer, t(10));
    expect(session.pendingSync, isEmpty);
    expect(session.events.single.synced, isTrue);
    expect(session.events.single.timeSentToServer, t(10));
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

    final result = await session.recordEvent(
      type: DemoAttendanceEventType.checkIn,
      networkOnline: true,
    );
    expect(result.isOk, isFalse);
    expect(result.error, contains('reboot'));
  });

  test('process restore keeps login and records a new app-open', () async {
    monotonic = FakeMonotonicClock(const Duration(hours: 8));
    wall = FakeWallClock(loginAt);
    final store = InMemoryDemoTimeStore();
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

  test('scenario 2: close app, rewind phone, check-in sends 1:00 PM not 9:00 AM',
      () async {
    await boot();
    await session.login(sessionId: 'emp_1');
    await session.recordAppClose();

    monotonic.advance(const Duration(hours: 4));
    wall.advance(const Duration(hours: 4));
    wall.setNow(loginAt);
    await session.recordAppOpen();

    final event = (await session.recordEvent(
      type: DemoAttendanceEventType.checkIn,
      networkOnline: true,
    )).event!;

    expect(event.phoneWallClock, loginAt);
    expect(event.calculatedActualTime, t(13));
    expect(event.actualEventTime, t(13));
    expect(event.comparison, TimeComparisonResult.match);
    expect(event.clockChanged, isTrue);
    expect(event.timeSentToServer, t(13));
  });

  test('mismatch uses trusted actual time, not calculated or phone', () async {
    monotonic = FakeMonotonicClock(const Duration(hours: 8));
    wall = FakeWallClock(loginAt);
    session = TrustedTimeSession(
      monotonicClock: monotonic,
      wallClock: wall,
      store: InMemoryDemoTimeStore(),
      trustedActualTimeSource: () async => t(13),
    );
    await session.login();

    final event = (await session.recordEvent(
      type: DemoAttendanceEventType.checkIn,
      networkOnline: true,
    )).event!;

    expect(event.phoneWallClock, loginAt);
    expect(event.calculatedActualTime, loginAt);
    expect(event.actualEventTime, t(13));
    expect(event.comparison, TimeComparisonResult.mismatch);
    expect(event.timeSentToServer, t(13));
  });
}
