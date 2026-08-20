import 'package:Obecno/features/auth/data/models/token_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TokenModel', () {
    test('builds authorization header', () {
      final token = TokenModel(
        accessToken: 'abc',
        tokenType: 'Bearer',
        expiresIn: 3600,
        issuedAt: DateTime.now(),
      );
      expect(token.authorizationHeader, 'Bearer abc');
      expect(token.isExpired, isFalse);
    });

    test('isExpired when issued in the past', () {
      final token = TokenModel(
        accessToken: 'abc',
        tokenType: 'Bearer',
        expiresIn: 1,
        issuedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(token.isExpired, isTrue);
    });

    test('round-trips storage json', () {
      final original = TokenModel(
        accessToken: 'tok',
        tokenType: 'Bearer',
        expiresIn: 100,
        issuedAt: DateTime.parse('2026-01-01T00:00:00.000'),
      );
      final restored = TokenModel.fromStorageJson(original.toStorageJson());
      expect(restored?.accessToken, 'tok');
      expect(restored?.expiresIn, 100);
    });

    test('fromJson requires access_token', () {
      expect(TokenModel.fromJson({}), isNull);
      expect(
        TokenModel.fromJson({'access_token': 'x', 'expires_in': 10})
            ?.accessToken,
        'x',
      );
    });
  });
}
