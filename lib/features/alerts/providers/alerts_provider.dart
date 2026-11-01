import 'dart:async';

import 'package:flutter/material.dart';
import 'package:obecno/core/helpers/toast_helper.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/auth/providers/auth_provider.dart';
import 'package:obecno/features/alerts/data/models/device_alert_item.dart';
import 'package:obecno/features/alerts/services/alert_notification_service.dart';
import 'package:obecno/features/alerts/services/alert_seen_store.dart';
import 'package:obecno/features/alerts/services/leave_alert_store.dart';
import 'package:obecno/features/employee_module/leaves/data/models/leave_models.dart';
import 'package:obecno/features/manager_module/Manager_employees/providers/manager_employees_provider.dart';
import 'package:obecno/features/manager_module/Manager_employees/services/manager_employees_service.dart';
import 'package:obecno/features/manager_module/Manager_overview/data/models/manager_overview_models.dart';
import 'package:obecno/features/manager_module/Manager_overview/providers/manager_overview_provider.dart';
import 'package:obecno/features/manager_module/Manager_overview/services/manager_overview_service.dart';
import 'package:obecno/features/more/data/models/device_model.dart';
import 'package:obecno/features/more/providers/device_provider.dart';
import 'package:obecno/main.dart';

class AlertsProvider extends ChangeNotifier {
  AlertsProvider({
    required AuthProvider auth,
    required DeviceProvider devices,
    required ManagerEmployeesProvider employees,
    required ManagerEmployeesService employeesService,
    required ManagerOverviewService overviewService,
    required ManagerOverviewProvider overviewProvider,
    AlertSeenStore? seenStore,
    LeaveAlertStore? leaveStore,
    LeaveAlertStore? employeeLeaveStore,
  }) : _auth = auth,
       _devices = devices,
       _employees = employees,
       _employeesService = employeesService,
       _overviewService = overviewService,
       _overviewProvider = overviewProvider,
       _seenStore = seenStore ?? AlertSeenStore(),
       _managerLeaveStore = leaveStore ?? LeaveAlertStore(),
       _employeeLeaveStore =
           employeeLeaveStore ?? LeaveAlertStore(namespace: 'employee');

  final AuthProvider _auth;
  final DeviceProvider _devices;
  final ManagerEmployeesProvider _employees;
  final ManagerEmployeesService _employeesService;
  final ManagerOverviewService _overviewService;
  final ManagerOverviewProvider _overviewProvider;
  final AlertSeenStore _seenStore;
  final LeaveAlertStore _managerLeaveStore;
  final LeaveAlertStore _employeeLeaveStore;

  LeaveAlertStore get _leaveStore =>
      _managerView ? _managerLeaveStore : _employeeLeaveStore;

  static const _pollInterval = Duration(seconds: 30);
  /// Leave inbox while Alerts is open (matches device-alert poll pace).
  static const _leavePollInterval = Duration(seconds: 30);
  /// Leave badge refresh while Alerts is in the background.
  static const _leavePollBackgroundInterval = Duration(seconds: 60);
  /// Employee leave decisions — poll LeavesStore for approve/reject changes.
  static const _employeeLeavePollInterval = Duration(seconds: 30);

  List<DeviceAlertItem> _items = const [];
  List<DeviceAlertItem> get items => _items;

  List<ManagerTeamLeaveItem> _leaveAlerts = const [];
  List<ManagerTeamLeaveItem> get leaveAlerts => _leaveAlerts;

  String? _focusLeaveKey;
  String? get focusLeaveKey => _focusLeaveKey;

  bool _loading = false;
  bool get isLoading => _loading;

  bool _managerView = false;
  bool get isManagerView => _managerView;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _actingKey;
  String? get actingKey => _actingKey;

  String? _actingLeaveKey;
  String? get actingLeaveKey => _actingLeaveKey;

  bool _started = false;
  bool _hasLoadedOnce = false;
  bool _hasLeaveSyncedOnce = false;
  bool _refreshing = false;
  bool _leaveSyncing = false;
  bool _unseenNotification = false;
  bool _alertsTabVisible = false;
  /// Manager device fan-out (1 GET per employee) waits until Alerts opens.
  bool _managerDeviceAlertsWarmed = false;
  Set<String> _knownPendingKeys = {};

