import 'package:Obecno/features/auth/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuthHomeTarget distinguishes roles', () {
    expect(AuthHomeTarget.values, contains(AuthHomeTarget.employee));
    expect(AuthHomeTarget.values, contains(AuthHomeTarget.manager));
  });
}
