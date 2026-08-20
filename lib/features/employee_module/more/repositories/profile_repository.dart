import 'dart:convert';

import 'package:obecno/core/api/api_client.dart';
import 'package:obecno/core/api/api_endpoints.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/api/api_response.dart';
import 'package:obecno/features/employee_module/more/data/models/employee_profile_model.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final ApiClient _client;

  Map<String, dynamic>? _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : null;

  Map<String, dynamic>? _unwrapEnvelope(dynamic raw) {
    var current = raw;

    // Follow a value that's a JSON-encoded string down to the object it
    // represents (handles case 3, and any depth of double-encoding).
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
    if (inner is String) {
      final trimmed = inner.trim();
      if (trimmed.startsWith('{')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {
          // fall through
        }
      }
    }

    return map;
  }

  Future<ApiResponse<EmployeeProfileModel>> getProfile() async {
    try {
      final response = await _client.get(ApiEndpoints.employeeProfile);
      return _parseProfile(
        response.data,
        response.statusCode,
        fallbackMessage: 'Failed to load profile.',
      );
    } on ApiError catch (e) {
      return ApiResponse.failure(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }

  Future<ApiResponse<EmployeeProfileModel>> updateProfile(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _client.put(
        ApiEndpoints.employeeProfile,
        data: payload,
      );
      return _parseProfile(
        response.data,
        response.statusCode,
        fallbackMessage: 'Failed to update profile.',
      );
    } on ApiError catch (e) {
      return ApiResponse.failure(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }

  Future<ApiResponse<EmployeeProfileModel>> updatePhoto({
    List<int>? photoBytes,
    String? fileName,
    bool removePhoto = false,
  }) async {
    try {
      final response = await _client.postMultipart(
        ApiEndpoints.employeeProfilePhoto,
        fields: removePhoto ? {'remove_photo': '1'} : null,
        fileFieldName: photoBytes != null ? 'photo' : null,
        fileBytes: photoBytes,
        fileName: fileName,
      );
      return _parseProfile(
        response.data,
        response.statusCode,
        fallbackMessage: 'Failed to update photo.',
      );
    } on ApiError catch (e) {
      return ApiResponse.failure(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }

  ApiResponse<EmployeeProfileModel> _parseProfile(
    dynamic data,
    int statusCode, {
    required String fallbackMessage,
  }) {
    final decoded = _unwrapEnvelope(data);
    if (decoded == null) {
      return ApiResponse.failure(
        'Unexpected response from server. Please try again.',
        statusCode: statusCode,
      );
    }

    try {
      final success = decoded['success'] != false;
      final body = decoded['data'];

      if (!success || body is! Map<String, dynamic>) {
        return ApiResponse.failure(
          (decoded['message'] as String?) ?? fallbackMessage,
          statusCode: statusCode,
        );
      }

      return ApiResponse.success(
        EmployeeProfileModel.fromJson(body),
        message: decoded['message'] as String?,
        statusCode: statusCode,
      );
    } catch (_) {
      return ApiResponse.failure(
        'Failed to read server response. Please try again.',
        statusCode: statusCode,
      );
    }
  }
}
