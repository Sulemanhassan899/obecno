import 'dart:async';

import 'package:flutter/material.dart';
import 'package:obecno/core/api/base_provider.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/employee_module/more/data/models/device_model.dart';
import 'package:obecno/features/employee_module/more/repositories/device_repository.dart';
import 'package:obecno/features/employee_module/more/services/device_cache_service.dart';
import 'package:obecno/features/employee_module/more/services/device_service.dart';
import 'package:obecno/core/monitors/device_approval_guard.dart';

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
  List<DeviceModel> get devices => DeviceModel.currentFirst(_devices);

  DeviceModel? _currentDevice;
  DeviceModel? get currentDevice => _currentDevice;

  bool get hasDevices => _devices.isNotEmpty;

  bool _isRegistering = false;
  bool get isRegistering => _isRegistering;

  bool _deviceApproved = false;
  bool _deviceBlocked = false;
  bool _statusValidated = false;
  bool _isFetchingDevices = false;
  bool _currentListedByServer = true;
  Completer<bool>? _fetchDevicesCompleter;

  // Last derived status ('approved' | 'pending' | 'blocked'). Used to detect
  // a manager block even when GET omits the current device.
  String? _lastKnownStatus;

  bool _isShowingCachedDevices = false;
  bool get isShowingCachedDevices => _isShowingCachedDevices;

  DeviceModel? _registeredFallback;
  Completer<DeviceRegisterResult>? _registerCompleter;

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
        _devices = data.devices.map((d) {
          var marked = d.markCurrent(currentId);
          if (marked.requestedAt == null && marked.lastActive == null) {
            marked = marked.withTimestamps(requestedAt: DateTime.now());
          }
          return marked;
        }).toList(growable: false);
        _isShowingCachedDevices = false;
        _currentListedByServer = _devices.any((d) => d.isCurrent);
        _mergeRegisteredFallback(currentId);
        _syncCurrentDevice(currentId);
        _syncApprovalFromList(fetchSucceeded: true);
      },
    );

    if (ok) {
      unawaited(_cache.cacheDevices(_devices));
      return true;
    }

    final cached = await _cache.getCachedDevices();
    if (cached.isNotEmpty) {
      _devices = cached
          .map((d) => d.markCurrent(currentId))
          .toList(growable: false);
      _isShowingCachedDevices = true;
      _currentListedByServer = true;
      _mergeRegisteredFallback(currentId);
      _syncCurrentDevice(currentId);
      _syncApprovalFromList(fetchSucceeded: true);
      setSuccess();
      AppLogger.info(
        '[DeviceProvider] devices_fetch failed, showing ${cached.length} cached device(s).',
      );
      return true;
    }

    _mergeRegisteredFallback(currentId);
    if (_devices.isNotEmpty) {
      _syncCurrentDevice(currentId);
      _syncApprovalFromList(fetchSucceeded: true);
      setSuccess();
      return true;
    }

    return false;
  }

  DeviceModel? get _listedCurrent {
    for (final d in _devices) {
      if (d.isCurrent) return d;
    }
    return null;
  }

  void _syncCurrentDevice(String currentId) {
    final listed = _listedCurrent;
    if (listed != null) {
      _currentDevice = listed;
      return;
    }
    if (_currentDevice == null) return;
    if (currentId.isNotEmpty && _currentDevice!.deviceId != currentId) {
      return;
    }
  }

  /// Keep fetchDevices and checkDeviceStatus on the same approved/blocked
  /// flags so AppGuard cannot send the user to /device_blocked while
  /// DeviceBlockedScreen immediately sends them home (the 10s bounce).
  void _syncApprovalFromList({required bool fetchSucceeded}) {
    if (!fetchSucceeded) return;
    final listedCurrent = _listedCurrent;
    // Only treat a missing row as a manager-block if THIS phone is not in
    // the list at all. Using the pre-merge `_currentListedByServer` flag
    // false-positived whenever the backend id didn't match, even when the
    // Linked Devices card for this phone was Active.
    final vanishedAfterApproval =
        !_isShowingCachedDevices &&
        _lastKnownStatus == 'approved' &&
        listedCurrent == null;
    _deviceApproved =
        listedCurrent != null &&
        listedCurrent.isApproved &&
        !vanishedAfterApproval;
    _deviceBlocked =
        (listedCurrent != null &&
            (listedCurrent.isBlocked || listedCurrent.isRejected)) ||
        vanishedAfterApproval;
  }

  void _mergeRegisteredFallback(String currentId) {
    final fallback = _registeredFallback;
    if (fallback == null) return;

    final alreadyListed = _devices.any((d) {
      if (d.isCurrent) return true;
      if (currentId.isNotEmpty && d.deviceId == currentId) return true;
      if (fallback.deviceId.isNotEmpty && d.deviceId == fallback.deviceId) {
        return true;
      }
      if (fallback.id.isNotEmpty && d.id == fallback.id) return true;
      return false;
    });
    if (alreadyListed) {
      _devices = _devices.map((d) {
        final isMatch =
            d.isCurrent ||
            (currentId.isNotEmpty && d.deviceId == currentId) ||
            (fallback.deviceId.isNotEmpty && d.deviceId == fallback.deviceId) ||
            (fallback.id.isNotEmpty && d.id == fallback.id);
        if (!isMatch) return d;
        var updated = d.markCurrent(currentId);
        if (updated.requestedAt == null && fallback.requestedAt != null) {
          updated = updated.withTimestamps(requestedAt: fallback.requestedAt);
        }
        if (updated.requestedAt == null && updated.lastActive == null) {
          updated = updated.withTimestamps(requestedAt: DateTime.now());
        }
        return updated;
      }).toList(growable: false);
      if (_devices.any((d) => d.isCurrent)) {
        _currentDevice = _devices.firstWhere((d) => d.isCurrent);
      }
      return;
    }

    if (_devices.length == 1) {
      final only = _devices.first;
      _devices = [
        only.markCurrent(only.deviceId.isNotEmpty ? only.deviceId : currentId),
      ];
      if (!_devices.first.isCurrent) {
        _devices = [
          DeviceModel(
            id: only.id,
            deviceId: only.deviceId.isNotEmpty ? only.deviceId : currentId,
            name: only.name,
            model: only.model,
            manufacturer: only.manufacturer,
            os: only.os,
            osVersion: only.osVersion,
            appVersion: only.appVersion,
            ipAddress: only.ipAddress,
            timezone: only.timezone,
            platform: only.platform,
            lastActive: only.lastActive,
            requestedAt: only.requestedAt,
            status: only.status.isNotEmpty ? only.status : 'pending',
            isCurrent: true,
            approvedFlag: only.approvedFlag,
            actionedBy: only.actionedBy,
            actionedById: only.actionedById,
          ),
        ];
      }
      _currentDevice = _devices.first;
      return;
    }

    final merged = fallback.markCurrent(
      currentId.isNotEmpty ? currentId : fallback.deviceId,
    );
    _devices = [merged, ..._devices];
    _currentDevice = merged;
    AppLogger.info(
      '[DeviceProvider] GET list missed current device -- showing registered '
      'request (${merged.displayName}, status=${merged.statusLabel})',
    );
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
      final result = await _registerOnce();
      final ok =
          result.outcome == DeviceRegisterOutcome.registered ||
          result.outcome == DeviceRegisterOutcome.alreadyRegistered;
      if (!ok) {
        setError(result.message ?? 'Failed to register device.');
      } else {
        _rememberRegisteredDevice(result.device);
        setSuccess();
        await fetchDevices();
      }
      return ok;
    } finally {
      _isRegistering = false;
      notifyListeners();
    }
  }

  /// Linked Devices screen: fetch the list, and if this phone is still
  /// missing, POST a registration request then reload so the pending card
  /// is visible.
  Future<bool> loadLinkedDevices() async {
    await fetchDevices();
    final hasCurrent = _devices.any((d) => d.isCurrent);
    if (hasCurrent) return true;

    AppLogger.info(
      '[DeviceProvider] Linked Devices: current device not in list -- sending register request',
    );
    final result = await _registerOnce();
    final ok =
        result.outcome == DeviceRegisterOutcome.registered ||
        result.outcome == DeviceRegisterOutcome.alreadyRegistered;
    if (ok) {
      _rememberRegisteredDevice(result.device);
    } else {
      AppLogger.info(
        '[DeviceProvider] Linked Devices: register failed (${result.message})',
      );
    }
    await fetchDevices();
    return hasDevices;
  }

  Future<DeviceRegisterResult> _registerOnce() async {
    if (_registerCompleter != null) {
      return _registerCompleter!.future;
    }
    final completer = Completer<DeviceRegisterResult>();
    _registerCompleter = completer;
    try {
      final result = await _service.registerCurrentDevice();
      AppLogger.info(
        '[DeviceProvider] registerCurrentDevice outcome=${result.outcome} '
        'message=${result.message ?? ""} '
        'deviceId=${result.device?.deviceId ?? ""}',
      );
      completer.complete(result);
      return result;
    } catch (e, st) {
      AppLogger.error('DeviceProvider', '_registerOnce', e, stackTrace: st);
      const failed = DeviceRegisterResult(
        outcome: DeviceRegisterOutcome.failed,
        message: 'Something went wrong. Please try again.',
      );
      completer.complete(failed);
      return failed;
    } finally {
      _registerCompleter = null;
    }
  }

  void _rememberRegisteredDevice(DeviceModel? device) {
    if (device == null) return;
    _registeredFallback = device;
  }

  Future<LoginDeviceCheck> registerOnLogin() async {
    try {
      final result = await _registerOnce();
      switch (result.outcome) {
        case DeviceRegisterOutcome.registered:
          _deviceApproved = false;
          _deviceBlocked = false;
          _statusValidated = true;
          _rememberRegisteredDevice(result.device);
          return LoginDeviceCheck.newlyRegistered;
        case DeviceRegisterOutcome.alreadyRegistered:
          _deviceApproved = false;
          _deviceBlocked = false;
          _statusValidated = true;
          _rememberRegisteredDevice(result.device);
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
    // [context] is retained for call-site API compatibility. After the await
    // below we must not reuse it across the async gap; DeviceApprovalGuard
    // already falls back to [rootNavigatorKey] when context is null.
    final ok = await fetchDevices();

    // Scenario 6: current device is approved ONLY when status == approved.
    // Pending / request-already-sent / not-in-list → treat as UNREGISTERED.
    // If GET omits a device that was approved (common after a manager
    // block), treat it as blocked so the employee is kicked immediately.
    // Flags were already derived in fetchDevices via `_syncApprovalFromList`
    // so this poll cannot disagree with DeviceBlockedScreen's refresh.
    final listedCurrent = _listedCurrent;
    final current = listedCurrent ?? _currentDevice;
    final approved = ok && _deviceApproved;
    final blocked = ok && _deviceBlocked;
    final pending = ok && listedCurrent != null && listedCurrent.isPending;

    notifyListeners();

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
        context: null,
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
      DeviceApprovalGuard.handle(
        context: null,
        status: DeviceApprovalStatus.blocked,
        isRejected: current?.isRejected ?? false,
      );
      return false;
    }

    // Background polls exist to catch a manager *block*, not to re-toast
    // "unregistered" every 10s while the user is already in the app.
    if (source == 'BACKGROUND') {
      AppLogger.info(
        '[DeviceProvider] checkDeviceStatus: '
        '${pending ? "pending" : "unregistered"} (background, no alert)',
      );
      return true;
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
      context: null,
      status: DeviceApprovalStatus.unregistered,
      loginMessage: true,
    );
    return true;
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
    _currentListedByServer = true;
    _registeredFallback = null;
    DeviceApprovalGuard.reset();
    await _cache.clearCache();
  }

  /// DELETE /employee/devices/{id} — cancel a pending device request / unlink.
  Future<bool> deleteDevice(DeviceModel device) async {
    final primary = _usableDeviceKey(device.id);
    final secondary = _usableDeviceKey(device.deviceId);

    if (primary.isEmpty && secondary.isEmpty) {
      _removeLocalDevice(device);
      setSuccess();
      return true;
    }

    try {
      final result = await _service.deleteDevice(
        primary.isNotEmpty ? primary : secondary,
        alternateId: secondary != primary ? secondary : null,
      );
      if (result.success) {
        _removeLocalDevice(device);
        setSuccess();
        return true;
      }
      setError(result.message ?? 'Failed to delete device.');
      return false;
    } catch (e, st) {
      AppLogger.error('DeviceProvider', 'deleteDevice', e, stackTrace: st);
      setError('Failed to delete device.');
      return false;
    }
  }

  String _usableDeviceKey(String value) {
    final key = value.trim();
    if (key.isEmpty || key == '0' || key == 'null') return '';
    return key;
  }

  void _removeLocalDevice(DeviceModel device) {
    bool same(DeviceModel other) {
      if (device.id.isNotEmpty && other.id == device.id) return true;
      if (device.deviceId.isNotEmpty && other.deviceId == device.deviceId) {
        return true;
      }
      return false;
    }

    _devices = _devices.where((d) => !same(d)).toList(growable: false);
    if (_currentDevice != null && same(_currentDevice!)) {
      DeviceModel? next;
      for (final d in _devices) {
        if (d.isCurrent) {
          next = d;
          break;
        }
      }
      _currentDevice = next;
    }
    if (_registeredFallback != null && same(_registeredFallback!)) {
      _registeredFallback = null;
    }
    unawaited(_cache.cacheDevices(_devices));
  }
}
