import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:obecno/core/routes/app_routes.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/main.dart';

/// Handles invite / download deep links so tapping the link again opens Obecno
/// when the app is already installed ("Open with").
class JoinDeepLinkService {
  JoinDeepLinkService._();
  static final JoinDeepLinkService instance = JoinDeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handle(initial, fromColdStart: true);
      }
    } catch (e) {
      debugPrint('[JoinDeepLink] initial link failed: $e');
    }

    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _handle(uri, fromColdStart: false),
      onError: (e) => debugPrint('[JoinDeepLink] stream error: $e'),
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  bool _isJoinUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    if (scheme == 'obecno' && (host == 'join' || path.contains('join'))) {
      return true;
    }
    if ((scheme == 'http' || scheme == 'https') &&
        (host == 'www.obecno.com' || host == 'obecno.com') &&
        path.startsWith('/download')) {
      return true;
    }
    return false;
  }

  void _handle(Uri uri, {required bool fromColdStart}) {
    if (!_isJoinUri(uri)) return;
    debugPrint('[JoinDeepLink] opening from $uri (coldStart=$fromColdStart)');

    // Defer until navigator is ready.
    Future<void>.delayed(Duration(milliseconds: fromColdStart ? 800 : 100), () {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;

      final auth = bindings.authProvider;
      if (auth.isAuthenticated) {
        final home = auth.homeTarget == AuthHomeTarget.manager
            ? '/manager_nav'
            : '/employee_nav';
        router.go(home);
        return;
      }
      router.go('/login');
    });
  }
}
