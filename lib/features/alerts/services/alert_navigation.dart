import 'dart:async';

import 'package:obecno/core/routes/app_routes.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/more/data/models/reminder_type.dart';
import 'package:obecno/main.dart';
import 'package:obecno/widgets/bottom_nav_bars/employee_nav.dart';
import 'package:obecno/widgets/bottom_nav_bars/manager_nav.dart';

class AlertNavigation {
  AlertNavigation._();

  static const employeePayload = 'alert_device_employee';
  static const managerPayload = 'alert_device_manager';
  static const managerLeavePayloadPrefix = 'alert_leave_manager';
  static const employeeLeavePayloadPrefix = 'alert_leave_employee';

  static bool pendingOpen = false;

  static bool get _isManager =>
      bindings.authProvider.homeTarget == AuthHomeTarget.manager;

  static String managerLeavePayload({int? leaveId, String? leaveKey}) {
    if (leaveId != null) return '$managerLeavePayloadPrefix:$leaveId';
    final key = (leaveKey ?? '').trim();
    if (key.isNotEmpty) return '$managerLeavePayloadPrefix:$key';
    return managerLeavePayloadPrefix;
  }

  static String employeeLeavePayload({int? leaveId, String? leaveKey}) {
    if (leaveId != null) return '$employeeLeavePayloadPrefix:$leaveId';
    final key = (leaveKey ?? '').trim();
    if (key.isNotEmpty) return '$employeeLeavePayloadPrefix:$key';
    return employeeLeavePayloadPrefix;
  }

  static bool isManagerLeavePayload(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    return payload == managerLeavePayloadPrefix ||
        payload.startsWith('$managerLeavePayloadPrefix:');
  }

  static bool isEmployeeLeavePayload(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    return payload == employeeLeavePayloadPrefix ||
        payload.startsWith('$employeeLeavePayloadPrefix:');
  }

  static bool isLeavePayload(String? payload) {
    return isManagerLeavePayload(payload) || isEmployeeLeavePayload(payload);
  }

  static String? leaveKeyFromPayload(String? payload) {
    if (!isLeavePayload(payload)) return null;
    final prefix = isEmployeeLeavePayload(payload)
        ? employeeLeavePayloadPrefix
        : managerLeavePayloadPrefix;
    if (payload == prefix) return null;
    final parts = payload!.split(':');
    if (parts.length < 2) return null;
    final rest = parts.sublist(1).join(':').trim();
    if (rest.isEmpty) return null;
    // Numeric id → leave_<id> key used by ManagerTeamLeaveItem.alertKey.
    final asInt = int.tryParse(rest);
    if (asInt != null) return 'leave_$asInt';
    return rest.startsWith('leave_') ? rest : 'leave_$rest';
  }

  /// Device-alert, leave, reminder, smart-attendance, and test payloads.
  static bool isNavigablePayload(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    if (payload == employeePayload || payload == managerPayload) return true;
    if (isLeavePayload(payload)) return true;
    if (payload == 'test') return true;
    if (payload.startsWith('smart-')) return true;
    return ReminderType.fromStorageKey(payload) != null;
  }

  /// Alerts chip to select when a notification is tapped.
  static String? filterForPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    if (isLeavePayload(payload)) return 'leaves';
    if (payload == 'test') return 'reminder';
    if (payload.startsWith('smart-')) return 'reminder';
    if (ReminderType.fromStorageKey(payload) != null) return 'reminder';
    return null;
  }

  static String _currentPath() {
    try {
      return router.routeInformationProvider.value.uri.path;
    } catch (_) {
      return '';
    }
  }

  /// Splash uses this so a notification tap opens the Alerts tab for the
  /// signed-in role instead of always landing on the employee nav.
  ///
  /// Leaves [pendingOpen] set so the nav (or [_openWhenReady]) can still
  /// consume it if [goToAlerts] races ahead of the first frame.
  static String destinationAfterSplash(String dest) {
    if (!pendingOpen) return dest;
    if (dest != '/manager_nav' && dest != '/employee_nav') return dest;
    if (_isManager) {
      // Keep filter/leave key already staged by [handleNotificationTap].
      ManagerBottomNavBar.goToAlerts(
        filter: ManagerBottomNavBar.pendingAlertsFilter,
        leaveKey: ManagerBottomNavBar.pendingAlertsLeaveKey,
      );
      return '/manager_nav';
    }
    EmployeeBottomNavBar.goToAlerts(
      filter: EmployeeBottomNavBar.pendingAlertsFilter,
      leaveKey: EmployeeBottomNavBar.pendingAlertsLeaveKey,
    );
    return '/employee_nav';
  }

  static void openAlerts({bool? manager, String? filter, String? leaveKey}) {
    final openManager = manager ?? _isManager;
    if (openManager) {
      ManagerBottomNavBar.goToAlerts(filter: filter, leaveKey: leaveKey);
      if (_currentPath() != '/manager_nav') {
        router.go('/manager_nav');
      }
      return;
    }
    EmployeeBottomNavBar.goToAlerts(filter: filter, leaveKey: leaveKey);
    if (_currentPath() != '/employee_nav') {
      router.go('/employee_nav');
    }
  }

  static void handleNotificationTap(String? payload) {
    if (!isNavigablePayload(payload)) return;
    pendingOpen = true;
    final filter = filterForPayload(payload);
    if (isLeavePayload(payload)) {
      final leaveKey = leaveKeyFromPayload(payload);
      if (isEmployeeLeavePayload(payload) || !_isManager) {
        EmployeeBottomNavBar.pendingAlertsFilter = 'leaves';
        EmployeeBottomNavBar.pendingAlertsLeaveKey = leaveKey;
      } else {
        ManagerBottomNavBar.pendingAlertsFilter = 'leaves';
        ManagerBottomNavBar.pendingAlertsLeaveKey = leaveKey;
      }
    } else if (filter != null) {
      // Reminder (and smart/test) taps open Alerts on the Reminder chip for
      // both roles — set before nav mounts so cold-start still applies it.
      ManagerBottomNavBar.pendingAlertsFilter = filter;
      EmployeeBottomNavBar.pendingAlertsFilter = filter;
    }
    unawaited(_openWhenReady(payload));
  }

  static Future<void> _openWhenReady(String? payload) async {
    for (var i = 0; i < 50; i++) {
      if (bindings.authProvider.isAuthenticated) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!bindings.authProvider.isAuthenticated) return;

    final leaveKey = leaveKeyFromPayload(payload);
    final filter = filterForPayload(payload);

    // Splash / login may still be navigating; wait until home nav is up, or
    // until another path already consumed [pendingOpen].
    for (var i = 0; i < 50; i++) {
      if (!pendingOpen) return;
      final path = _currentPath();
      if (path == '/manager_nav' || path == '/employee_nav') {
        pendingOpen = false;
        openAlerts(
          manager: path == '/manager_nav' || _isManager,
          filter: filter,
          leaveKey: leaveKey,
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (!pendingOpen) return;
    pendingOpen = false;
    openAlerts(
      filter: filter,
      leaveKey: leaveKey,
    );
  }
}
