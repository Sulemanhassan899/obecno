// lib/core/validators/validators.dart
import '../constants/app_enums.dart';

/// Centralized form-validation helpers.
///
/// All methods return `null` when the value is valid, or a user-facing
/// error `String` when it isn't — the standard `FormFieldValidator<String>`
/// contract, so these can be dropped straight into a `TextFormField`'s
/// `validator:` parameter.
class Validators {
  Validators._();

  /// Generic "field must not be empty" check.
  static String? required(String? value, {String? label}) {
    if (value == null || value.trim().isEmpty) {
      return '${label ?? 'This field'} is required.';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final regex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w]{2,4}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email.';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone is required.';
    final regex = RegExp(r'^0[0-9]{10}$');
    if (!regex.hasMatch(value.replaceAll('-', '').replaceAll(' ', ''))) {
      return 'Enter a valid Pakistani phone (03XXXXXXXXX).';
    }
    return null;
  }

  static String? password(String? value, {int minLength = 8}) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String? original) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.isEmpty) return null; // optional
    final parsed = double.tryParse(value);
    if (parsed == null || parsed < 0) return 'Enter a valid amount.';
    return null;
  }

  /// Classifies password strength as weak / medium / strong.
  ///
  /// Scoring is based on length plus the variety of character classes
  /// present (lowercase, uppercase, digits, symbols).
  static PasswordStrength passwordStrength(String? value) {
    if (value == null || value.isEmpty) return PasswordStrength.weak;

    int score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[a-z]').hasMatch(value)) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=]').hasMatch(value)) score++;

    if (score >= 5) return PasswordStrength.strong;
    if (score >= 3) return PasswordStrength.medium;
    return PasswordStrength.weak;
  }

  /// Human-readable label for [passwordStrength] results.
  static String passwordStrengthLabel(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.strong:
        return 'Strong';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.weak:
        return 'Weak';
    }
  }
}
