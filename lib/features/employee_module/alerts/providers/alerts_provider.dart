import 'dart:async';

import 'package:flutter/material.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/alerts/data/models/device_alert_item.dart';
import 'package:obecno/features/alerts/services/alert_notification_service.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/services/manager_employees_service.dart';
import 'package:obecno/features/more/providers/device_provider.dart';

class AlertsProvider extends ChangeNotifier {
  AlertsProvider({
    required AuthProvider auth,
    required DeviceProvider devices,
    required ManagerEmployeesProvider employees,
    required ManagerEmployeesService employeesService,
  }) : _auth = auth,
       _devices = devices,
       _employees = employees,
       _employeesService = employeesService;

  final AuthProvider _auth;
  final DeviceProvider _devices;
  final ManagerEmployeesProvider _employees;
  final ManagerEmployeesService _employeesService;

  static const _pollInterval = Duration(seconds: 30);

  List<DeviceAlertItem> _items = const [];
  List<DeviceAlertItem> get items => _items;

  bool _loading = false;
  bool get isLoading => _loading;

  bool _managerView = false;
  bool get isManagerView => _managerView;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _actingKey;
  String? get actingKey => _actingKey;

  bool _started = false;
  bool _hasLoadedOnce = false;
  bool _refreshing = false;
  bool _unseenNotification = false;
  String? _lastEmployeeStatus;
  Set<String> _knownPendingKeys = {};
  Timer? _pollTimer;
  VoidCallback? _authListener;
  VoidCallback? _deviceListener;

  int get pendingCount => _items.where((item) => item.device.isPending).length;

  bool get showNavBadge => _unseenNotification || pendingCount > 0;

  void markAlertsSeen() {
    if (!_unseenNotification) return;
    _unseenNotification = false;
    notifyListeners();
  }

  void _flagNotification() {
    if (_unseenNotification) return;
    _unseenNotification = true;
    notifyListeners();
  }

  void start() {
    if (_started) return;
    _started = true;
    _authListener = _onAuthChanged;
    _deviceListener = _onDevicesChanged;
    _auth.addListener(_authListener!);
    _devices.addListener(_deviceListener!);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    if (!_auth.isAuthenticated) {
      reset();
      return;
    }
    _managerView = _auth.homeTarget == AuthHomeTarget.manager;
    unawaited(refresh());
    _armPoll();
  }

  void _onDevicesChanged() {
    if (!_auth.isAuthenticated || _managerView) return;
    _emitEmployeeApprovalIfNeeded();
    unawaited(refresh());
  }

