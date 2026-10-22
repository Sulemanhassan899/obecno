import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/api/session_manager.dart';
import 'package:obecno/core/services/token_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionManager', () {
    test('concurrent validateSession awaits the same in-flight result', () async {
      var calls = 0;
      final gate = Completer<void>();

      final manager = SessionManager(
        tokenService: TokenService(),
        validateWithBackend: () async {
          calls++;
          await gate.future;
          return true;
        },
      );

      final first = manager.validateSession();
      // Let the first validation reach the gate.
      await Future<void>.delayed(Duration.zero);

      final second = manager.validateSession();
      final third = manager.validateSession();

      gate.complete();

      final results = await Future.wait([first, second, third]);
      expect(calls, 1);
      expect(results, [true, true, true]);
      expect(manager.isSessionValid, isTrue);
    });

    test('markValid / markInvalid update cached session flag', () {
      final manager = SessionManager(
        tokenService: TokenService(),
        validateWithBackend: () async => false,
      );

      expect(manager.isSessionValid, isFalse);
      manager.markValid();
      expect(manager.isSessionValid, isTrue);
      manager.markInvalid();
      expect(manager.isSessionValid, isFalse);
    });
  });
}