  /// Non-pending cards marked seen this session stay visible until restart.
  Set<String> _keepVisibleThisSession = {};
  Timer? _pollTimer;
  Timer? _leavePollTimer;
  VoidCallback? _authListener;
  VoidCallback? _deviceListener;
  Future<void>? _emitApprovalInFlight;
  String? _observedEmployeeStatus;

  int get pendingCount =>
      _items.where((item) => item.device.isPending).length +
      _leaveAlerts.where((e) => e.isPendingInInbox).length;

  /// Any leave still waiting for approve/reject on Alerts.
  bool get hasPendingLeaveAlerts =>
      _leaveAlerts.any((e) => e.isPendingInInbox);

  /// Clock banner only — clears as soon as Alerts is viewed.
  bool get hasUnseenAlert => _unseenNotification;

  /// Alerts tab red dot: unseen notifications OR pending leave requests.
  /// Pending-leave part stays until approve/reject (not cleared by viewing).
  bool get showNavBadge => _unseenNotification || hasPendingLeaveAlerts;

  /// Nav calls this when the Alerts tab is selected / left so live reminder
  /// writes while viewing Alerts are absorbed as already seen.
  void setAlertsTabVisible(bool visible) {
    if (_alertsTabVisible == visible) {
      if (visible) markAlertsSeen();
      return;
    }
    if (visible) {
      _alertsTabVisible = true;
      markAlertsSeen();
      // First open: load per-employee devices + full leave inbox.
      _ensureManagerDeviceAlertsWarmed();
      // Fresh sync + faster poll only while Alerts is on screen.
      unawaited(syncLeaveAlerts());
      _armLeavePoll();
      return;
    }
    // Clear while still marked visible so a concurrent leftover write is
    // absorbed, then flip off so the next *new* notification can badge again.
    markAlertsSeen();
    _alertsTabVisible = false;
    _armLeavePoll();
  }

