import 'package:obecno/features/alerts/services/alert_navigation.dart';
import 'package:obecno/features/more/services/reminder_notification_service.dart';

class AlertNotificationService {
  AlertNotificationService._();

  static const _employeeId = 9101;
  static const _managerId = 9102;
  static const _managerLeaveIdBase = 9200;
  static const _employeeLeaveIdBase = 9300;

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

  /// Tap-only leave request banner (no Approve/Reject actions on the tray).
  static Future<void> notifyManagerLeaveRequest({
    required String employeeName,
    required String leaveType,
    String? leaveKey,
    int? leaveId,
  }) {
    final name = employeeName.trim().isEmpty ? 'Employee' : employeeName.trim();
    final type = leaveType.trim().isEmpty ? 'Leave' : leaveType.trim();
    final id = leaveId != null
        ? _managerLeaveIdBase + (leaveId % 700)
        : _managerLeaveIdBase + (leaveKey?.hashCode.abs() ?? 0) % 700;
    return ReminderNotificationService.instance.showCustom(
      id: id,
      title: '$name has requested a leave',
      body: type,
      payload: AlertNavigation.managerLeavePayload(
        leaveId: leaveId,
        leaveKey: leaveKey,
      ),
    );
  }

  /// Employee leave decision banner after manager approve/reject.
  static Future<void> notifyEmployeeLeaveDecision({
    required bool approved,
    required String leaveType,
    String? leaveKey,
    int? leaveId,
  }) {
    final type = leaveType.trim().isEmpty ? 'Leave' : leaveType.trim();
    final id = leaveId != null
        ? _employeeLeaveIdBase + (leaveId % 700)
        : _employeeLeaveIdBase + (leaveKey?.hashCode.abs() ?? 0) % 700;
    return ReminderNotificationService.instance.showCustom(
      id: id,
      title: approved ? 'Leave approved' : 'Leave rejected',
      body: type,
      payload: AlertNavigation.employeeLeavePayload(
        leaveId: leaveId,
        leaveKey: leaveKey,
      ),
    );
  }
}
