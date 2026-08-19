import 'package:Obecno/core/api/api_client.dart';
import 'package:Obecno/core/api/api_endpoints.dart';
import 'package:Obecno/core/api/api_error.dart';
import 'package:Obecno/core/api/api_response.dart';
import 'package:Obecno/features/auth/data/models/auth_user_model.dart';
import 'package:Obecno/features/auth/data/models/permission_item_model.dart';

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Map<String, dynamic>? _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : null;

  Future<ApiResponse<bool>> checkEmail(String email) async {
    try {
      final response = await _client.post(
        ApiEndpoints.login,
        data: {'email': email},
      );
      return _parseCheckEmail(response.data, response.statusCode);
    } on ApiError catch (e) {
      return ApiResponse.failure(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }

  ApiResponse<bool> _parseCheckEmail(dynamic data, int statusCode) {
    final decoded = _asMap(data);
    if (decoded == null) {
      return ApiResponse.failure(
        'Unexpected response from server. Please try again.',
        statusCode: statusCode,
      );
    }

    final success = decoded['success'] == true;
    if (!success) {
      return ApiResponse.failure(
        (decoded['message'] as String?) ?? 'Failed to verify email.',
        statusCode: statusCode,
      );
    }

    final body = decoded['data'];
    bool exists = false;
    if (body is Map<String, dynamic>) {
      exists = body['exists'] == true;
    } else if (body is bool) {
      exists = body;
    }

    return ApiResponse.success(
      exists,
      message: decoded['message'] as String?,
      statusCode: statusCode,
    );
  }

  Future<ApiResponse<AuthUserModel>> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      final response = await _client.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password, 'remember_me': rememberMe},
      );
      return _parseUserEnvelope(
        response.data,
        response.statusCode,
        fallbackMessage: 'Login failed. Please try again.',
      );
    } on ApiError catch (e) {
      return ApiResponse.failure(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }

  Future<ApiResponse<AuthUserModel>> getCurrentUser() async {
    try {
      final response = await _client.get(
        ApiEndpoints.currentUser,
        skipAuthInterceptor: true,
      );
      return _parseUserEnvelope(
        response.data,
        response.statusCode,
        fallbackMessage: 'Failed to load current user.',
      );
    } on ApiError catch (e) {
      return ApiResponse.failure(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }

  ApiResponse<AuthUserModel> _parseUserEnvelope(
    dynamic data,
    int statusCode, {
    required String fallbackMessage,
  }) {
    final decoded = _asMap(data);
    if (decoded == null) {
      return ApiResponse.failure(
        'Unexpected response from server. Please try again.',
        statusCode: statusCode,
      );
    }

    try {
      final success = decoded['success'] == true;
      final body = decoded['data'];

      if (!success || body is! Map<String, dynamic>) {
        return ApiResponse.failure(
          (decoded['message'] as String?) ?? fallbackMessage,
          statusCode: statusCode,
        );
      }

      final user = AuthUserModel.fromJson(body);
      return ApiResponse.success(
        user,
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

  Future<ApiResponse<List<Map<String, dynamic>>>> fetchPermissions() async {
    try {
      final response = await _client.get(ApiEndpoints.perimssion);
      final decoded = _asMap(response.data);
      if (decoded == null) {
        return ApiResponse.failure(
          'Unexpected response from server. Please try again.',
          statusCode: response.statusCode,
        );
      }

      final success = decoded['success'] != false;
      if (!success) {
        return ApiResponse.failure(
          (decoded['message'] as String?) ?? 'Failed to load permissions.',
          statusCode: response.statusCode,
        );
      }

      final body = decoded['data'];
      // Prefer structured shapes (permission_items / sections) over the
      // nested policy map under `permissions`, which lacks labels/items.
      final items = PermissionItemModel.listFromEnvelope(body);
      if (items.isEmpty) {
        return ApiResponse.failure(
          'Unexpected response from server. Please try again.',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.success(
        items.map((e) => e.toJson()).toList(growable: false),
        message: decoded['message'] as String?,
        statusCode: response.statusCode,
      );
    } on ApiError catch (e) {
      return ApiResponse.failure(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }

  // ================= FORGOT PASSWORD =================
  Future<ApiResponse<void>> forgotPassword(String email) async {
    try {
      final response = await _client.post(
        ApiEndpoints.forgot,
        data: {'email': email},
      );
      final decoded = _asMap(response.data);

      return ApiResponse.success(
        null,
        message:
            decoded?['message'] as String? ??
            'Please check your email for further instructions.',
        statusCode: response.statusCode,
      );
    } on ApiError catch (e) {
      return ApiResponse.failure(
        _fieldOrGeneralMessage(e, 'email'),
        statusCode: e.statusCode,
      );
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }

  Future<ApiResponse<void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      final response = await _client.post(
        ApiEndpoints.changePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirm': newPasswordConfirmation,
        },
      );

      final decoded = _asMap(response.data);
      final success = decoded?['success'] != false;

      if (!success) {
        return ApiResponse.failure(
          (decoded?['message'] as String?) ?? 'Failed to change password.',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.success(
        null,
        message:
            decoded?['message'] as String? ?? 'Password changed successfully.',
        statusCode: response.statusCode,
      );
    } on ApiError catch (e) {
      return ApiResponse.failure(
        _changePasswordMessageFrom(e),
        statusCode: e.statusCode,
      );
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }

  String _fieldOrGeneralMessage(ApiError error, String field) {
    final fieldError = error.fieldErrors?[field];
    if (fieldError is String) return fieldError;
    if (fieldError is List && fieldError.isNotEmpty)
      return fieldError.first.toString();
    return error.message;
  }

  String _changePasswordMessageFrom(ApiError error) {
    for (final field in const [
      'current_password',
      'new_password',
      'new_password_confirm',
    ]) {
      final fieldError = error.fieldErrors?[field];
      if (fieldError is String && fieldError.isNotEmpty) return fieldError;
      if (fieldError is List && fieldError.isNotEmpty)
        return fieldError.first.toString();
    }
    return error.message;
  }
}
