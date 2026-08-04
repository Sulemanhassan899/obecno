import 'dart:async';

import 'package:Obecno/core/services/logger.dart';
import 'package:Obecno/core/services/token_service.dart';

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

  bool _isValidationRunning = false;

  Future<bool> validateSession() {
    final inFlight = _sessionValidationCompleter;

    if (inFlight != null) {
      if (_isValidationRunning) {
        AppLogger.info(
          '[SessionManager] Re-entrant validateSession() call detected -- '
          'returning cached state instead of awaiting in-flight validation.',
        );
        return Future.value(_isSessionValid);
      }

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
    _isValidationRunning = true;
    try {
      final valid = await _validateWithBackend();
      _isSessionValid = valid;
      _lastValidatedAt = DateTime.now();
      return valid;
    } catch (_) {
      final cachedSessionActive = await _tokenService.isSessionActive;
      _isSessionValid = cachedSessionActive;
      return cachedSessionActive;
    } finally {
      _isValidationRunning = false;
    }
  }

  Future<bool> handleUnauthorized() async {
    AppLogger.info('[Interceptor] Handling 401 -- validating session');
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
