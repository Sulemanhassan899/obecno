import 'package:obecno/features/more/data/models/help_feedback_ticket_model.dart';
import 'package:obecno/features/more/data/domain/help_feedback_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HelpFeedbackPhone', () {
    test('splits Pakistani numbers with a leading zero', () {
      final parts = HelpFeedbackPhone.split('03001234567');
      expect(parts.code, '+92');
      expect(parts.number, '3001234567');
    });

    test('splits an international number with a plus prefix', () {
      final parts = HelpFeedbackPhone.split('+1 2025550123');
      expect(parts.code, '+1');
      expect(parts.number, '2025550123');
    });
  });

  group('HelpFeedbackEntity', () {
    test('builds ticket content with user, device, and issue details', () {
      const entity = HelpFeedbackEntity(
        name: 'Ali Khan',
        email: 'ali@obecno.com',
        phoneCode: '+92',
        phone: '3001234567',
        department: 'Sales',
        issue: 'Clock in is failing',
        deviceName: 'Pixel 8',
        deviceMac: 'aa-bb-cc',
        complaintDate: '2026-09-11 20:51',
        employeeId: '42',
        company: 'Obecno',
        role: 'Employee',
        designation: 'Associate',
        employeeCode: 'EMP-1',
        os: 'android 14',
        appVersion: '1.1.0',
      );

      final content = entity.buildContentMessage();
      expect(content, contains('Issue:'));
      expect(content, contains('Clock in is failing'));
      expect(content, contains('Name: Ali Khan'));
      expect(content, contains('Email: ali@obecno.com'));
      expect(content, contains('Phone: +92 3001234567'));
      expect(content, contains('Department: Sales'));
      expect(content, contains('Device name: Pixel 8'));
      expect(content, contains('Device MAC: aa-bb-cc'));
      expect(content, contains('Date of complaint: 2026-09-11 20:51'));
      expect(content, contains('Employee ID: 42'));
      expect(content, contains('Company: Obecno'));
    });

    test('maps to the tickets API payload', () {
      const entity = HelpFeedbackEntity(
        name: 'Ali Khan',
        email: 'ali@obecno.com',
        phoneCode: '+92',
        phone: '3001234567',
        department: 'Sales',
        issue: 'Need help',
        deviceName: 'iPhone',
        deviceMac: 'id-1',
        complaintDate: '2026-09-11 20:51',
      );

      final json = HelpFeedbackTicketModel(entity: entity).toJson();
      expect(json['user_name'], 'Ali Khan');
      expect(json['user_email'], 'ali@obecno.com');
      expect(json['content'], contains('Need help'));
      expect(json['content'], contains('Device MAC: id-1'));
    });
  });
}
