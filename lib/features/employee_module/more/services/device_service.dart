import 'dart:async';

import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/employee_module/more/data/models/device_model.dart';
import 'package:obecno/features/employee_module/more/repositories/device_repository.dart';
import 'package:obecno/features/employee_module/more/services/device_info_service.dart';

class DeviceService {
  DeviceService(this._repository, this._deviceInfoService);

  final DeviceRepository _repository;
  final DeviceInfoService _deviceInfoService;

  static const int _registerRetryAttempts = 2;
  static const Duration _registerRetryDelay = Duration(seconds: 1);

  Future<DeviceInfoSnapshot> currentDeviceInfo({bool forceRefresh = false}) {
    return _deviceInfoService.collect(forceRefresh: forceRefresh);
  }

  Map<String, dynamic> _buildPayload(DeviceInfoSnapshot info) {
    return {
      // Required by spec
      'device_name': DeviceDisplayName.resolve(
        name: info.deviceName,
        model: info.model,
        manufacturer: info.manufacturer,
        platform: info.platform,
        os: info.os,
      ),
      'device_details': info.deviceDetails,
      'mac_address': info.macAddress,
      // Extended
      'device_id': info.deviceId,
      'model': info.model,
      'manufacturer': info.manufacturer,
      'os': info.os,
      'os_version': info.osVersion,
      'sdk_version': info.sdkVersion,
      'platform': info.platform,
      'app_version': info.appVersion,
      'timezone': info.timezone,
      if (info.uptimeSeconds != null) 'uptime_seconds': info.uptimeSeconds,
    };
  }

  /// Registers the current device. Used both right after login (Scenario 2)
  /// and from the Linked Devices screen if the user wants to re-register.
  ///
  /// Retries on transient failures only: a `blocked` or `alreadyRegistered`
  /// outcome is a real answer from the backend and is returned immediately,
  /// never retried.
  Future<DeviceRegisterResult> registerCurrentDevice() async {
    final info = await _deviceInfoService.collect();
    final payload = _buildPayload(info);

    DeviceRegisterResult result = await _repository.registerDevice(payload);

    var attempt = 0;
    while (result.outcome == DeviceRegisterOutcome.failed &&
        attempt < _registerRetryAttempts) {
      attempt++;
      AppLogger.info(
        '[DeviceService] registerCurrentDevice retry $attempt/$_registerRetryAttempts '
        'after failure: ${result.message}',
      );
      await Future.delayed(_registerRetryDelay);
      result = await _repository.registerDevice(payload);
    }

    return _withFallbackDevice(result, info);
  }

  DeviceRegisterResult _withFallbackDevice(
    DeviceRegisterResult result,
    DeviceInfoSnapshot info,
  ) {
    if (result.device != null) return result;
    if (result.outcome != DeviceRegisterOutcome.registered &&
        result.outcome != DeviceRegisterOutcome.alreadyRegistered) {
      return result;
    }
    return DeviceRegisterResult(
      outcome: result.outcome,
      message: result.message,
      device: pendingDeviceFrom(info),
    );
  }

  DeviceModel pendingDeviceFrom(
    DeviceInfoSnapshot info, {
    DeviceModel? registered,
  }) {
    final name = DeviceDisplayName.resolve(
      name: registered?.name.isNotEmpty == true
          ? registered!.name
          : info.deviceName,
      model: info.model,
      manufacturer: info.manufacturer,
      platform: info.platform,
      os: info.os,
    );

    return DeviceModel(
      id: registered?.id ?? '',
      deviceId: info.deviceId,
      name: name,
      model: info.model,
      manufacturer: info.manufacturer,
      os: info.os,
      osVersion: info.osVersion,
      appVersion: info.appVersion,
      ipAddress: registered?.ipAddress ?? '',
      timezone: info.timezone,
      platform: info.platform,
      lastActive: registered?.lastActive,
      requestedAt: registered?.requestedAt ?? DateTime.now(),
      status: (registered?.status.isNotEmpty ?? false)
          ? registered!.status
          : 'pending',
      isCurrent: true,
      approvedFlag: registered?.approvedFlag ?? false,
      actionedBy: registered?.actionedBy,
    );
  }

  Future<ApiResponse<DeviceListResponse>> fetchLinkedDevices() {
    return _repository.fetchLinkedDevices();
  }

  Future<ApiResponse<bool>> deleteDevice(String id, {String? alternateId}) {
    return _repository.deleteDevice(id, alternateId: alternateId);
  }

  Future<String> currentDeviceId() async {
    final info = await _deviceInfoService.collect();
    return info.deviceId;
  }
}
