import 'dart:async';

import 'package:flutter/material.dart';
import 'package:Obecno/core/api/base_provider.dart';
import 'package:Obecno/core/services/logger.dart';
import 'package:Obecno/features/employee_module/more/data/models/device_model.dart';
import 'package:Obecno/features/employee_module/more/repositories/device_repository.dart';
import 'package:Obecno/features/employee_module/more/services/device_cache_service.dart';
import 'package:Obecno/features/employee_module/more/services/device_service.dart';
import 'package:Obecno/core/monitors/device_approval_guard.dart';

enum LoginDeviceCheck {
  registeredSilently,
  newlyRegistered,
  blocked,
  checkFailed,
}

class DeviceProvider extends BaseProvider {
  DeviceProvider(this._service, this._cache);

  final DeviceService _service;
  final DeviceCacheService _cache;

  List<DeviceModel> _devices = const [];
  List<DeviceModel> get devices => _devices;

  DeviceModel? _currentDevice;
  DeviceModel? get currentDevice => _currentDevice;

  bool get hasDevices => _devices.isNotEmpty;

  bool _isRegistering = false;
  bool get isRegistering => _isRegistering;

  bool _deviceApproved = false;
  bool _deviceBlocked = false;
  bool _statusValidated = false;
  bool _isFetchingDevices = false;
  Completer<bool>? _fetchDevicesCompleter;

  // Which status ('approved' | 'pending' | 'blocked') was last derived from
  // the server. checkDeviceStatus() uses this only to decide whether a
  // *business* action (re-registering after a block) should fire on a
  // genuine transition -- NOT to decide whether to show UI. Whether the
  // toast/dialog for a given status has already been shown is now tracked
  // entirely inside DeviceApprovalGuard, which is the single place that
  // owns UI side-effect bookkeeping; this provider no longer duplicates it.
  String? _lastKnownStatus;

  bool _isShowingCachedDevices = false;
  bool get isShowingCachedDevices => _isShowingCachedDevices;

  bool get isDeviceApproved => _deviceApproved;
  bool get isDeviceBlocked => _deviceBlocked;

  Future<bool> fetchDevices() async {
    if (_isFetchingDevices) {
      AppLogger.info(
        '[DeviceProvider] fetchDevices already in flight -- awaiting its result instead of skipping.',
      );
      return _fetchDevicesCompleter?.future ?? false;
    }

    _isFetchingDevices = true;
    final completer = Completer<bool>();
    _fetchDevicesCompleter = completer;

    try {
      final result = await _fetchDevicesOnce();
      completer.complete(result);
      return result;
    } catch (e) {
      completer.complete(false);
      rethrow;
    } finally {
      _isFetchingDevices = false;
      _fetchDevicesCompleter = null;
    }
  }

  Future<bool> _fetchDevicesOnce() async {
    final currentDeviceInfo = await _service.currentDeviceInfo();
    final currentId = currentDeviceInfo.deviceId;
    _currentDevice = DeviceModel(
      id: '',
      deviceId: currentDeviceInfo.deviceId,
      name: currentDeviceInfo.deviceName,
      model: currentDeviceInfo.model,
      manufacturer: currentDeviceInfo.manufacturer,
      os: currentDeviceInfo.os,
      osVersion: currentDeviceInfo.osVersion,
      appVersion: currentDeviceInfo.appVersion,
      ipAddress: '',
      timezone: currentDeviceInfo.timezone,
      platform: currentDeviceInfo.platform,
      isCurrent: true,
    );

    final ok = await safeCall<DeviceListResponse>(
      operationKey: 'devices_fetch',
      request: (_) => _service.fetchLinkedDevices(),
      onSuccess: (data) {
        _devices = data.devices
            .map((d) => d.markCurrent(currentId))
            .toList(growable: false);
        _isShowingCachedDevices = false;
        final currentDeviceInList = _devices.firstWhere(
          (d) => d.isCurrent,
          orElse: () => _currentDevice!,
        );
        _currentDevice = currentDeviceInList;
      },
    );

    if (ok) {
      _deviceApproved = _devices.any((d) => d.isCurrent && d.isApproved);
      _deviceBlocked = _devices.any(
        (d) => d.isCurrent && (d.isBlocked || d.isRejected),
      );

      unawaited(_cache.cacheDevices(_devices));
      return true;
    }

    final cached = await _cache.getCachedDevices();
    if (cached.isNotEmpty) {
      _devices = cached
          .map((d) => d.markCurrent(currentId))
          .toList(growable: false);
      _isShowingCachedDevices = true;
      final currentDeviceInList = _devices.firstWhere(
        (d) => d.isCurrent,
        orElse: () => _currentDevice!,
      );
      _currentDevice = currentDeviceInList;
      _deviceApproved = _devices.any((d) => d.isCurrent && d.isApproved);
      _deviceBlocked = _devices.any(
        (d) => d.isCurrent && (d.isBlocked || d.isRejected),
      );
      setSuccess();
      AppLogger.info(
        '[DeviceProvider] devices_fetch failed, showing ${cached.length} cached device(s).',
      );
      return true;
    }

    return false;
  }