  void _armPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!_auth.isAuthenticated) return;
      unawaited(refresh(silent: true));
    });
  }

  void _emitEmployeeApprovalIfNeeded() {
    final current =
        _devices.devices.where((d) => d.isCurrent).firstOrNull ??
        _devices.currentDevice;
    final status = current == null
        ? null
        : current.isApproved
        ? 'approved'
        : current.isPending
        ? 'pending'
        : 'other';
    if (_lastEmployeeStatus == 'pending' &&
        status == 'approved' &&
        current != null) {
      _flagNotification();
      unawaited(
        AlertNotificationService.notifyEmployeeApproved(
          deviceName: current.displayName,
        ),
      );
    }
    _lastEmployeeStatus = status;
  }

  Future<void> refresh({bool silent = false}) async {
    if (!_auth.isAuthenticated || _refreshing) return;
    _refreshing = true;
    _managerView = _auth.homeTarget == AuthHomeTarget.manager;
    if (!silent) {
      _loading = _items.isEmpty;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      if (_managerView) {
        await _loadManagerAlerts();
      } else {
        _loadEmployeeAlerts();
      }
      _loading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    } catch (e, st) {
      AppLogger.error('AlertsProvider', 'refresh', e, stackTrace: st);
      _loading = false;
      _errorMessage = 'Failed to load alerts.';
      notifyListeners();
    } finally {
      _refreshing = false;
    }
  }

  void _loadEmployeeAlerts() {
    final user = _auth.user;
    final name = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'You';
    final email = user?.email.trim();
    final location = user?.permissionLocation?.name.trim().isNotEmpty == true
        ? user!.permissionLocation!.name.trim()
        : (user?.locations.isNotEmpty == true
              ? user!.locations.first.name.trim()
              : null);
    final next = <DeviceAlertItem>[];
    final seen = <String>{};
    for (final device in _devices.devices) {
      if (!device.isPending && !device.isCurrent) continue;
      final item = DeviceAlertItem(
        device: device,
        employeeName: name,
        email: email,
        locationName: location,
      );
      if (!seen.add(item.key)) continue;
      next.add(item);
    }
    _items = next;
  }

  Future<void> _loadManagerAlerts() async {
    if (_employees.members.isEmpty) {
      await _employees.load();
    }

    final next = <DeviceAlertItem>[];
    final pendingKeys = <String>{};

    await Future.wait(
      _employees.members.map((member) async {
        final userId = member.userId;
        if (userId == null) return;
        final result = await _employeesService.loadEmployeeDevices(
          userId: userId,
        );
        if (!result.success || result.data == null) return;
        for (final device in result.data!) {
          if (!device.isPending &&
              !device.isRejected &&
              !device.isApproved &&
              !device.isBlocked) {
            continue;
          }
          final item = DeviceAlertItem(
            device: device,
            employeeName: member.name,
            employeeUserId: userId,
            email: member.email,
            locationName: member.locationName,
          );
          next.add(item);
          if (device.isPending) pendingKeys.add(item.key);
        }
      }),
    );

    next.sort((a, b) {
      if (a.device.isPending != b.device.isPending) {
        return a.device.isPending ? -1 : 1;
      }
      return b.device.cardTimestamp.compareTo(a.device.cardTimestamp);
    });

    if (_hasLoadedOnce) {
      for (final item in next) {
        if (!item.device.isPending) continue;
        if (_knownPendingKeys.contains(item.key)) continue;
        _flagNotification();
        unawaited(
          AlertNotificationService.notifyManagerDeviceRequest(
            employeeName: item.employeeName,
            deviceName: item.device.displayName,
          ),
        );
      }
    }

    _knownPendingKeys = pendingKeys;
    _items = next;
  }

  Future<bool> deleteRequest(DeviceAlertItem item, BuildContext context) async {
    if (_actingKey != null) return false;
    _actingKey = item.key;
    notifyListeners();
    final ok = await _devices.deleteDevice(item.device);
    _actingKey = null;
    if (ok) {
      _items = _items.where((e) => e.key != item.key).toList(growable: false);
      ToastHelper.deviceDeleted(context);
    } else {
      ToastHelper.deviceDeleteFailed(context, message: _devices.errorMessage);
    }
    notifyListeners();
    return ok;
  }

  Future<bool> review(
    DeviceAlertItem item,
    String action,
    BuildContext context,
  ) async {
    final userId = item.employeeUserId;
    if (userId == null || _actingKey != null) return false;
    _actingKey = item.key;
    notifyListeners();

    final result = await _employeesService.reviewEmployeeDevice(
      userId: userId,
      deviceId: item.device.id.isNotEmpty
          ? item.device.id
          : item.device.deviceId,
      action: action,
    );

    _actingKey = null;
    if (!result.success) {
      ToastHelper.error(
        context,
        message: result.message ?? 'Failed to update device.',
      );
      notifyListeners();
      return false;
    }

    if (action == 'approve') {
      ToastHelper.deviceApproved(context);
    } else {
      ToastHelper.deviceRejected(context);
    }
    await refresh();
    return true;
  }

  void reset() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _items = const [];
    _loading = false;
    _errorMessage = null;
    _actingKey = null;
    _hasLoadedOnce = false;
    _lastEmployeeStatus = null;
    _knownPendingKeys = {};
    _unseenNotification = false;
    _managerView = false;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_authListener != null) _auth.removeListener(_authListener!);
    if (_deviceListener != null) _devices.removeListener(_deviceListener!);
    _pollTimer?.cancel();
    super.dispose();
  }
}
