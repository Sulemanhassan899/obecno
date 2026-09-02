import 'package:flutter/foundation.dart';
import 'package:obecno/demo/monotonic_clock/clocks/demo_clocks.dart';
import 'package:obecno/demo/monotonic_clock/domain/demo_time_models.dart';
import 'package:obecno/demo/monotonic_clock/services/demo_offline_queue.dart';
import 'package:obecno/demo/monotonic_clock/services/demo_time_store.dart';
import 'package:obecno/demo/monotonic_clock/services/trusted_time_calculator.dart';

void _log(String message) {
  debugPrint('[MONOTONIC_DEMO] $message');
}

/// Optional extra trusted time (e.g. HTTP Date). When it disagrees with
/// the monotonic calculation, the event is a MISMATCH and the trusted
/// time is sent. Phone wall-clock is never sent.
typedef TrustedActualTimeSource = Future<DateTime?> Function();

/// Session-scoped trusted time. Login is the session anchor. Every app
/// open and app close gets its own timestamp and does NOT replace login.
class TrustedTimeSession {
  TrustedTimeSession({
    required MonotonicClock monotonicClock,
    required WallClock wallClock,
    required DemoTimeStore store,
    TrustedTimeCalculator calculator = const TrustedTimeCalculator(),
    DemoOfflineQueue? queue,
    this.trustedActualTimeSource,
  })  : _monotonicClock = monotonicClock,
        _wallClock = wallClock,
        _store = store,
        _calculator = calculator,
        _queue = queue ?? DemoOfflineQueue();

  final MonotonicClock _monotonicClock;
  final WallClock _wallClock;
  final DemoTimeStore _store;
  final TrustedTimeCalculator _calculator;
  final DemoOfflineQueue _queue;
  final TrustedActualTimeSource? trustedActualTimeSource;

  String? _sessionId;
  TimeAnchor? _loginAnchor;
  final List<TimeAnchor> _appOpens = [];
  final List<TimeAnchor> _appCloses = [];
  final List<TrustedAttendanceEvent> _events = [];
  bool _sessionActive = false;
  int _eventSeq = 0;

  TimeAnchor? get loginAnchor => _loginAnchor;
  TimeAnchor? get latestAppOpen =>
      _appOpens.isEmpty ? null : _appOpens.last;
  TimeAnchor? get latestAppClose =>
      _appCloses.isEmpty ? null : _appCloses.last;
  List<TimeAnchor> get appOpens => List.unmodifiable(_appOpens);
  List<TimeAnchor> get appCloses => List.unmodifiable(_appCloses);
  List<TrustedAttendanceEvent> get events => List.unmodifiable(_events);
  List<TrustedAttendanceEvent> get pendingSync => _queue.pending;
  bool get sessionActive => _sessionActive;
  String? get sessionId => _sessionId;
  DemoOfflineQueue get queue => _queue;

  Future<void> restore() async {
    _sessionId = await _store.loadSessionId();
    _loginAnchor = await _store.loadLoginAnchor();
    _appOpens
      ..clear()
      ..addAll(await _store.loadAppOpens());
    _appCloses
      ..clear()
      ..addAll(await _store.loadAppCloses());
    _events
      ..clear()
      ..addAll(await _store.loadEvents());
    _queue.replaceAll(await _store.loadPendingQueue());
    _sessionActive = await _store.loadSessionActive();
    _eventSeq = _events.length;

    final lastMono = await _store.loadLastObservedMonotonic();
    final current = _monotonicClock.elapsedRealtime();
    if (_sessionActive && lastMono != null && current < lastMono) {
      _log(
        'RESTORE reboot detected: currentMonotonic=${current.inMilliseconds} '
        '< lastObserved=${lastMono.inMilliseconds}',
      );
    }

    _log(
      'RESTORE sessionActive=$_sessionActive sessionId=$_sessionId '
      'login=${_loginAnchor?.wallClockLocal} appOpens=${_appOpens.length} '
      'appCloses=${_appCloses.length} events=${_events.length} '
      'pending=${_queue.pending.length}',
    );
  }

