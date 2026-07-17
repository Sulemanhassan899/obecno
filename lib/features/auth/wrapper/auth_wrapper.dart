// import 'dart:async';

// import 'package:Obecno/core/services/connectivity_service.dart';
// import 'package:Obecno/core/state/change_notifier_provider.dart';
// import 'package:Obecno/features/auth/presentation/screens/login_email.dart';
// import 'package:flutter/material.dart';

// import '../providers/auth_provider.dart';

// /// Root entry point of the app.
// ///
// /// Responsibilities (per spec):
// /// 1. Session check (auto-login) via [AuthProvider.checkSession].
// /// 2. Internet connectivity, using the EXISTING [ConnectivityService] —
// ///    no new package added.
// /// 3. Loading/splash state while the check is in flight.
// /// 4. Route decision: authenticated home vs. login_email.dart.
// ///
// /// Must sit under a `ChangeNotifierProvider<AuthProvider>` ancestor (wired
// /// once in main.dart — see the module README for the exact snippet).
// ///
// /// [authenticatedBuilder] is intentionally a builder rather than a fixed
// /// widget so this file doesn't need to import the app's home/dashboard
// /// screen (kept decoupled from bottom-nav-bar wiring, which differs by
// /// role — see role_selection.dart).
// class AuthWrapper extends StatefulWidget {
//   const AuthWrapper({
//     super.key,
//     required this.authenticatedBuilder,
//     this.unauthenticatedBuilder,
//   });

//   final WidgetBuilder authenticatedBuilder;

//   /// Defaults to [LoginEmailScreen] — the first locked screen in the flow.
//   final WidgetBuilder? unauthenticatedBuilder;

//   @override
//   State<AuthWrapper> createState() => _AuthWrapperState();
// }

// class _AuthWrapperState extends State<AuthWrapper> {
//   bool _checking = true;
//   bool _hasConnection = true;
//   bool _isAuthenticated = false;

//   StreamSubscription<bool>? _connectivitySub;

//   @override
//   void initState() {
//     super.initState();

//     // ConnectivityService.start() is already called by AppGuard at app
//     // start; we only subscribe here, we don't start/stop the stream.
//     _connectivitySub = ConnectivityService.stream.listen((connected) {
//       if (mounted) setState(() => _hasConnection = connected);
//     });

//     _bootstrap();
//   }

//   Future<void> _bootstrap() async {
//     final connected = await ConnectivityService.isConnected();
//     if (!mounted) return;

//     if (!connected) {
//       setState(() {
//         _hasConnection = false;
//         _checking = false;
//       });
//       return;
//     }

//     final authProvider = context.read<AuthProvider>();
//     final loggedIn = await authProvider.checkSession();

//     if (!mounted) return;
//     setState(() {
//       _hasConnection = true;
//       _isAuthenticated = loggedIn;
//       _checking = false;
//     });
//   }

//   Future<void> _retry() async {
//     setState(() => _checking = true);
//     await _bootstrap();
//   }

//   @override
//   void dispose() {
//     _connectivitySub?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (!_hasConnection) {
//       return _NoInternetView(onRetry: _retry);
//     }

//     if (_checking) {
//       return const _AuthSplashView();
//     }

//     if (_isAuthenticated) {
//       return widget.authenticatedBuilder(context);
//     }

//     return widget.unauthenticatedBuilder?.call(context) ?? const LoginEmailScreen();
//   }
// }

// class _AuthSplashView extends StatelessWidget {
//   const _AuthSplashView();

//   @override
//   Widget build(BuildContext context) {
//     // Deliberately minimal — swap in the app's existing splash asset/animation
//     // here if one exists (e.g. reuse whatever splash.dart already renders),
//     // this file only needs to satisfy "show a loading state while checking".
//     return const Scaffold(
//       body: Center(child: CircularProgressIndicator()),
//     );
//   }
// }

// class _NoInternetView extends StatelessWidget {
//   const _NoInternetView({required this.onRetry});

//   final VoidCallback onRetry;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.wifi_off, size: 48),
//             const SizedBox(height: 16),
//             const Text('No internet connection'),
//             const SizedBox(height: 16),
//             ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'dart:async';

