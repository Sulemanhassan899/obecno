import 'dart:convert';

import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/api/employee_api_endpoints.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/core/services/logger.dart';
import 'package:obecno/features/employee_module/more/data/models/device_model.dart';

/// Result of a register-device call, distinguishing "device is newly
/// registered" from "server says this device is already registered" --
/// the two cases the login flow (Scenarios 2 & 3) must tell apart.
enum DeviceRegisterOutcome { registered, alreadyRegistered, blocked, failed }

class DeviceRegisterResult {
  const DeviceRegisterResult({
    required this.outcome,
    this.message,
    this.device,
  });

  final DeviceRegisterOutcome outcome;
  final String? message;
  final DeviceModel? device;
}

class DeviceRepository {
  DeviceRepository(this._client);

  final ApiClient _client;

  Map<String, dynamic>? _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : null;

  Map<String, dynamic>? _unwrapEnvelope(dynamic raw) {
    var current = raw;

    if (current is String) {
      final trimmed = current.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          current = jsonDecode(trimmed);
        } catch (_) {
          return null;
        }
      }
    }

    final map = _asMap(current);
    if (map == null) return null;
    if (map.containsKey('success')) return map;

    final inner = map['data'];
    if (inner is Map<String, dynamic> && inner.containsKey('success')) {
      return inner;
    }
    return map;
  }

  bool _looksAlreadyRegistered(String? message) {
    if (message == null) return false;
    final normalized = message.toLowerCase();
    return normalized.contains('already registered');
  }

  bool _looksBlocked(String? message, int? statusCode) {
    if (statusCode == 403) return true;
    if (message == null) return false;
    final normalized = message.toLowerCase();
    return normalized.contains('blocked') || normalized.contains('suspicious');
  }

  DeviceModel? _deviceFromRegisterResponse(dynamic decoded) {
    final parsed = DeviceModel.listFromEnvelope(decoded);
    if (parsed.isEmpty) return null;
    return parsed.firstWhere((d) => d.isCurrent, orElse: () => parsed.first);
  }

  /// POST /employee/devices
  ///
  /// Scenario 2 (unregistered device): server registers it and returns
  /// success -> [DeviceRegisterOutcome.registered].
  /// Scenario 3a (already registered): server returns a failure whose
  /// message says the device is already registered -> swallowed and
  /// reported as [DeviceRegisterOutcome.alreadyRegistered], never a hard
  /// failure, so the login flow is never interrupted.
  /// Scenario 3b (blocked/suspicious device, if backend supports it):
  /// a 403 or a message mentioning blocked/suspicious -> reported as
  /// [DeviceRegisterOutcome.blocked] so the UI can show a warning; this
  /// still does not throw or interrupt login itself (see
  /// DeviceProvider/login screen for why login can't be gated here without
  /// touching AuthProvider).
  Future<DeviceRegisterResult> registerDevice(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _client.post(
        EmployeeApiEndpoints.registerdevices,
        data: payload,
      );

      final decoded = _unwrapEnvelope(response.data);
      final success = decoded == null ? true : decoded['success'] != false;
      final message = decoded?['message'] as String?;

      if (success) {
        final device = _deviceFromRegisterResponse(decoded);
        AppLogger.info(
          '[DeviceRepository] POST /employee/devices succeeded '
          '(id=${device?.id ?? "none"} deviceId=${device?.deviceId ?? "none"} '
          'status=${device?.status ?? "none"})',
        );
        return DeviceRegisterResult(
          outcome: DeviceRegisterOutcome.registered,
          message: message,
          device: device,
        );
      }

      if (_looksBlocked(message, response.statusCode)) {
        AppLogger.info(
          '[DeviceRepository] POST /employee/devices blocked: $message',
        );
        return DeviceRegisterResult(
          outcome: DeviceRegisterOutcome.blocked,
          message: message,
        );
      }

      if (_looksAlreadyRegistered(message)) {
        AppLogger.info(
          '[DeviceRepository] POST /employee/devices already registered: $message',
        );
        return DeviceRegisterResult(
          outcome: DeviceRegisterOutcome.alreadyRegistered,
          message: message,
          device: _deviceFromRegisterResponse(decoded),
        );
      }

      AppLogger.info(
        '[DeviceRepository] POST /employee/devices failed: $message',
      );
      return DeviceRegisterResult(
        outcome: DeviceRegisterOutcome.failed,
        message: message ?? 'Failed to register device.',
      );
    } on ApiError catch (e) {
      if (_looksBlocked(e.message, e.statusCode)) {
        return DeviceRegisterResult(
          outcome: DeviceRegisterOutcome.blocked,
          message: e.message,
        );
      }
      if (_looksAlreadyRegistered(e.message)) {
        return DeviceRegisterResult(
          outcome: DeviceRegisterOutcome.alreadyRegistered,
          message: e.message,
        );
      }
      return DeviceRegisterResult(
        outcome: DeviceRegisterOutcome.failed,
        message: e.message,
      );
    } catch (_) {
      return const DeviceRegisterResult(
        outcome: DeviceRegisterOutcome.failed,
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  /// GET /employee/devices
  Future<ApiResponse<DeviceListResponse>> fetchLinkedDevices() async {
    try {
      final response = await _client.get(EmployeeApiEndpoints.devices);
      final decoded = _unwrapEnvelope(response.data);

      if (decoded == null) {
        return ApiResponse.failure(
          'Unexpected response from server. Please try again.',
          statusCode: response.statusCode,
        );
      }

      final success = decoded['success'] != false;
      if (!success) {
        return ApiResponse.failure(
          (decoded['message'] as String?) ?? 'Failed to load devices.',
          statusCode: response.statusCode,
        );
      }

      var devices = DeviceModel.listFromEnvelope(decoded);
      if (devices.isEmpty) {
        devices = DeviceModel.listFromEnvelope(response.data);
      }
      AppLogger.info(
        '[DeviceRepository] GET /employee/devices parsed ${devices.length} device(s)',
      );
      return ApiResponse.success(
        DeviceListResponse(devices),
        message: decoded['message'] as String?,
        statusCode: response.statusCode,
      );
    } on ApiError catch (e) {
      return ApiResponse.failure(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }

  /// DELETE /employee/devices/{id}
  /// Cancels / deletes a pending device registration request.
  ///
  /// Some backends reject HTTP DELETE (405 / connection reset) or return an
  /// empty/HTML body. Try DELETE, then POST .../delete, then a collection
  /// POST. 404 means the request is already gone.
  Future<ApiResponse<bool>> deleteDevice(
    String id, {
    String? alternateId,
  }) async {
    final ids = <String>[];
    void addId(String? value) {
      final key = value?.trim() ?? '';
      if (key.isEmpty || key == '0' || key == 'null') return;
      if (!ids.contains(key)) ids.add(key);
    }

    addId(id);
    addId(alternateId);
    if (ids.isEmpty) {
      return ApiResponse.failure('Invalid device.');
    }

    ApiResponse<bool>? lastFailure;
    for (final key in ids) {
      final result = await _deleteDeviceOnce(key);
      if (result.success) return result;
      lastFailure = result;
    }
    return lastFailure ?? ApiResponse.failure('Failed to delete device.');
  }

  Future<ApiResponse<bool>> _deleteDeviceOnce(String id) async {
    try {
      final deleted = await _client.delete(
        EmployeeApiEndpoints.deleteDevice(id),
      );
      final first = _interpretDeleteResponse(deleted);
      if (first.success) return first;
      if (!_shouldTryDeleteFallback(first, deleted.statusCode)) {
        return first;
      }
    } on ApiError catch (e) {
      AppLogger.info(
        '[DeviceRepository] DELETE /employee/devices/$id failed: '
        '${e.statusCode} ${e.message}',
      );
      if (!_isRetryableDeleteError(e)) {
        return ApiResponse.failure(e.message, statusCode: e.statusCode);
      }
    } catch (_) {
      // Fall through to POST fallbacks (DELETE is often blocked).
    }

    try {
      final posted = await _client.post(
        EmployeeApiEndpoints.deleteDeviceAction(id),
      );
      final result = _interpretDeleteResponse(posted);
      if (result.success) return result;
      if (!_shouldTryDeleteFallback(result, posted.statusCode)) {
        return result;
      }
    } on ApiError catch (e) {
      if (!_isRetryableDeleteError(e)) {
        return ApiResponse.failure(e.message, statusCode: e.statusCode);
      }
    } catch (_) {}

    try {
      final posted = await _client.post(
        EmployeeApiEndpoints.deleteDeviceCollection,
        data: {'id': id, 'device_id': id, '_method': 'DELETE'},
      );
      final result = _interpretDeleteResponse(posted);
      if (result.success) return result;
      if (posted.statusCode == 404 || result.statusCode == 404) {
        return ApiResponse.success(true, message: 'Device deleted.');
      }
      return result;
    } on ApiError catch (e) {
      if (e.statusCode == 404) {
        return ApiResponse.success(true, message: 'Device deleted.');
      }
      return ApiResponse.failure(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }

  bool _isRetryableDeleteError(ApiError e) {
    if (e.type == ApiErrorType.network || e.type == ApiErrorType.timeout) {
      return true;
    }
    final code = e.statusCode;
    return code == 404 || code == 405 || code == 501 || code == 415;
  }

  bool _shouldTryDeleteFallback(ApiResponse<bool> result, int? statusCode) {
    if (result.success) return false;
    if (statusCode == 404 || statusCode == 405 || statusCode == 501) {
      return true;
    }
    final message = (result.message ?? '').toLowerCase();
    return message.contains('unexpected') ||
        message.contains('interrupted') ||
        message.contains('not found');
  }

  ApiResponse<bool> _interpretDeleteResponse(RawApiResponse response) {
    final statusCode = response.statusCode;
    final decoded = _unwrapEnvelope(response.data);

    if (statusCode == 200 || statusCode == 201 || statusCode == 204) {
      if (decoded == null || decoded['success'] != false) {
        return ApiResponse.success(
          true,
          message: (decoded?['message'] as String?) ?? 'Device deleted.',
          statusCode: statusCode,
        );
      }
    }

    if (decoded != null && decoded['success'] == false) {
      return ApiResponse.failure(
        (decoded['message'] as String?) ?? 'Failed to delete device.',
        statusCode: statusCode,
      );
    }

    if (decoded != null && decoded['success'] == true) {
      return ApiResponse.success(
        true,
        message: (decoded['message'] as String?) ?? 'Device deleted.',
        statusCode: statusCode,
      );
    }

    if (statusCode == 404 || statusCode == 405 || statusCode == 501) {
      return ApiResponse.failure(
        (decoded?['message'] as String?) ?? 'Device not found.',
        statusCode: statusCode,
      );
    }

    return ApiResponse.failure(
      (decoded?['message'] as String?) ??
          'Unexpected response from server. Please try again.',
      statusCode: statusCode,
    );
  }
}