  Future<bool> refreshDeviceApprovalState() async {
    resetDeviceApprovalAlerts();
    return fetchDevices();
  }

  Future<bool> refreshDevices() => fetchDevices();

  Future<bool> registerDevice() async {
    _isRegistering = true;
    notifyListeners();
    try {
      final result = await _service.registerCurrentDevice();
      final ok =
          result.outcome == DeviceRegisterOutcome.registered ||
          result.outcome == DeviceRegisterOutcome.alreadyRegistered;
      if (!ok) {
        setError(result.message ?? 'Failed to register device.');
      } else {
        setSuccess();
        await fetchDevices();
      }
      return ok;
    } finally {
      _isRegistering = false;
      notifyListeners();
    }
  }

  Future<LoginDeviceCheck> registerOnLogin() async {
    try {
      final result = await _service.registerCurrentDevice();
      switch (result.outcome) {
        case DeviceRegisterOutcome.registered:
          _deviceApproved = false;
          _deviceBlocked = false;
          _statusValidated = true;
          return LoginDeviceCheck.newlyRegistered;
        case DeviceRegisterOutcome.alreadyRegistered:
          _deviceApproved = false;
          _deviceBlocked = false;
          _statusValidated = true;
          return LoginDeviceCheck.registeredSilently;
        case DeviceRegisterOutcome.blocked:
          _deviceBlocked = true;
          _statusValidated = true;
          return LoginDeviceCheck.blocked;
        case DeviceRegisterOutcome.failed:
          return LoginDeviceCheck.checkFailed;
      }
    } catch (e, st) {
      AppLogger.error('DeviceProvider', 'registerOnLogin', e, stackTrace: st);
      return LoginDeviceCheck.checkFailed;
    }
  }

