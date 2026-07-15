import 'dart:io';

import 'package:Obecno/core/api/api.dart';
import 'package:Obecno/core/api/api_client.dart';
import 'package:Obecno/core/api/cookie_service.dart';
import 'package:Obecno/core/services/network_checker.dart';
import 'package:Obecno/core/services/token_service.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/features/auth/repositories/auth_repository.dart';
import 'package:Obecno/features/auth/services/auth_service.dart';
import 'package:Obecno/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Fakes `path_provider` so CookieService works in tests
class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('obecno_test_').path;
  }
}

/// Fake network checker (no real connectivity calls)
class _FakeNetworkChecker implements NetworkChecker {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => const Stream<bool>.empty();
}

void main() {
  setUpAll(() {
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  testWidgets('App builds and renders the initial route without crashing', (
    WidgetTester tester,
  ) async {
    final cookieService = await CookieService.init();
    final tokenService = TokenService();

    final apiClient = ApiClient(
      cookieService: cookieService,
      networkChecker: _FakeNetworkChecker(),
      tokenService: tokenService,
    );
    final httpapiClient = HttpApiClient(
      cookieService: cookieService,
      networkChecker: _FakeNetworkChecker(),
    );
    // Positional constructor, as AuthProvider expects.
    final authProvider = AuthProvider(
      AuthService(AuthRepository(apiClient), tokenService),
    );

    // Build app
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // Smoke test assertion
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
