import 'package:flutter/foundation.dart';
import 'package:obecno/features/clock/clocks/clocks.dart';
import 'package:obecno/features/clock/domain/trusted_time_models.dart';
import 'package:obecno/features/clock/services/trusted_time_calculator.dart';
import 'package:obecno/features/clock/services/trusted_time_store.dart';

void _log(String message) {
  debugPrint('[TRUSTED_TIME] $message');
}

/// Optional extra trusted time (e.g. HTTP Date). When it disagrees with
/// the monotonic calculation, the punch is a MISMATCH and the trusted
/// time is sent. Phone wall-clock is never sent.
typedef TrustedActualTimeSource = Future<DateTime?> Function();

/// Session-scoped trusted time. Login is the session origin. Every app
/// open and app close gets its own timestamp and does NOT replace login.
///
/// Attendance events themselves live in the clock controller / offline
/// queue. This class only issues the frozen timestamp those layers must
/// send — never recalculate later.
class TrustedTimeSession {
  TrustedTimeSession({
    required MonotonicClock monotonicClock,
    required WallClock wallClock,
    required TrustedTimeStore store,
    TrustedTimeCalculator calculator = const TrustedTimeCalculator(),
    this.trustedActualTimeSource,
  })  : _monotonicClock = monotonicClock,
        _wallClock = wallClock,
        _store = store,
        _calculator = calculator;

  final MonotonicClock _monotonicClock;
  final WallClock _wallClock;
  final TrustedTimeStore _store;
  final TrustedTimeCalculator _calculator;
  final TrustedActualTimeSource? trustedActualTimeSource;

  String? _sessionId;
  TimeAnchor? _loginAnchor;
  final List<TimeAnchor> _appOpens = [];
  final List<TimeAnchor> _appCloses = [];
  bool _sessionActive = false;

  TimeAnchor? get loginAnchor => _loginAnchor;
  TimeAnchor? get latestAppOpen =>
      _appOpens.isEmpty ? null : _appOpens.last;
  TimeAnchor? get latestAppClose =>
      _appCloses.isEmpty ? null : _appCloses.last;
  List<TimeAnchor> get appOpens => List.unmodifiable(_appOpens);
  List<TimeAnchor> get appCloses => List.unmodifiable(_appCloses);
  bool get sessionActive => _sessionActive;
  String? get sessionId => _sessionId;

  Future<void> restore() async {
    _sessionId = await _store.loadSessionId();
    _loginAnchor = await _store.loadLoginAnchor();
    _appOpens
      ..clear()
      ..addAll(await _store.loadAppOpens());
    _appCloses
      ..clear()
      ..addAll(await _store.loadAppCloses());
    _sessionActive = await _store.loadSessionActive();

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
      'appCloses=${_appCloses.length}',
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

  Future<void> resetAll() async {
    _sessionId = null;
    _loginAnchor = null;
    _appOpens.clear();
    _appCloses.clear();
    _sessionActive = false;
    await _store.clearAll();
    _log('RESET trusted-time state cleared');
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

  /// Calculated actual time for the on-screen clock. Falls back to the
  /// phone wall clock only when no login anchor can be used (reboot / logout).
  DateTime displayNow({bool networkOnline = true}) {
    final snap = currentSnapshot(networkOnline: networkOnline);
    return snap.calculatedActualTime ?? snap.phoneWallClock;
  }

  Future<RecordTimeResult> issuePunch({required bool networkOnline}) async {
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
      _log('PUNCH_BLOCKED reason=$error');
      return RecordTimeResult.fail(error);
    }

    final calculated = snapshot.calculatedActualTime!;
    final actual = snapshot.actualEventTime!;
    final comparison = snapshot.comparison!;
    // MATCH → calculated. MISMATCH → trusted actual. Never phone time.
    final sent = comparison == TimeComparisonResult.match ? calculated : actual;

    await _store.saveLastObservedMonotonic(snapshot.currentMonotonic);

    _log(
      'PUNCH result=${comparison.label} '
      'phone=${snapshot.phoneWallClock} '
      'actual=$actual '
      'calculated=$calculated '
      'clockChanged=${snapshot.clockChange.changed} '
      'sent=$sent '
      'network=${networkOnline ? "ONLINE" : "OFFLINE"}',
    );

    return RecordTimeResult.ok(
      AuthoritativePunch(
        timeSentToServer: sent,
        phoneWallClock: snapshot.phoneWallClock,
        calculatedActualTime: calculated,
        actualEventTime: actual,
        comparison: comparison,
        clockChanged: snapshot.clockChange.changed,
        clockDifference: snapshot.clockChange.difference,
        monotonicElapsed: snapshot.currentMonotonic,
        loginAnchor: snapshot.loginAnchor!,
        appOpenAnchor: snapshot.latestAppOpen,
        appCloseAnchor: snapshot.latestAppClose,
        networkOnline: networkOnline,
      ),
    );
  }

  Future<void> _persistAnchors() async {
    await _store.saveSessionId(_sessionId);
    await _store.saveLoginAnchor(_loginAnchor);
    await _store.saveAppOpens(_appOpens);
    await _store.saveAppCloses(_appCloses);
  }
}