  /// Re-derives device status from the server and hands the result to
  /// [DeviceApprovalGuard], which owns all of the actual toast/dialog/
  /// navigation work. `context` is passed through as-is -- it is only ever
  /// used by the guard as a *preferred* context (see
  /// `DeviceApprovalGuard._safeContext`), with a root-navigator fallback
  /// baked in, so it is always safe to call this from a background flow
  /// whose originating screen may already be gone.
  ///
  /// `source` / `userId` / `isFirstLogin` are for the [DEVICE_CHECK] debug
  /// log only -- callers that don't have that context (e.g. tests) can omit
  /// them and still get correct behavior, just a less detailed log line.
  Future<bool> checkDeviceStatus(
    BuildContext? context, {
    bool loginMessage = false,
    String source = 'UNKNOWN',
    String? userId,
    bool isFirstLogin = false,
  }) async {
    final ok = await fetchDevices();

    // Scenario 6: current device is approved ONLY when status == approved.
    // Pending / request-already-sent / not-in-list → treat as UNREGISTERED.
    DeviceModel? current;
    for (final d in _devices) {
      if (d.isCurrent) {
        current = d;
        break;
      }
    }
    current ??= _currentDevice;

    final approved = ok && current != null && current.isApproved;
    final blocked =
        ok && current != null && (current.isBlocked || current.isRejected);
    final pending = ok && current != null && current.isPending;

    _deviceApproved = approved;
    _deviceBlocked = blocked;

    final statusForLog = approved
        ? 'APPROVED'
        : (blocked
              ? 'BLOCKED'
              : (pending ? 'PENDING_AS_UNREGISTERED' : 'UNREGISTERED'));
    AppLogger.info(
      '[DEVICE_CHECK]\n'
      'userId=${userId ?? "unknown"}\n'
      'deviceId=${_currentDevice?.deviceId ?? current?.deviceId ?? "unknown"}\n'
      'status=$statusForLog\n'
      'source=$source\n'
      'isFirstLogin=$isFirstLogin\n'
      'isBackgroundCheck=${source == "BACKGROUND"}\n'
      'isAppStart=${source == "APP_START"}\n'
      'timestamp=${DateTime.now().toIso8601String()}',
    );

    if (approved) {
      AppLogger.info('[DeviceProvider] checkDeviceStatus: approved');
      _lastKnownStatus = 'approved';
      DeviceApprovalGuard.handle(
        context: context,
        status: DeviceApprovalStatus.approved,
      );
      return true;
    }

    final statusKey = blocked ? 'blocked' : 'pending';
    final justBecameBlocked =
        statusKey == 'blocked' && _lastKnownStatus != 'blocked';
    _lastKnownStatus = statusKey;

    if (blocked) {
      AppLogger.info(
        '[DeviceProvider] checkDeviceStatus: blocked (justBecameBlocked=$justBecameBlocked)',
      );
      if (justBecameBlocked) {
        unawaited(_reregisterAfterBlock());
      }
      DeviceApprovalGuard.handle(
        context: context,
        status: DeviceApprovalStatus.blocked,
        isRejected: current.isRejected,
      );
      return false;
    }

    // Pending OR missing from list → same UX as unregistered until approved.
    AppLogger.info(
      '[DeviceProvider] checkDeviceStatus: '
      '${pending ? "pending" : "unregistered"} → unregistered alert '
      '(loginMessage=$loginMessage)',
    );
    // Ensure toast/dialog can fire again on every login / app reopen.
    DeviceApprovalGuard.reset();
    DeviceApprovalGuard.handle(
      context: context,
      status: DeviceApprovalStatus.unregistered,
      loginMessage: true,
    );
    return true;
  }

  Future<void> _reregisterAfterBlock() async {
    try {
      final result = await _service.registerCurrentDevice();
      AppLogger.info(
        '[DeviceProvider] re-registration after block: ${result.outcome}',
      );
    } catch (e, st) {
      AppLogger.error(
        'DeviceProvider',
        '_reregisterAfterBlock',
        e,
        stackTrace: st,
      );
    }
  }

  /// Forces the next `checkDeviceStatus` alert to show again even if the
  /// status hasn't changed (used by DeviceBlockedScreen's manual "Try
  /// again" so a still-blocked result re-alerts rather than staying silent).
  void resetDeviceApprovalAlerts() {
    _lastKnownStatus = null;
    DeviceApprovalGuard.reset();
  }

  Future<void> clearLocalState() async {
    _devices = const [];
    _currentDevice = null;
    _isShowingCachedDevices = false;
    _deviceApproved = false;
    _deviceBlocked = false;
    _statusValidated = false;
    _lastKnownStatus = null;
    DeviceApprovalGuard.reset();
    await _cache.clearCache();
  }

  /// DELETE /employee/devices/{id} — cancel a pending device request / unlink.
  Future<bool> deleteDevice(String deviceId) async {
    if (deviceId.isEmpty) {
      setError('Invalid device.');
      return false;
    }

    final ok = await safeCall<bool>(
      operationKey: 'devices_delete_$deviceId',
      request: (_) => _service.deleteDevice(deviceId),
      onSuccess: (_) {
        _devices = _devices
            .where((d) => d.id != deviceId)
            .toList(growable: false);
        if (_currentDevice?.id == deviceId) {
          _currentDevice = null;
        }
        unawaited(_cache.cacheDevices(_devices));
      },
    );

    return ok;
  }
}