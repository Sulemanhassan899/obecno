import 'dart:async';

import 'package:flutter/material.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/alerts/data/models/device_alert_item.dart';
import 'package:obecno/features/alerts/services/alert_notification_service.dart';
import 'package:obecno/features/alerts/services/alert_seen_store.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/services/manager_employees_service.dart';
import 'package:obecno/features/more/data/models/device_model.dart';
import 'package:obecno/features/more/providers/device_provider.dart';

class AlertsProvider extends ChangeNotifier {
  AlertsProvider({
    required AuthProvider auth,
    required DeviceProvider devices,
    required ManagerEmployeesProvider employees,
    required ManagerEmployeesService employeesService,
    AlertSeenStore? seenStore,
  }) : _auth = auth,
       _devices = devices,
       _employees = employees,
       _employeesService = employeesService,
       _seenStore = seenStore ?? AlertSeenStore();

  final AuthProvider _auth;
  final DeviceProvider _devices;
  final ManagerEmployeesProvider _employees;
  final ManagerEmployeesService _employeesService;
  final AlertSeenStore _seenStore;

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
  Set<String> _knownPendingKeys = {};
  /// Non-pending cards marked seen this session stay visible until restart.
  Set<String> _keepVisibleThisSession = {};
  Timer? _pollTimer;
  VoidCallback? _authListener;
  VoidCallback? _deviceListener;
  Future<void>? _emitApprovalInFlight;
  String? _observedEmployeeStatus;

  int get pendingCount => _items.where((item) => item.device.isPending).length;

  bool get showNavBadge => _unseenNotification || pendingCount > 0;

  void markAlertsSeen() {
    // Persist for the next cold start, but keep cards on screen this session
    // so the Approved status (screenshot) remains readable on Alerts.
    final toMark = _items
        .where((item) => !item.device.isPending)
        .map((item) => item.key)
        .toSet();
    if (toMark.isNotEmpty) {
      _keepVisibleThisSession.addAll(toMark);
      unawaited(_seenStore.markSeen(toMark));
    }
    if (_unseenNotification) {
      _unseenNotification = false;
    }
    notifyListeners();
  }

  bool _shouldShowNonPending(String key) {
    if (_keepVisibleThisSession.contains(key)) return true;
    return !_seenStore.contains(key);
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
    unawaited(_emitEmployeeApprovalIfNeeded());
    unawaited(refresh());
  }

