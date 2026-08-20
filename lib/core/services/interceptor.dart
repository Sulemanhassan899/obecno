import 'package:obecno/core/services/logger.dart';

import 'token_service.dart';

class AuthFailureHandler {
  AuthFailureHandler({required TokenService tokenService, this.onUnauthorized})
    : _tokenService = tokenService;

  final TokenService _tokenService;

  final Future<void> Function()? onUnauthorized;

  Future<void>? _inFlight;

  Future<void> handleUnauthorized() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  Future<void> _run() async {
    final refreshed = await _tokenService.tryRefreshSession();
    if (!refreshed) {
      await _tokenService.clearSession();
      await onUnauthorized?.call();
      AppLogger.info('AuthFailureHandler: session cleared after 401/403.');
    }
  }
}
