import 'dart:convert';

import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/api/employee_api_endpoints.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/employee_module/more/data/models/device_model.dart';

/// Result of a register-device call, distinguishing "device is newly
/// registered" from "server says this device is already registered" --
/// the two cases the login flow (Scenarios 2 & 3) must tell apart.
enum DeviceRegisterOutcome { registered, alreadyRegistered, blocked, failed }

class DeviceRegisterResult {
  const DeviceRegisterResult({required this.outcome, this.message});

  final DeviceRegisterOutcome outcome;
  final String? message;
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
        return DeviceRegisterResult(
          outcome: DeviceRegisterOutcome.registered,
          message: message,
        );
      }

      if (_looksBlocked(message, response.statusCode)) {
        return DeviceRegisterResult(
          outcome: DeviceRegisterOutcome.blocked,
          message: message,
        );
      }

      if (_looksAlreadyRegistered(message)) {
        return DeviceRegisterResult(
          outcome: DeviceRegisterOutcome.alreadyRegistered,
          message: message,
        );
      }

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

      final body = decoded['data'] ?? decoded['devices'];
      return ApiResponse.success(
        DeviceListResponse.fromJson(body),
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
  Future<ApiResponse<bool>> deleteDevice(String id) async {
    try {
      final response = await _client.delete(
        EmployeeApiEndpoints.deleteDevice(id),
      );
      final decoded = _unwrapEnvelope(response.data);

      if (decoded == null) {
        final statusCode = response.statusCode;
        if (statusCode == 200 || statusCode == 204) {
          return ApiResponse.success(true, message: 'Device deleted.');
        }
        return ApiResponse.failure(
          'Unexpected response from server. Please try again.',
          statusCode: statusCode,
        );
      }

      final success = decoded['success'] != false;
      if (!success) {
        return ApiResponse.failure(
          (decoded['message'] as String?) ?? 'Failed to delete device.',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.success(
        true,
        message: (decoded['message'] as String?) ?? 'Device deleted.',
        statusCode: response.statusCode,
      );
    } on ApiError catch (e) {
      return ApiResponse.failure(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }
}
