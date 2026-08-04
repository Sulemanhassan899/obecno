import 'package:Obecno/core/services/logger.dart';
import 'package:flutter/foundation.dart';

import 'session_manager.dart';

class SessionManagerDebugHarness {
  const SessionManagerDebugHarness(this._sessionManager);

  final SessionManager _sessionManager;

  Future<void> simulateRaceCondition({int concurrentCalls = 5}) async {
    if (!kDebugMode) return;

    AppLogger.info(
      '[SessionManager][Debug] Simulating $concurrentCalls concurrent validateSession() calls',
    );

    final futures = List.generate(
      concurrentCalls,
      (_) => _sessionManager.validateSession(),
    );
    final results = await Future.wait(futures);
    final allAgree = results.toSet().length <= 1;

    AppLogger.info(
      '[SessionManager][Debug] Race simulation results=$results '
      'singleFlightHeld=$allAgree',
    );
  }

  Future<void> simulateSessionExpiry() async {
    if (!kDebugMode) return;

    AppLogger.info('[SessionManager][Debug] Simulating forced 401 / expiry');
    final stillValid = await _sessionManager.handleUnauthorized();

    AppLogger.info(
      stillValid
          ? '[Interceptor][Debug] Session revalidated -- would retry original request once'
          : '[Interceptor][Debug] Session confirmed invalid -- would log out',
    );
  }

  Future<void> simulateOfflineMode<T>({
    required Future<T> Function() action,
    required T Function() cachedFallback,
  }) async {
    if (!kDebugMode) return;

    AppLogger.info('[SessionManager][Debug] Simulating offline validation');

    try {
      await action();
      AppLogger.info('[SessionManager][Debug] Action completed without error');
    } catch (e) {
      final fallback = cachedFallback();
      AppLogger.info(
        '[SessionManager][Debug] Action threw ($e) -- cached fallback still usable: $fallback',
      );
    }
  }
}
