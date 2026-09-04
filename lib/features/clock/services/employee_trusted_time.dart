import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:obecno/features/clock/clocks/clocks.dart';
import 'package:obecno/features/clock/domain/trusted_time_models.dart';
import 'package:obecno/features/clock/services/trusted_time_session.dart';
import 'package:obecno/features/clock/services/trusted_time_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-scoped trusted time for the signed-in employee.
///
/// Captures a login time-anchor (idempotent per user id), records app
/// open/close without replacing login, and issues punch timestamps from
/// login + monotonic elapsed time.
class EmployeeTrustedTime with WidgetsBindingObserver, ChangeNotifier {
  EmployeeTrustedTime({
    TrustedTimeSession? session,
    MonotonicClock monotonicClock = const SystemMonotonicClock(),
    WallClock wallClock = const SystemWallClock(),
  })  : _monotonicClock = monotonicClock,
        _wallClock = wallClock,
        _injectedSession = session;

  final MonotonicClock _monotonicClock;
  final WallClock _wallClock;
  final TrustedTimeSession? _injectedSession;

  TrustedTimeSession? _session;
  PrefsTrustedTimeStore? _store;
  String? _attachedUserId;
  Future<void>? _inFlight;
  bool _ready = false;
  bool _skipNextResumeAppOpen = false;
  AppLifecycleState? _lifecycle;

  TrustedTimeSession? get session => _session;
  bool get ready => _ready;
  String? get attachedUserId => _attachedUserId;

  static String sessionIdFor(String userId) => 'emp_$userId';

  Future<void> init() async {
    if (_injectedSession != null) {
      _session = _injectedSession;
      _ready = true;
      WidgetsBinding.instance.addObserver(this);
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _store = PrefsTrustedTimeStore(prefs, userId: '_none');
    _session = TrustedTimeSession(
      monotonicClock: AnchoredMonotonicClock(_monotonicClock),
      wallClock: _wallClock,
      store: _store!,
    );
    await _session!.restore();
    _ready = true;
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
  }

  Future<void> ensureLogin({required String userId}) {
    if (_attachedUserId == userId &&
        _session?.sessionActive == true &&
        _session?.loginAnchor != null) {
      return Future.value();
    }
    return _inFlight ??= _ensureLogin(userId).whenComplete(() {
      _inFlight = null;
    });
  }

  Future<void> _ensureLogin(String userId) async {
    if (!_ready) await init();
    final session = _session;
    if (session == null) return;

    if (_attachedUserId == userId &&
        session.sessionActive &&
        session.loginAnchor != null) {
      return;
    }

    final store = _store;
    if (store != null && store.userId != userId) {
      if (session.sessionActive) {
        await session.expireSession();
      }
      store.setUserId(userId);
      await session.restore();
    } else if (store != null && store.userId == '_none') {
      store.setUserId(userId);
      await session.restore();
    }

    final expected = sessionIdFor(userId);
    if (session.sessionActive &&
        session.sessionId == expected &&
        session.loginAnchor != null) {
      _attachedUserId = userId;
      _skipNextResumeAppOpen = true;
      await session.recordAppOpen(reason: 'process_start');
      debugPrint(
        '[TRUSTED_TIME] reuse login=${session.loginAnchor!.wallClockLocal} '
        'user=$userId',
      );
      notifyListeners();
      return;
    }

    if (session.sessionId != null && session.sessionId != expected) {
      await session.resetAll();
    }

    await session.login(sessionId: expected);
    _attachedUserId = userId;
    _skipNextResumeAppOpen = true;
    debugPrint('[TRUSTED_TIME] captured login for user=$userId');
    notifyListeners();
  }

  Future<void> ensureLoggedOut() async {
    if (_attachedUserId == null && _session?.sessionActive != true) return;
    _attachedUserId = null;
    await _session?.expireSession();
    debugPrint('[TRUSTED_TIME] session expired on logout');
    notifyListeners();
  }

  DateTime displayNow({bool networkOnline = true}) {
    return _session?.displayNow(networkOnline: networkOnline) ?? DateTime.now();
  }

  TrustedTimeSnapshot snapshot({bool networkOnline = true}) {
    return _session?.currentSnapshot(networkOnline: networkOnline) ??
        TrustedTimeSnapshot(
          phoneWallClock: DateTime.now(),
          currentMonotonic: Duration.zero,
          loginAnchor: null,
          latestAppOpen: null,
          appOpenCount: 0,
          latestAppClose: null,
          appCloseCount: 0,
          calculatedActualTime: null,
          actualEventTime: null,
          comparison: null,
          clockChange: const ClockChangeDetection(
            changed: false,
            difference: Duration.zero,
            wallElapsed: Duration.zero,
            monotonicElapsed: Duration.zero,
          ),
          networkOnline: networkOnline,
          rebootDetected: false,
          sessionActive: false,
          reasonUnavailable: 'Trusted time is not ready.',
        );
  }

  bool get canPunch => snapshot().canIssueAuthoritativeTime;

  bool get rebootDetected => snapshot().rebootDetected;

  Future<RecordTimeResult> issuePunch({required bool networkOnline}) async {
    final session = _session;
    if (session == null) {
      return const RecordTimeResult.fail('Trusted time is not ready.');
    }
    final result = await session.issuePunch(networkOnline: networkOnline);
    notifyListeners();
    return result;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previous = _lifecycle;
    _lifecycle = state;

    final closing = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (closing && previous == AppLifecycleState.resumed) {
      unawaited(_onBackground());
      return;
    }

    if (state == AppLifecycleState.resumed &&
        previous != null &&
        previous != AppLifecycleState.resumed) {
      if (_skipNextResumeAppOpen) {
        _skipNextResumeAppOpen = false;
        return;
      }
      unawaited(_onForeground());
    }
  }

  Future<void> _onForeground() async {
    await _session?.recordAppOpen(reason: 'foreground');
    notifyListeners();
  }

  Future<void> _onBackground() async {
    await _session?.recordAppClose(reason: 'background');
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
