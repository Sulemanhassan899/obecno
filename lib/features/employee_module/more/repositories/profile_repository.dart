import 'dart:convert';

import 'package:Obecno/core/api/api_client.dart';
import 'package:Obecno/core/api/api_endpoints.dart';
import 'package:Obecno/core/api/api_error.dart';
import 'package:Obecno/core/api/api_response.dart';
import 'package:Obecno/features/employee_module/more/data/models/employee_profile_model.dart';

/// Talks to every `/api/employee/profile*` endpoint. Mirrors
/// `AuthRepository`'s pattern: non-2xx status codes are already
/// normalized into an [ApiError] by [ApiClient], so this class only has
/// to unwrap the `{success, data, message}` body shape on 2xx.
class ProfileRepository {
  ProfileRepository(this._client);

  final ApiClient _client;

  Map<String, dynamic>? _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : null;

  /// 🔥 FIX: `GET /api/employee/profile` has been observed coming back
  /// double-encoded -- the raw body is `{"data": "{\"success\":true,...}"}"`,
  /// i.e. the *whole* envelope arrives as a JSON string sitting under the
  /// outer "data" key, instead of `{"success":true,"data":{...}}` directly.
  /// Depending on how far `ApiClient` got in decoding that string, what
  /// lands here as [raw] can be any of:
  ///   1. the correct envelope already: {success, message, data: {...}}
  ///   2. the buggy double-nest: {data: {success, message, data: {...}}}
  ///   3. the envelope still as a raw JSON string under "data"
  /// This unwraps all three down to case 1 so `_parseProfile` always sees
  /// a real `{success, data, message}` map, regardless of what shape the
  /// shared API client happened to hand back -- keeping the fix entirely
  /// inside this module instead of depending on `core/api` behaving a
  /// particular way.
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

    // Already the real envelope -- has its own "success" flag.
    if (map.containsKey('success')) return map;

    // Buggy nesting: the real envelope is one level down, either as a
    // Map (case 2) or still as a String (case 3 wrapped in an outer Map).
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

    // Nothing matched a known shape -- return as-is so the "Unexpected
    // response" failure below can still surface sensibly.
    return map;
  }

  /// GET /api/employee/profile -- profile fields plus the countries/
  /// cities/departments lookup lists used to populate the edit form's
  /// dropdowns.
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

  /// PUT /api/employee/profile -- [payload] is whatever subset of
  /// editable fields the form changed (e.g. `{"phone": "...", "city_id":
  /// "..."}`); the repository doesn't assume a fixed shape since the docs
  /// don't pin one down.
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

  /// POST /api/employee/profile/photo -- pass [photoBytes] + [fileName]
  /// to upload a new photo, or [removePhoto] = true (with no bytes) to
  /// clear the existing one via the `remove_photo` form field.
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