  /// Creates a NEW login timestamp for this employee session.
  Future<TimeAnchor> login({String? sessionId}) async {
    final wall = _wallClock.now();
    final mono = _monotonicClock.elapsedRealtime();
    _sessionId = sessionId ?? 'session_${wall.microsecondsSinceEpoch}';
    _sessionActive = true;
    _loginAnchor = TimeAnchor.capture(
      sessionId: _sessionId!,
      kind: 'login',
      wallClock: wall,
      monotonicElapsed: mono,
    );
    _appOpens
      ..clear()
      ..add(
        TimeAnchor.capture(
          sessionId: _sessionId!,
          kind: 'app_open',
          wallClock: wall,
          monotonicElapsed: mono,
        ),
      );
    _appCloses.clear();

    await _persistAnchors();
    await _store.saveSessionActive(true);
    await _store.saveLastObservedMonotonic(mono);

    _log(
      'LOGIN wall=${_loginAnchor!.wallClockLocal} '
      'utc=${_loginAnchor!.wallClockUtc.toIso8601String()} '
      'tz=${_loginAnchor!.timezoneName} ${_loginAnchor!.timezoneOffset} '
      'monotonic=${mono.inMilliseconds} sessionId=$_sessionId',
    );
    return _loginAnchor!;
  }

  Future<TimeAnchor?> recordAppOpen({String reason = 'app_open'}) async {
    if (!_sessionActive || _loginAnchor == null || _sessionId == null) {
      _log('APP_OPEN skipped: no active session');
      return null;
    }

    final wall = _wallClock.now();
    final mono = _monotonicClock.elapsedRealtime();
    final open = TimeAnchor.capture(
      sessionId: _sessionId!,
      kind: 'app_open',
      wallClock: wall,
      monotonicElapsed: mono,
    );
    _appOpens.add(open);
    if (_appOpens.length > 40) {
      _appOpens.removeRange(0, _appOpens.length - 40);
    }

    await _persistAnchors();
    await _store.saveLastObservedMonotonic(mono);

    _log(
      'APP_OPEN #$reason count=${_appOpens.length} wall=$wall '
      'monotonic=${mono.inMilliseconds} '
      'loginStill=${_loginAnchor!.wallClockLocal}',
    );
    return open;
  }

  Future<TimeAnchor?> recordAppClose({String reason = 'app_close'}) async {
    if (!_sessionActive || _loginAnchor == null || _sessionId == null) {
      _log('APP_CLOSE skipped: no active session');
      return null;
    }

    final wall = _wallClock.now();
    final mono = _monotonicClock.elapsedRealtime();
    final close = TimeAnchor.capture(
      sessionId: _sessionId!,
      kind: 'app_close',
      wallClock: wall,
      monotonicElapsed: mono,
    );
    _appCloses.add(close);
    if (_appCloses.length > 40) {
      _appCloses.removeRange(0, _appCloses.length - 40);
    }

    await _persistAnchors();
    await _store.saveLastObservedMonotonic(mono);

    _log(
      'APP_CLOSE #$reason count=${_appCloses.length} wall=$wall '
      'monotonic=${mono.inMilliseconds} '
      'loginStill=${_loginAnchor!.wallClockLocal}',
    );
    return close;
  }

  Future<void> expireSession() async {
    _log('SESSION_EXPIRE sessionId=$_sessionId');
    _sessionActive = false;
    _loginAnchor = null;
    _appOpens.clear();
    _appCloses.clear();
    _sessionId = null;
    await _store.saveSessionActive(false);
    await _store.saveLoginAnchor(null);
    await _store.saveAppOpens(const []);
    await _store.saveAppCloses(const []);
    await _store.saveSessionId(null);
    await _store.saveLastObservedMonotonic(null);
  }

  TrustedTimeSnapshot currentSnapshot({
    required bool networkOnline,
    DateTime? trustedActualTime,
  }) {
    return _calculator.calculate(
      phoneWallClock: _wallClock.now(),
      currentMonotonic: _monotonicClock.elapsedRealtime(),
      loginAnchor: _loginAnchor,
      latestAppOpen: latestAppOpen,
      appOpenCount: _appOpens.length,
      latestAppClose: latestAppClose,
      appCloseCount: _appCloses.length,
      networkOnline: networkOnline,
      sessionActive: _sessionActive,
      trustedActualTime: trustedActualTime,
    );
  }

