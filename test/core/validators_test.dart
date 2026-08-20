import 'package:Obecno/core/constants/app_enums.dart';
import 'package:Obecno/core/validators/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.email', () {
    test('rejects empty', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('accepts valid email', () {
      expect(Validators.email('user@obecno.com'), isNull);
    });

    test('rejects invalid email', () {
      expect(Validators.email('not-an-email'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('requires length, cases, digit, symbol', () {
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('alllowercase1!'), isNotNull);
      expect(Validators.password('ALLUPPERCASE1!'), isNotNull);
      expect(Validators.password('NoDigitsHere!'), isNotNull);
      expect(Validators.password('NoSymbolHere1'), isNotNull);
      expect(Validators.password('GoodPass1!'), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('must match', () {
      expect(Validators.confirmPassword('a', 'b'), isNotNull);
      expect(Validators.confirmPassword('a', 'a'), isNull);
    });
  });

  group('Validators.passwordStrength', () {
    test('scores weak to strong', () {
      expect(Validators.passwordStrength('a'), PasswordStrength.weak);
      expect(
        Validators.passwordStrength('Abcdef12!'),
        isNot(PasswordStrength.weak),
      );
    });
  });

  group('Validators.phone', () {
    test('accepts Pakistani mobile', () {
      expect(Validators.phone('03001234567'), isNull);
      expect(Validators.phone('123'), isNotNull);
    });
  });
}
