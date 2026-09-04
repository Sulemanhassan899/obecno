import 'package:obecno/features/auth/data/models/auth_user_model.dart';
import 'package:obecno/features/auth/data/models/communication_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommunicationOptions', () {
    test('email shows only the email icon', () {
      final options = CommunicationOptions.parse('email');
      expect(options.showEmail, isTrue);
      expect(options.showCall, isFalse);
      expect(options.showMessage, isFalse);
      expect(options.showWhatsapp, isFalse);
    });

    test('phone shows call, message, and whatsapp', () {
      final options = CommunicationOptions.parse('phone');
      expect(options.showCall, isTrue);
      expect(options.showMessage, isTrue);
      expect(options.showWhatsapp, isTrue);
      expect(options.showEmail, isFalse);
    });

    test('combines email and phone', () {
      final options = CommunicationOptions.parse('email,phone');
      expect(options.showEmail, isTrue);
      expect(options.showCall, isTrue);
      expect(options.showMessage, isTrue);
      expect(options.showWhatsapp, isTrue);
    });

    test('parses a list of options', () {
      final options = CommunicationOptions.parse(['sms', 'email']);
      expect(options.showMessage, isTrue);
      expect(options.showEmail, isTrue);
      expect(options.showCall, isFalse);
      expect(options.showWhatsapp, isFalse);
    });

    test('whatsapp alone shows only whatsapp', () {
      final options = CommunicationOptions.parse('whatsapp');
      expect(options.showWhatsapp, isTrue);
      expect(options.showCall, isFalse);
      expect(options.showMessage, isFalse);
      expect(options.showEmail, isFalse);
    });
  });

  group('AuthUserModel communication_option', () {
    test('reads communication_option from /auth/me payload', () {
      final user = AuthUserModel.fromJson({
        'id': 1,
        'name': 'Owner',
        'email': 'owner@example.com',
        'communication_option': 'email',
      });
      expect(user.communicationOptions.showEmail, isTrue);
      expect(user.communicationOptions.showCall, isFalse);
    });

    test('reads nested user.communication_options list', () {
      final user = AuthUserModel.fromJson({
        'user': {
          'id': 1,
          'name': 'Owner',
          'email': 'owner@example.com',
          'communication_options': ['phone', 'email'],
        },
      });
      expect(user.communicationOptions.showCall, isTrue);
      expect(user.communicationOptions.showEmail, isTrue);
    });
  });
}
