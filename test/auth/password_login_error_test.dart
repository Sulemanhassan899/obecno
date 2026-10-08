import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';

void main() {
  test('wrong password is reported as a password error', () {
    expect(
      passwordLoginErrorMessage('Invalid email or password.'),
      'Invalid password.',
    );
    expect(passwordLoginErrorMessage(null), 'Invalid password.');
    expect(
      passwordLoginErrorMessage('Invalid credentials'),
      'Invalid credentials',
    );
  });

  test('password rules stay specific and email replies do not', () {
    expect(
      passwordLoginErrorMessage('Password must be at least 8 characters.'),
      'Password must be at least 8 characters.',
    );
    expect(
      passwordLoginErrorMessage('Please verify your email again.'),
      'Invalid password.',
    );
    expect(
      passwordLoginErrorMessage('Your session has expired. Please log in again.'),
      'Invalid password.',
    );
  });
}
