import 'dart:async';

import 'package:obecno/core/routes/app_routes.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/main.dart';
import 'package:obecno/widgets/bottom_nav_bars/employee_nav.dart';
import 'package:obecno/widgets/bottom_nav_bars/manager_nav.dart';

class AlertNavigation {
  AlertNavigation._();

  static const employeePayload = 'alert_device_employee';
  static const managerPayload = 'alert_device_manager';

  static bool pendingOpen = false;

  static bool get _isManager =>
      bindings.authProvider.homeTarget == AuthHomeTarget.manager;

  static bool _isAlertPayload(String? payload) {
    return payload == employeePayload || payload == managerPayload;
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
  static String destinationAfterSplash(String dest) {
    if (!pendingOpen) return dest;
    if (dest != '/manager_nav' && dest != '/employee_nav') return dest;
    pendingOpen = false;
    if (_isManager) {
      ManagerBottomNavBar.goToAlerts();
      return '/manager_nav';
    }
    EmployeeBottomNavBar.goToAlerts();
    return '/employee_nav';
  }

  static void openAlerts({bool? manager}) {
    final openManager = manager ?? _isManager;
    if (openManager) {
      ManagerBottomNavBar.goToAlerts();
      if (_currentPath() != '/manager_nav') {
        router.go('/manager_nav');
      }
      return;
    }
    EmployeeBottomNavBar.goToAlerts();
    if (_currentPath() != '/employee_nav') {
      router.go('/employee_nav');
    }
  }

  static void handleNotificationTap(String? payload) {
    if (!_isAlertPayload(payload)) return;
    pendingOpen = true;
    unawaited(_openWhenReady());
  }

  static Future<void> _openWhenReady() async {
    for (var i = 0; i < 50; i++) {
      if (bindings.authProvider.isAuthenticated) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!bindings.authProvider.isAuthenticated) return;

    final path = _currentPath();
    if (path == '/manager_nav' || path == '/employee_nav') {
      pendingOpen = false;
      openAlerts(manager: path == '/manager_nav' || _isManager);
      return;
    }
  }
}
