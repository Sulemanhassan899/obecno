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
      'device_name': info.deviceName,
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

    return result;
  }

  Future<ApiResponse<DeviceListResponse>> fetchLinkedDevices() {
    return _repository.fetchLinkedDevices();
  }

  Future<ApiResponse<bool>> deleteDevice(String id) {
    return _repository.deleteDevice(id);
  }

  Future<String> currentDeviceId() async {
    final info = await _deviceInfoService.collect();
    return info.deviceId;
  }
}
