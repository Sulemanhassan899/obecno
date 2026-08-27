import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/shared/bottom_sheets/edit_sheets/edit_account_field_sheet.dart';

void main() {
  group('AccountEditField', () {
    test('validates email, phone, and address', () {
      expect(AccountEditField.email.validate(''), 'Email is required.');
      expect(
        AccountEditField.email.validate('bad@'),
        'Enter a valid email address.',
      );
      expect(AccountEditField.email.validate('employee1@thedemo.com'), isNull);

      expect(
        AccountEditField.phone.validate('123'),
        'Enter a valid phone number.',
      );
      expect(AccountEditField.phone.validate('+1234567890'), isNull);

      expect(AccountEditField.address.validate(''), 'Address is required.');
      expect(AccountEditField.address.validate('Al Wasl Road, Dubai'), isNull);
    });

    test('builds a payload with only the edited field', () {
      expect(AccountEditField.phone.payload('+19876543210'), {
        'phone': '+19876543210',
        'phone_number': '+19876543210',
      });
      expect(AccountEditField.email.payload('new.email@thedemo.com'), {
        'email': 'new.email@thedemo.com',
      });
      expect(AccountEditField.companyId.payload('12'), {
        'employee_code': '12',
        'staff_id': '12',
        'employee_id_number': '12',
      });
      expect(AccountEditField.address.payload('street 1'), {
        'address': 'street 1',
        'home_address': 'street 1',
        'present_address': 'street 1',
        'permanent_address': 'street 1',
        'employee': {'address': 'street 1', 'home_address': 'street 1'},
        'profile': {'address': 'street 1', 'home_address': 'street 1'},
      });
    });

    test('surfaces email field errors and ignores generic API summaries', () {
      final highlighted = ApiResponse<void>.failure(
        'Please fix the highlighted fields.',
        fieldErrors: const {
          'photo': ['Profile photo is required.'],
        },
      );
      expect(
        AccountEditField.email.saveFailureMessage(highlighted),
        'Failed to update email.',
      );

      final emailTaken = ApiResponse<void>.failure(
        'Please fix the highlighted fields.',
        fieldErrors: const {
          'email': ['This email is already in use.'],
        },
      );
      expect(
        AccountEditField.email.saveFailureMessage(emailTaken),
        'This email is already in use.',
      );
    });

    test('uses Phone Number as the edit label', () {
      expect(AccountEditField.phone.label, 'Phone Number');
      expect(AccountEditField.address.maxLines, 3);
    });
  });
}
