import 'package:Obecno/core/api/api_client.dart';
import 'package:Obecno/core/services/network_checker.dart';
import 'package:Obecno/core/services/token_service.dart';
import 'package:Obecno/features/auth/data/models/auth_user_model.dart';
import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:Obecno/features/auth/repositories/auth_repository.dart';
import 'package:Obecno/features/auth/services/auth_service.dart';
import 'package:Obecno/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake network checker (no real connectivity calls)
class _FakeNetworkChecker implements NetworkChecker {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => const Stream<bool>.empty();
}

void main() {
  testWidgets('App builds and renders the initial route without crashing', (
    WidgetTester tester,
  ) async {
    final tokenService = TokenService();

    final apiClient = ApiClient(
      networkChecker: _FakeNetworkChecker(),
      tokenService: tokenService,
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

  test('AuthUserModel reads company from nested user payload', () {
    final user = AuthUserModel.fromJson({
      'user': {
        'id': '42',
        'name': 'Jane Doe',
        'email': 'jane@example.com',
        'company': {'id': 'c1', 'name': 'Acme Labs'},
      },
      'roles': ['employee'],
      'locations': [
        {'id': 'l1', 'name': 'HQ', 'is_default': true},
      ],
    });

    expect(user.company, isNotNull);
    expect(user.company!.name, 'Acme Labs');
    expect(user.locations, isNotEmpty);
  });
}
