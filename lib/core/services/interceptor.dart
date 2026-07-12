import 'package:Obecno/core/services/logger.dart';

import 'token_service.dart';

/// Reacts to auth failures (401/403) the same way the old Dio
/// `AuthInterceptor` did: try to refresh, otherwise clear the local
/// session so the router can redirect to the login screen.
///
/// There's no Dio interceptor chain anymore, so `ApiClient` calls
/// [handleUnauthorized] directly right after it detects a 401/403 status
/// code, instead of this class hooking into `onError`.
class AuthFailureHandler {
  AuthFailureHandler({required TokenService tokenService, this.onUnauthorized}) : _tokenService = tokenService;

  final TokenService _tokenService;

  /// Optional callback (wire to a router redirect) fired once the local
  /// session has been cleared after a confirmed 401/403.
  final Future<void> Function()? onUnauthorized;

  bool _handling = false;

  Future<void> handleUnauthorized() async {
    if (_handling) return;
    _handling = true;
    try {
      final refreshed = await _tokenService.tryRefreshSession();
      if (!refreshed) {
        await _tokenService.clearSession();
        await onUnauthorized?.call();
        AppLogger.info('AuthFailureHandler: session cleared after 401/403.');
      }
    } finally {
      _handling = false;
    }
  }
}
