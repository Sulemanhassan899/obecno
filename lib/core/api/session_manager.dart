import 'dart:async';

import 'package:obecno/core/services/logger.dart';
import 'package:obecno/core/services/token_service.dart';

class SessionManager {
  SessionManager({
    required TokenService tokenService,
    required Future<bool> Function() validateWithBackend,
    Future<void> Function()? onSessionLost,
  }) : _tokenService = tokenService,
       _validateWithBackend = validateWithBackend,
       _onSessionLost = onSessionLost;

  final TokenService _tokenService;

  final Future<bool> Function() _validateWithBackend;
  final Future<void> Function()? _onSessionLost;

  bool _isSessionValid = false;

  bool get isSessionValid => _isSessionValid;

  DateTime? _lastValidatedAt;
  DateTime? get lastValidatedAt => _lastValidatedAt;

  Completer<bool>? _sessionValidationCompleter;
  Completer<bool>? _unauthorizedCompleter;

  /// Call after a successful login / local session restore so concurrent
  /// 401 handlers do not treat the session as dead before the first
  /// `/auth/me` validation finishes.
  void markValid() {
    _isSessionValid = true;
    _lastValidatedAt = DateTime.now();
  }

  void markInvalid() {
    _isSessionValid = false;
  }

  Future<bool> validateSession() {
    final inFlight = _sessionValidationCompleter;

    // Always join the in-flight validation. Returning the stale
    // `_isSessionValid` (defaults to false) while a check is running caused
    // parallel 401s to clear the session and log the user out.
    if (inFlight != null) {
      AppLogger.info('[SessionManager] Waiting for ongoing validation');
      return inFlight.future;
    }

    final completer = Completer<bool>();
    _sessionValidationCompleter = completer;
    AppLogger.info('[SessionManager] Validation started');

    unawaited(
      _runValidation()
          .then(
            (result) {
              if (!completer.isCompleted) completer.complete(result);
            },
            onError: (Object e, StackTrace st) {
              AppLogger.info('[SessionManager] Validation error: $e');
              if (!completer.isCompleted) completer.complete(_isSessionValid);
            },
          )
          .whenComplete(() {
            _sessionValidationCompleter = null;
            AppLogger.info('[SessionManager] Validation completed');
          }),
    );

    return completer.future;
  }

  Future<bool> _runValidation() async {
    try {
      final valid = await _validateWithBackend();
      _isSessionValid = valid;
      _lastValidatedAt = DateTime.now();
      return valid;
    } catch (_) {
      final cachedSessionActive = await _tokenService.isSessionActive;
      _isSessionValid = cachedSessionActive;
      return cachedSessionActive;
    }
  }

  /// 401/419 recovery: force token renew → retry; only logout if renew and
  /// `/auth/me` both confirm the session is dead. Parallel 401s share one run.
  Future<bool> handleUnauthorized() {
    final inFlight = _unauthorizedCompleter;
    if (inFlight != null) {
      AppLogger.info('[SessionManager] Waiting for ongoing 401 recovery');
      return inFlight.future;
    }

    final completer = Completer<bool>();
    _unauthorizedCompleter = completer;
    unawaited(
      _runUnauthorized()
          .then(
            (result) {
              if (!completer.isCompleted) completer.complete(result);
            },
            onError: (Object e, StackTrace st) {
              AppLogger.info('[SessionManager] 401 recovery error: $e');
              if (!completer.isCompleted) completer.complete(_isSessionValid);
            },
          )
          .whenComplete(() {
            _unauthorizedCompleter = null;
          }),
    );
    return completer.future;
  }

  Future<bool> _runUnauthorized() async {
    AppLogger.info('[Interceptor] Handling 401 -- validating session');

    // Always hit /auth/refresh on 401 — local expiry alone is not enough;
    // the server may reject a token the phone still thinks is valid.
    try {
      final refreshed = await _tokenService.tryRefreshSession(
        forceNetwork: true,
      );
      if (refreshed) {
        markValid();
        AppLogger.info(
          '[Interceptor] Token refreshed after 401 — request will retry',
        );
        return true;
      }
    } catch (e) {
      AppLogger.info('[Interceptor] Refresh attempt error: $e');
    }

    final valid = await validateSession();

    if (!valid) {
      AppLogger.info('[Interceptor] Logging out user');
      await _tokenService.clearSession();
      await _onSessionLost?.call();
    }

    return valid;
  }

  Future<bool> restoreOnAppStart() => validateSession();
}