  void _armPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!_auth.isAuthenticated) return;
      unawaited(refresh(silent: true));
    });
  }

  bool _isThisPhone(DeviceModel device) {
    if (device.isCurrent || _isLocalCurrent(device)) return true;
    final local = _devices.currentDevice;
    if (local == null) return false;
    return device.matchesPhysicalDevice(
      currentDeviceId: local.deviceId,
      model: local.model,
      manufacturer: local.manufacturer,
      platform: local.platform,
      name: local.name,
    );
  }

  DeviceModel? _employeeNoticeDevice() {
    DeviceModel? pendingForPhone;
    DeviceModel? currentRow;
    for (final device in _devices.devices) {
      if (!_isThisPhone(device)) continue;
      currentRow ??= device;
      if (device.isPending) pendingForPhone ??= device;
    }
    // A new request for this phone must be observed even if an older
    // approved row is still ranked as the current device.
    if (pendingForPhone != null) return pendingForPhone;
    if (currentRow != null) return currentRow;

    final local = _devices.currentDevice;
    if (local == null) return null;
    // Local fetch stub: empty id + empty status. DeviceModel treats that
    // as pending, which previously retriggered the approval push on launch.
    if (local.id.trim().isEmpty && local.normalizedStatus.isEmpty) {
      return null;
    }
    return local;
  }

  String _employeeDeviceStatus(DeviceModel device) {
    if (device.isApproved) return 'approved';
    if (device.isPending) return 'pending';
    return 'other';
  }

  String _employeeNoticeKey(DeviceModel device) {
    final deviceId = device.deviceId.trim();
    if (deviceId.isNotEmpty) return deviceId;
    return device.id.trim();
  }

  Future<void> _emitEmployeeApprovalIfNeeded() {
    final previous = _emitApprovalInFlight ?? Future.value();
    final run = previous.then((_) => _emitEmployeeApprovalOnce());
    _emitApprovalInFlight = run.catchError((_) {});
    return run;
  }

  Future<void> _emitEmployeeApprovalOnce() async {
    if (!_auth.isAuthenticated || _managerView) return;
    await _seenStore.load();
    if (!_auth.isAuthenticated || _managerView) return;

    final current = _employeeNoticeDevice();
    if (current == null) return;

    final status = _employeeDeviceStatus(current);
    final noticeKey = _employeeNoticeKey(current);
    if (status == 'pending') {
      await _seenStore.clearEmployeeApprovalNotice();
    }

    final previous = _observedEmployeeStatus ?? _seenStore.lastEmployeeStatus;
    final becameApproved = previous == 'pending' && status == 'approved';
    if (becameApproved &&
        !_seenStore.alreadyNotifiedEmployeeApproval(noticeKey)) {
      await _seenStore.markEmployeeApprovalNotified(noticeKey);
      final item = DeviceAlertItem(
        device: current,
        employeeName: _auth.user?.name.trim().isNotEmpty == true
            ? _auth.user!.name.trim()
            : 'You',
      );
      await _seenStore.addOneshot(item.key);
      _flagNotification();
      unawaited(
        AlertNotificationService.notifyEmployeeApproved(
          deviceName: current.displayName,
        ),
      );
    }

    _observedEmployeeStatus = status;
    await _seenStore.setLastEmployeeStatus(status);
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
      await _seenStore.load();
      if (_managerView) {
        await _loadManagerAlerts();
      } else {
        await _emitEmployeeApprovalIfNeeded();
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

  bool _isLocalCurrent(DeviceModel device) {
    if (device.isCurrent) return true;
    final local = _devices.currentDevice;
    if (local == null) return false;
    final localId = local.deviceId.trim();
    if (localId.isEmpty) return false;
    return device.deviceId.trim() == localId || device.id.trim() == localId;
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
      final item = DeviceAlertItem(
        device: device,
        employeeName: name,
        email: email,
        locationName: location,
      );
      if (!seen.add(item.key)) continue;

      // Pending requests always stay on the Alerts screen.
      if (device.isPending) {
        next.add(item);
        continue;
      }

      // Approved current device: show once across app launches.
      if (!device.isApproved || !_isLocalCurrent(device)) continue;
      if (!_shouldShowNonPending(item.key)) continue;
      next.add(item);
    }

    _items = next;
  }

  Future<void> _loadManagerAlerts() async {
    if (_employees.members.isEmpty) {
      await _employees.load();
    }

    final collected = <DeviceAlertItem>[];
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
          final item = DeviceAlertItem(
            device: device,
            employeeName: member.name,
            employeeUserId: userId,
            email: member.email,
            locationName: member.locationName,
          );

          if (device.isPending) {
            collected.add(item);
            pendingKeys.add(item.key);
            continue;
          }

          // Approved / rejected / blocked cards show once per device request.
          if ((device.isRejected ||
                  device.isApproved ||
                  device.isBlocked) &&
              _shouldShowNonPending(item.key)) {
            collected.add(item);
          }
        }
      }),
    );

    collected.sort((a, b) {
      if (a.device.isPending != b.device.isPending) {
        return a.device.isPending ? -1 : 1;
      }
      return b.device.cardTimestamp.compareTo(a.device.cardTimestamp);
    });

    if (_hasLoadedOnce) {
      for (final item in collected) {
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
    _items = collected;
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
    _knownPendingKeys = {};
    _keepVisibleThisSession = {};
    _unseenNotification = false;
    _managerView = false;
    _observedEmployeeStatus = null;
    _emitApprovalInFlight = null;
    unawaited(_seenStore.clear());
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