import 'package:Obecno/core/services/connectivity_service.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/presentation/screens/login_email.dart';
import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';

/// Root entry point of the app.
///
/// Responsibilities (per spec):
/// 1. Session check (auto-login) via [AuthProvider.checkSession].
/// 2. Internet connectivity, using the EXISTING [ConnectivityService] —
///    no new package added.
/// 3. Loading/splash state while the check is in flight.
/// 4. Route decision: authenticated home vs. login_email.dart.
///
/// Must sit under a `ChangeNotifierProvider<AuthProvider>` ancestor (wired
/// once in main.dart — see the module README for the exact snippet).
///
/// [authenticatedBuilder] is intentionally a builder rather than a fixed
/// widget so this file doesn't need to import the app's home/dashboard
/// screen (kept decoupled from bottom-nav-bar wiring, which differs by
/// role — see role_selection.dart).
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({
    super.key,
    required this.authenticatedBuilder,
    this.unauthenticatedBuilder,
  });

  final WidgetBuilder authenticatedBuilder;

  /// Defaults to [LoginEmailScreen] — the first locked screen in the flow.
  final WidgetBuilder? unauthenticatedBuilder;

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _checking = true;
  bool _hasConnection = true;
  bool _isAuthenticated = false;

  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();

    // ConnectivityService.start() is already called by AppGuard at app
    // start; we only subscribe here, we don't start/stop the stream.
    _connectivitySub = ConnectivityService.stream.listen((connected) {
      if (mounted) setState(() => _hasConnection = connected);
    });

    _bootstrap();
  }

  /// OFFLINE-FIX: this used to short-circuit on `!connected` and show
  /// [_NoInternetView] without ever calling [AuthProvider.checkSession] --
  /// so a user who was already logged in got stuck on a "no internet"
  /// screen (with no way back into the app) the moment connectivity was
  /// down at launch, which is indistinguishable from being logged out.
  ///
  /// [AuthProvider.checkSession] is now offline-first itself (trusts the
  /// locally persisted session immediately, and only ever clears it on a
  /// confirmed 401/403/419 -- see auth_provider.dart), so it's always
  /// safe to call regardless of connectivity. [_hasConnection] is still
  /// tracked and used in [build] to decide what to show when there's
  /// *no* local session to fall back on (an unauthenticated user genuinely
  /// can't log in without a connection).
  Future<void> _bootstrap() async {
    final connected = await ConnectivityService.isConnected();
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final loggedIn = await authProvider.checkSession();

    if (!mounted) return;
    setState(() {
      _hasConnection = connected;
      _isAuthenticated = loggedIn;
      _checking = false;
    });
  }

  Future<void> _retry() async {
    setState(() => _checking = true);
    await _bootstrap();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const _AuthSplashView();
    }

    // OFFLINE-FIX: an authenticated session (confirmed locally, and with
    // the server whenever reachable -- see AuthProvider.checkSession) is
    // let straight into the app even with no connectivity right now.
    // Connectivity issues are surfaced non-destructively elsewhere
    // (AppGuard's periodic "No Internet" dialog / Clock module's offline
    // queue banner) instead of gating access to a screen the user is
    // already allowed to see.
    if (_isAuthenticated) {
      return widget.authenticatedBuilder(context);
    }

    // No local/confirmed session to fall back on -- logging in requires
    // reaching the server, so only here does "no internet" actually
    // block the user.
    if (!_hasConnection) {
      return _NoInternetView(onRetry: _retry);
    }

    return widget.unauthenticatedBuilder?.call(context) ?? const LoginEmailScreen();
  }
}

class _AuthSplashView extends StatelessWidget {
  const _AuthSplashView();

  @override
  Widget build(BuildContext context) {
    // Deliberately minimal — swap in the app's existing splash asset/animation
    // here if one exists (e.g. reuse whatever splash.dart already renders),
    // this file only needs to satisfy "show a loading state while checking".
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _NoInternetView extends StatelessWidget {
  const _NoInternetView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48),
            const SizedBox(height: 16),
            const Text('No internet connection'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}