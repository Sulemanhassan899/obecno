import 'dart:async';

import 'package:Obecno/core/services/connectivity_service.dart';
import 'package:Obecno/core/state/change_notifier_provider.dart';
import 'package:Obecno/features/auth/presentation/screens/login_email.dart';
import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({
    super.key,
    required this.authenticatedBuilder,
    this.unauthenticatedBuilder,
  });

  final WidgetBuilder authenticatedBuilder;

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

    _connectivitySub = ConnectivityService.stream.listen((connected) {
      if (mounted) setState(() => _hasConnection = connected);
    });

    _bootstrap();
  }

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

    if (_isAuthenticated) {
      return widget.authenticatedBuilder(context);
    }

    if (!_hasConnection) {
      return _NoInternetView(onRetry: _retry);
    }

    return widget.unauthenticatedBuilder?.call(context) ??
        const LoginEmailScreen();
  }
}

class _AuthSplashView extends StatelessWidget {
  const _AuthSplashView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
