import 'package:obecno/features/auth/data/models/token_model.dart';
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

    test('fromJson defaults missing or zero expires_in', () {
      final missing = TokenModel.fromJson({'access_token': 'x'});
      expect(missing?.expiresIn, TokenModel.defaultExpiresInSeconds);
      expect(missing?.isExpired, isFalse);

      final zero = TokenModel.fromJson({
        'access_token': 'x',
        'expires_in': 0,
      });
      expect(zero?.expiresIn, TokenModel.defaultExpiresInSeconds);
      expect(zero?.isExpired, isFalse);
    });

    test('fromJson reads nested token object', () {
      final token = TokenModel.fromJson({
        'token': {
          'access_token': 'nested',
          'token_type': 'Bearer',
          'expires_in': 120,
        },
      });
      expect(token?.accessToken, 'nested');
      expect(token?.expiresIn, 120);
    });

    test('fromJson and storage keep refresh_token', () {
      final token = TokenModel.fromJson({
        'access_token': 'a',
        'refresh_token': 'r',
        'expires_in': 60,
      });
      expect(token?.refreshToken, 'r');
      final restored = TokenModel.fromStorageJson(token!.toStorageJson());
      expect(restored?.refreshToken, 'r');
    });
  });
}
