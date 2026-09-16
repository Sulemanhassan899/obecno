import 'package:obecno/features/alerts/services/alert_navigation.dart';
import 'package:obecno/features/more/services/reminder_notification_service.dart';

class AlertNotificationService {
  AlertNotificationService._();

  static const _employeeId = 9101;
  static const _managerId = 9102;

  static Future<void> notifyEmployeeApproved({required String deviceName}) {
    return ReminderNotificationService.instance.showCustom(
      id: _employeeId,
      title: 'Device request approved',
      body: '$deviceName is now approved for attendance.',
      payload: AlertNavigation.employeePayload,
    );
  }

  static Future<void> notifyManagerDeviceRequest({
    required String employeeName,
    required String deviceName,
  }) {
    return ReminderNotificationService.instance.showCustom(
      id: _managerId,
      title: 'New device request',
      body: '$employeeName requested approval for $deviceName.',
      payload: AlertNavigation.managerPayload,
    );
  }
}