  void _ensureManagerDeviceAlertsWarmed() {
    if (!_managerView || _managerDeviceAlertsWarmed) return;
    _managerDeviceAlertsWarmed = true;
    unawaited(refresh());
    _armPoll();
  }

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
    final hadUnseen = _unseenNotification;
    _unseenNotification = false;
    if (hadUnseen) {
      notifyListeners();
    }
  }

  bool _shouldShowNonPending(String key) {
    if (_keepVisibleThisSession.contains(key)) return true;
    return !_seenStore.contains(key);
  }

  void _flagNotification() {
    // Already looking at Alerts — treat as seen; no badge when they leave.
    if (_alertsTabVisible) return;
    if (_unseenNotification) return;
    _unseenNotification = true;
    notifyListeners();
  }

  /// Reminder / smart-attendance banners — same red nav-dot as device alerts.
  void flagUnseenFromReminder() => _flagNotification();

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
      // Soft reset only — keep leave archives on disk AND in memory so an
      // in-flight sync cannot persist an emptied map over a good archive.
      reset(clearLeaveArchives: false);
      return;
    }
    final nextManager = _auth.homeTarget == AuthHomeTarget.manager;
    if (_managerView != nextManager) {
      _hasLeaveSyncedOnce = false;
      _leaveAlerts = const [];
      _focusLeaveKey = null;
      _managerDeviceAlertsWarmed = false;
    }
    _managerView = nextManager;
    // Allow a fresh sync even if a pre-auth attempt left _leaveSyncing stuck.
    _leaveSyncing = false;
    if (_managerView) {
      // Light: pending-leave badge only. Device fan-out waits for Alerts tab.
      unawaited(syncLeaveAlerts(silent: true));
      _armLeavePoll();
      if (_alertsTabVisible || _managerDeviceAlertsWarmed) {
        _ensureManagerDeviceAlertsWarmed();
      }
      return;
    }
    unawaited(refresh());
    unawaited(syncLeaveAlerts());
    _armPoll();
    _armLeavePoll();
  }

  void _onDevicesChanged() {
    if (!_auth.isAuthenticated || _managerView) return;
    unawaited(_emitEmployeeApprovalIfNeeded());
    unawaited(refresh());
  }

  void _armPoll() {
    _pollTimer?.cancel();
    // Manager: only after Alerts has been opened (avoids N device GETs at login).
    if (_managerView && !_managerDeviceAlertsWarmed) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!_auth.isAuthenticated) return;
      if (_managerView && !_managerDeviceAlertsWarmed) return;
      unawaited(refresh(silent: true));
    });
  }

  void _armLeavePoll() {
    _leavePollTimer?.cancel();
    if (!_auth.isAuthenticated) return;
    final Duration interval;
    if (_managerView) {
      interval = _alertsTabVisible
          ? _leavePollInterval
          : _leavePollBackgroundInterval;
    } else {
      interval = _employeeLeavePollInterval;
    }
    _leavePollTimer = Timer.periodic(interval, (_) {
      if (!_auth.isAuthenticated) return;
      unawaited(syncLeaveAlerts(silent: true));
    });
  }

  void focusLeave(String? key) {
    final next = key?.trim();
    if (next == null || next.isEmpty) {
      if (_focusLeaveKey == null) return;
      _focusLeaveKey = null;
      notifyListeners();
      return;
    }
    if (_focusLeaveKey == next) return;
    _focusLeaveKey = next;
    notifyListeners();
  }

  void clearLeaveFocus() {
    if (_focusLeaveKey == null) return;
    _focusLeaveKey = null;
    notifyListeners();
  }

  /// Manager: pending team leaves. Employee: own approved/rejected decisions.
  Future<void> syncLeaveAlerts({bool silent = false}) async {
    if (!_auth.isAuthenticated || _leaveSyncing) return;
    if (_managerView) {
      await _syncManagerLeaveAlerts(silent: silent);
    } else {
      await _syncEmployeeLeaveAlerts();
    }
  }

  /// Pull pending team leaves, archive forever, notify on brand-new requests.
  Future<void> _syncManagerLeaveAlerts({bool silent = false}) async {
    if (!_managerView || _leaveSyncing) return;
    _leaveSyncing = true;
    try {
      await _managerLeaveStore.load();
      // Show archived cards immediately — don't wait on network.
      _leaveAlerts = _managerLeaveStore.items;
      if (_leaveAlerts.isNotEmpty) notifyListeners();

      final dash =
          _overviewProvider.dashboard?.pendingTeamLeaves ??
          const <ManagerTeamLeaveItem>[];
      final result = await _overviewService.loadPendingTeamLeaves(
        dashboardPending: dash,
      );
      if (!_auth.isAuthenticated || !_managerView) return;
      final pending = <ManagerTeamLeaveItem>[
        ...?result.data,
        ...dash.where((e) => e.isPendingInInbox),
      ];
      await _managerLeaveStore.mergePending(pending);

      // Full open only — silent polls skip decided history to cut API load.
      if (!silent) {
        try {
          final approved =
              await _overviewService.loadTeamLeaves(status: 'approved');
          final rejected =
              await _overviewService.loadTeamLeaves(status: 'rejected');
          if (!_auth.isAuthenticated || !_managerView) return;
          if (approved.data != null && approved.data!.isNotEmpty) {
            await _managerLeaveStore.mergeDecided(
              approved.data!,
              assumeApproved: true,
            );
          }
          if (rejected.data != null && rejected.data!.isNotEmpty) {
            await _managerLeaveStore.mergeDecided(
              rejected.data!,
              assumeRejected: true,
            );
          }
        } catch (_) {
          // Archive still has whatever was persisted locally.
        }
      }

      if (!_auth.isAuthenticated || !_managerView) return;
      final merged = _managerLeaveStore.items;

      // First sync seeds the archive without flooding old pending as "new".
      if (_hasLeaveSyncedOnce) {
        for (final item in merged) {
          if (!item.isPendingInInbox) continue;
          final key = item.alertKey;
          if (_managerLeaveStore.wasNotified(key)) continue;
          await _managerLeaveStore.markNotified(key);
          _flagNotification();
          unawaited(
            AlertNotificationService.notifyManagerLeaveRequest(
              employeeName: item.employeeName ?? 'Employee',
              leaveType: item.leaveType ?? 'Leave',
              leaveId: item.id,
              leaveKey: key,
            ),
          );
        }
      } else {
        for (final item in merged) {
          if (!item.isPendingInInbox) continue;
          await _managerLeaveStore.markNotified(item.alertKey);
        }
        _hasLeaveSyncedOnce = true;
      }

      _leaveAlerts = _managerLeaveStore.items;
      notifyListeners();
    } catch (e, st) {
      AppLogger.error('AlertsProvider', 'syncLeaveAlerts', e, stackTrace: st);
    } finally {
      _leaveSyncing = false;
    }
  }

  /// Archive employee leave decisions and notify when status flips.
  Future<void> _syncEmployeeLeaveAlerts() async {
    if (_managerView || _leaveSyncing) return;
    _leaveSyncing = true;
    try {
      await _employeeLeaveStore.load();
      // Show archived cards immediately — don't wait on LeavesStore.refresh.
      _leaveAlerts = _employeeLeaveStore.items;
      if (_leaveAlerts.isNotEmpty) notifyListeners();

      // Refresh own leaves so approve/reject from the manager is picked up.
      await bindings.leavesStore.refresh();
      if (!_auth.isAuthenticated || _managerView) return;
      final user = _auth.user;
      final userId = int.tryParse(user?.id ?? '');
      final name = (user?.name ?? '').trim();
      final decided = <ManagerTeamLeaveItem>[
        for (final request in bindings.leavesStore.requests)
          if (!request.isLocal &&
              (request.status == LeaveRequestStatus.approved ||
                  request.status == LeaveRequestStatus.rejected))
            _employeeLeaveAlertFromRequest(
              request,
              employeeName: name.isEmpty ? 'You' : name,
              userId: userId,
            ),
      ];
      final merged = await _employeeLeaveStore.mergeDecided(decided);
      if (!_auth.isAuthenticated || _managerView) return;

      if (_hasLeaveSyncedOnce) {
        for (final item in merged) {
          if (item.isPendingInInbox) continue;
          final key = item.alertKey;
          // Notify once per final status (approve vs reject).
          final notifyKey =
              '$key:${item.isRejectedLeave ? 'rejected' : 'approved'}';
          if (_employeeLeaveStore.wasNotified(notifyKey)) continue;
          await _employeeLeaveStore.markNotified(notifyKey);
          _flagNotification();
          unawaited(
            AlertNotificationService.notifyEmployeeLeaveDecision(
              approved: item.countsAsOnLeave,
              leaveType: item.leaveType ?? 'Leave',
              leaveId: item.id,
              leaveKey: key,
            ),
          );
        }
      } else {
        for (final item in merged) {
          if (item.isPendingInInbox) continue;
          final key = item.alertKey;
          final notifyKey =
              '$key:${item.isRejectedLeave ? 'rejected' : 'approved'}';
          await _employeeLeaveStore.markNotified(notifyKey);
        }
        _hasLeaveSyncedOnce = true;
      }

      _leaveAlerts = _employeeLeaveStore.items;
      notifyListeners();
    } catch (e, st) {
      AppLogger.error(
        'AlertsProvider',
        'syncEmployeeLeaveAlerts',
        e,
        stackTrace: st,
      );
    } finally {
      _leaveSyncing = false;
    }
  }

  static String _fmtLeaveDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static ManagerTeamLeaveItem _employeeLeaveAlertFromRequest(
    LeaveRequest request, {
    required String employeeName,
    int? userId,
  }) {
    final approved = request.status == LeaveRequestStatus.approved;
    return ManagerTeamLeaveItem(
      id: int.tryParse(request.id),
      userId: userId,
      employeeName: employeeName,
      dateFrom: _fmtLeaveDate(request.startDate),
      dateTo: _fmtLeaveDate(request.endDate),
      status: approved ? 'approved' : 'rejected',
      statusLabel: approved ? 'Approved' : 'Rejected',
      leaveType: request.typeName,
      note: request.note,
      documentName: request.documentName,
      sourceId: request.id,
      requestedAt: request.createdAt.toIso8601String(),
    );
  }

  /// Apply a review that already succeeded elsewhere (e.g. detail sheet).
  Future<void> archiveLeaveReview(
    ManagerTeamLeaveItem item,
    String action,
  ) async {
    await _managerLeaveStore.markReviewed(key: item.alertKey, action: action);
    _leaveAlerts = _managerLeaveStore.items;
    notifyListeners();
    unawaited(syncLeaveAlerts(silent: true));
  }

  Future<bool> reviewLeaveAlert(
    ManagerTeamLeaveItem item,
    String action,
    BuildContext context,
  ) async {
    final id = item.id;
    if (id == null || _actingLeaveKey != null) return false;
    final key = item.alertKey;
    _actingLeaveKey = key;
    notifyListeners();

    final result = await _overviewService.reviewTeamLeave(
      leaveId: id,
      action: action,
    );
    if (!result.success) {
      _actingLeaveKey = null;
      if (context.mounted) {
        ToastHelper.error(
          context,
          message: result.message ?? 'Unable to $action leave',
        );
      }
      notifyListeners();
      return false;
    }

    await _managerLeaveStore.markReviewed(key: key, action: action);
    _leaveAlerts = _managerLeaveStore.items;
    _actingLeaveKey = null;
    if (context.mounted) {
      ToastHelper.success(
        context,
        message: action == 'approve' ? 'Leave approved' : 'Leave rejected',
      );
    }
    notifyListeners();
    // Refresh remote pending in background — local archive already keeps card.
    unawaited(syncLeaveAlerts(silent: true));
    return true;
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

    final before = _alertSignature();
    try {
      await _seenStore.load();
      if (_managerView) {
        await _loadManagerAlerts();
        // Keep leave inbox warm on the same cadence as devices when silent.
        unawaited(syncLeaveAlerts(silent: true));
      } else {
        await _emitEmployeeApprovalIfNeeded();
        _loadEmployeeAlerts();
      }
      _loading = false;
      _hasLoadedOnce = true;
      if (!(silent && before == _alertSignature())) {
        notifyListeners();
      }
    } catch (e, st) {
      AppLogger.error('AlertsProvider', 'refresh', e, stackTrace: st);
      _loading = false;
      _errorMessage = 'Failed to load alerts.';
      notifyListeners();
    } finally {
      _refreshing = false;
    }
  }

  String _alertSignature() {
    final items = _items
        .map(
          (item) =>
              '${item.key}:${item.device.normalizedStatus}:${item.device.isPending}',
        )
        .join(',');
    return '$_unseenNotification|$items';
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
          if ((device.isRejected || device.isApproved || device.isBlocked) &&
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
      if (context.mounted) ToastHelper.deviceDeleted(context);
    } else if (context.mounted) {
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
      if (context.mounted) {
        ToastHelper.error(
          context,
          message: result.message ?? 'Failed to update device.',
        );
      }
      notifyListeners();
      return false;
    }

    if (context.mounted) {
      if (action == 'approve') {
        ToastHelper.deviceApproved(context);
      } else {
        ToastHelper.deviceRejected(context);
      }
    }
    await refresh();
    return true;
  }

  /// Clears in-memory alert state.
  ///
  /// [clearLeaveArchives] deletes persisted leave cards from secure storage.
  /// Pass `true` only on real logout / account switch — never on the brief
  /// unauthenticated flicker during app restart (that path must NOT unload
  /// the in-memory archive either, or an in-flight sync can persist `[]`).
  void reset({bool clearLeaveArchives = true}) {
    _pollTimer?.cancel();
    _pollTimer = null;
    _leavePollTimer?.cancel();
    _leavePollTimer = null;
    _items = const [];
    // Soft path keeps leave cards in memory so UI can restore instantly and
    // in-flight persist cannot overwrite disk with an emptied map.
    if (clearLeaveArchives) {
      _leaveAlerts = const [];
    }
    _loading = false;
    _errorMessage = null;
    _actingKey = null;
    _actingLeaveKey = null;
    _focusLeaveKey = null;
    _hasLoadedOnce = false;
    if (clearLeaveArchives) {
      _hasLeaveSyncedOnce = false;
    }
    _knownPendingKeys = {};
    _keepVisibleThisSession = {};
    _unseenNotification = false;
    _alertsTabVisible = false;
    _managerDeviceAlertsWarmed = false;
    _managerView = false;
    _observedEmployeeStatus = null;
    _emitApprovalInFlight = null;
    _leaveSyncing = false;
    unawaited(_seenStore.clear());
    if (clearLeaveArchives) {
      unawaited(_managerLeaveStore.clear());
      unawaited(_employeeLeaveStore.clear());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    if (_authListener != null) _auth.removeListener(_authListener!);
    if (_deviceListener != null) _devices.removeListener(_deviceListener!);
    _pollTimer?.cancel();
    _leavePollTimer?.cancel();
    super.dispose();
  }
}
