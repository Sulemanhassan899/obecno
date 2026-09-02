import 'package:flutter/foundation.dart';
import 'package:obecno/demo/monotonic_clock/clocks/demo_clocks.dart';
import 'package:obecno/demo/monotonic_clock/services/demo_time_store.dart';
import 'package:obecno/demo/monotonic_clock/services/trusted_time_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures a login time-anchor for the already-authenticated employee
/// using the live monotonic clock. Idempotent per user id.
class DemoEmployeeClockBridge {
  DemoEmployeeClockBridge._();

  static String? _attachedUserId;
  static Future<void>? _inFlight;

  static String sessionIdFor(String userId) => 'emp_$userId';

  static Future<void> ensureLogin({required String userId}) {
    if (_attachedUserId == userId) return Future.value();
    return _inFlight ??= _ensureLogin(userId).whenComplete(() {
      _inFlight = null;
    });
  }

  static Future<void> _ensureLogin(String userId) async {
    if (_attachedUserId == userId) return;

    final store = PrefsDemoTimeStore(await SharedPreferences.getInstance());
    final session = TrustedTimeSession(
      monotonicClock: const SystemMonotonicClock(),
      wallClock: const SystemWallClock(),
      store: store,
    );
    await session.restore();

    final expected = sessionIdFor(userId);
    if (session.sessionActive &&
        session.sessionId == expected &&
        session.loginAnchor != null) {
      _attachedUserId = userId;
      debugPrint(
        '[MONOTONIC_DEMO] BRIDGE reuse login=${session.loginAnchor!.wallClockLocal} user=$userId',
      );
      return;
    }

    if (session.sessionId != null && session.sessionId != expected) {
      await session.resetDemo();
    }

    await session.login(sessionId: expected);
    _attachedUserId = userId;
    debugPrint(
      '[MONOTONIC_DEMO] BRIDGE captured login for user=$userId',
    );
  }

  static Future<void> ensureLoggedOut() async {
    if (_attachedUserId == null) return;
    _attachedUserId = null;
    final store = PrefsDemoTimeStore(await SharedPreferences.getInstance());
    final session = TrustedTimeSession(
      monotonicClock: const SystemMonotonicClock(),
      wallClock: const SystemWallClock(),
      store: store,
    );
    await session.restore();
    await session.expireSession();
    debugPrint('[MONOTONIC_DEMO] BRIDGE session expired on logout');
  }
}
