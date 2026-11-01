import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/features/alerts/services/alert_navigation.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlertNavigation leave payloads', () {
    test('builds manager and employee leave payloads from id or key', () {
      expect(
        AlertNavigation.managerLeavePayload(leaveId: 12),
        'alert_leave_manager:12',
      );
      expect(
        AlertNavigation.managerLeavePayload(leaveKey: 'leave_9'),
        'alert_leave_manager:leave_9',
      );
      expect(
        AlertNavigation.employeeLeavePayload(leaveId: 44),
        'alert_leave_employee:44',
      );
      expect(
        AlertNavigation.employeeLeavePayload(leaveKey: 'leave_44'),
        'alert_leave_employee:leave_44',
      );
      expect(
        AlertNavigation.employeeLeavePayload(),
        AlertNavigation.employeeLeavePayloadPrefix,
      );
    });

    test('detects manager vs employee leave payloads', () {
      expect(
        AlertNavigation.isManagerLeavePayload('alert_leave_manager:7'),
        isTrue,
      );
      expect(
        AlertNavigation.isEmployeeLeavePayload('alert_leave_employee:7'),
        isTrue,
      );
      expect(
        AlertNavigation.isLeavePayload('alert_leave_employee:7'),
        isTrue,
      );
      expect(
        AlertNavigation.isEmployeeLeavePayload('alert_leave_manager:7'),
        isFalse,
      );
      expect(AlertNavigation.isLeavePayload(null), isFalse);
      expect(AlertNavigation.isLeavePayload(''), isFalse);
    });

    test('leaveKeyFromPayload normalizes numeric ids to leave_<id>', () {
      expect(
        AlertNavigation.leaveKeyFromPayload('alert_leave_employee:18'),
        'leave_18',
      );
      expect(
        AlertNavigation.leaveKeyFromPayload('alert_leave_manager:leave_18'),
        'leave_18',
      );
      expect(
        AlertNavigation.leaveKeyFromPayload('alert_leave_employee:abc'),
        'leave_abc',
      );
      expect(
        AlertNavigation.leaveKeyFromPayload(
          AlertNavigation.employeeLeavePayloadPrefix,
        ),
        isNull,
      );
      expect(AlertNavigation.leaveKeyFromPayload('unrelated'), isNull);
    });

    test('leave taps open Alerts on the leaves chip', () {
      expect(
        AlertNavigation.filterForPayload('alert_leave_employee:3'),
        'leaves',
      );
      expect(
        AlertNavigation.filterForPayload('alert_leave_manager:3'),
        'leaves',
      );
      expect(
        AlertNavigation.filterForPayload(ReminderType.checkIn.storageKey),
        'reminder',
      );
      expect(AlertNavigation.filterForPayload('smart-enter'), 'reminder');
      expect(AlertNavigation.filterForPayload('test'), 'reminder');
      expect(AlertNavigation.filterForPayload(null), isNull);
    });

    test('employee leave decision payloads are navigable', () {
      expect(
        AlertNavigation.isNavigablePayload('alert_leave_employee:5'),
        isTrue,
      );
      expect(
        AlertNavigation.isNavigablePayload('alert_leave_manager:5'),
        isTrue,
      );
      expect(
        AlertNavigation.isNavigablePayload(AlertNavigation.employeePayload),
        isTrue,
      );
      expect(AlertNavigation.isNavigablePayload('garbage'), isFalse);
    });
  });
}
