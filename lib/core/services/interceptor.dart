import 'package:obecno/core/services/logger.dart';

import 'token_service.dart';

/// Legacy 401 helper — kept for compile compatibility with older call sites.
///
/// Production traffic must use [SessionManager.handleUnauthorized] via
/// [ApiClient]. This class no longer clears the session on its own.
@Deprecated('Use SessionManager.handleUnauthorized via ApiClient')
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
    final refreshed = await _tokenService.tryRefreshSession(forceNetwork: true);
    if (refreshed) {
      AppLogger.info(
        'AuthFailureHandler: token refreshed (prefer SessionManager path).',
      );
      return;
    }
    // Do not clearSession() — SessionManager + /auth/me own logout.
    AppLogger.info(
      'AuthFailureHandler: refresh failed; session left for SessionManager.',
    );
    await onUnauthorized?.call();
  }
}
