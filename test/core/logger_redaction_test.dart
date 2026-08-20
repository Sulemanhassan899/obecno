import 'package:Obecno/core/services/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLogger.redact', () {
    test('masks password and token fields', () {
      final redacted = AppLogger.redact({
        'email': 'a@b.com',
        'password': 'secret',
        'access_token': 'tok_123',
        'nested': {'new_password': 'x'},
      }) as Map;

      expect(redacted['email'], 'a@b.com');
      expect(redacted['password'], '***');
      expect(redacted['access_token'], '***');
      expect((redacted['nested'] as Map)['new_password'], '***');
    });

    test('masks bearer headers and coordinates', () {
      expect(AppLogger.redact('Bearer abc.def'), 'Bearer ***');
      final map = AppLogger.redact({'lat': 1.2, 'lon': 3.4}) as Map;
      expect(map['lat'], '***');
      expect(map['lon'], '***');
    });
  });
}