  Future<RecordEventResult> recordEvent({
    required DemoAttendanceEventType type,
    required bool networkOnline,
  }) async {
    DateTime? trusted;
    if (networkOnline && trustedActualTimeSource != null) {
      try {
        trusted = await trustedActualTimeSource!();
      } catch (e) {
        _log('trusted time source failed: $e');
      }
    }

    final snapshot = currentSnapshot(
      networkOnline: networkOnline,
      trustedActualTime: trusted,
    );

    if (!snapshot.canIssueAuthoritativeTime) {
      final error =
          snapshot.reasonUnavailable ?? 'Cannot issue authoritative time.';
      _log('EVENT_BLOCKED type=${type.label} reason=$error');
      return RecordEventResult.fail(error);
    }

    final calculated = snapshot.calculatedActualTime!;
    final actual = snapshot.actualEventTime!;
    final comparison = snapshot.comparison!;
    // MATCH → calculated. MISMATCH → trusted actual. Never phone time.
    final sent = comparison == TimeComparisonResult.match ? calculated : actual;

    _eventSeq += 1;
    final event = TrustedAttendanceEvent(
      id: 'evt_${_sessionId}_$_eventSeq',
      sessionId: _sessionId!,
      type: type,
      phoneWallClock: snapshot.phoneWallClock,
      monotonicElapsed: snapshot.currentMonotonic,
      loginAnchor: snapshot.loginAnchor!,
      appOpenAnchor: snapshot.latestAppOpen,
      appCloseAnchor: snapshot.latestAppClose,
      calculatedActualTime: calculated,
      actualEventTime: actual,
      comparison: comparison,
      clockChanged: snapshot.clockChange.changed,
      clockDifference: snapshot.clockChange.difference,
      networkOnline: networkOnline,
      authoritativeTime: sent,
      timeSentToServer: sent,
      synced: networkOnline,
      createdAtMonotonic: snapshot.currentMonotonic,
    );

    _events.insert(0, event);
    if (!networkOnline) {
      _queue.enqueue(event);
    }

    await _store.saveEvents(_events);
    await _store.savePendingQueue(_queue.pending);
    await _store.saveLastObservedMonotonic(snapshot.currentMonotonic);

    _log(
      'EVENT ${type.logName} result=${comparison.label} '
      'phone=${event.phoneWallClock} '
      'actual=${event.actualEventTime} '
      'calculated=${event.calculatedActualTime} '
      'clockChanged=${event.clockChanged} '
      'sent=${event.timeSentToServer} '
      'network=${networkOnline ? "ONLINE" : "OFFLINE"} '
      'synced=${event.synced}',
    );

    return RecordEventResult.ok(event);
  }

  Future<SyncResult> syncPending() async {
    final toSend = _queue.peekForSync();
    if (toSend.isEmpty) {
      return const SyncResult(synced: [], preservedTimestamps: []);
    }

    for (final event in toSend) {
      _log(
        'SYNC sending ${event.type.logName} timeSentToServer='
        '${event.timeSentToServer} (original, not recalculated) '
        'result=${event.comparison.label}',
      );
    }

    final result = _queue.markSynced(toSend.map((e) => e.id));
    final byId = {for (final synced in result.synced) synced.id: synced};
    for (var i = 0; i < _events.length; i++) {
      final updated = byId[_events[i].id];
      if (updated != null) {
        _events[i] = updated;
      }
    }

    await _store.saveEvents(_events);
    await _store.savePendingQueue(_queue.pending);
    return result;
  }

  Future<void> resetEventsOnly() async {
    _events.clear();
    _queue.clear();
    _eventSeq = 0;
    await _store.saveEvents(const []);
    await _store.savePendingQueue(const []);
    _log('RESET events/queue cleared; login anchor kept');
  }

  Future<void> resetDemo() async {
    _sessionId = null;
    _loginAnchor = null;
    _appOpens.clear();
    _appCloses.clear();
    _events.clear();
    _queue.clear();
    _sessionActive = false;
    _eventSeq = 0;
    await _store.clearAll();
    _log('RESET demo state cleared');
  }

  Future<void> _persistAnchors() async {
    await _store.saveSessionId(_sessionId);
    await _store.saveLoginAnchor(_loginAnchor);
    await _store.saveAppOpens(_appOpens);
    await _store.saveAppCloses(_appCloses);
  }
}
