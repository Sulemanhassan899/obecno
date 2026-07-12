import 'dart:convert';

import 'package:Obecno/api/api.dart';
import 'package:Obecno/api/api_endpoints.dart';
import 'package:Obecno/api/api_response.dart';
import 'package:Obecno/model/auth_user_model.dart';

/// Owns the single-step login call for the auth module.
///
/// Kept intentionally separate from `api/base_repository.dart` (Dio-typed:
/// its `getRequest`/`postRequest` return `Response<dynamic>` from
/// `package:dio` under the hood via the Dio `ApiClient`), since this
/// module talks to `HttpApiClient` (`api/api.dart`) instead. The public
/// contract -- take a request, return an `ApiResponse<T>` -- is identical,
/// so `AuthProvider` doesn't need to know or care which transport is
/// behind it.
class AuthRepository {
  AuthRepository(this._client);

  final HttpApiClient _client;

  /// POSTs email + password to [ApiEndpoints.login] in a single request.
  /// The session cookie itself is captured by [HttpApiClient] from the
  /// response headers; this method only worries about the response body.
  Future<ApiResponse<AuthUserModel>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post(ApiEndpoints.login, {
        'email': email,
        'password': password,
      });

      return _handleResponse(response.statusCode, response.body);
    } on HttpApiClientException catch (e) {
      return ApiResponse.failure(e.message);
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }

  ApiResponse<AuthUserModel> _handleResponse(int statusCode, String rawBody) {
    switch (statusCode) {
      case 200:
        return _parseSuccess(rawBody, statusCode);
      case 400:
        return ApiResponse.failure(
          _messageFrom(rawBody) ??
              'Please check your email and password and try again.',
          statusCode: statusCode,
        );
      case 401:
        return ApiResponse.failure(
          _messageFrom(rawBody) ?? 'Invalid email or password.',
          statusCode: statusCode,
        );
      case 500:
        return ApiResponse.failure(
          'Server error. Please try again shortly.',
          statusCode: statusCode,
        );
      default:
        return ApiResponse.failure(
          _messageFrom(rawBody) ?? 'Something went wrong. Please try again.',
          statusCode: statusCode,
        );
    }
  }

  /// Never blindly `jsonDecode`s -- checks the body looks like JSON first,
  /// and wraps decoding in try/catch so a malformed or HTML body (e.g. a
  /// proxy error page) surfaces as a clean failure instead of a crash.
  ApiResponse<AuthUserModel> _parseSuccess(String rawBody, int statusCode) {
    if (!rawBody.trim().startsWith('{')) {
      return ApiResponse.failure(
        'Unexpected response from server. Please try again.',
        statusCode: statusCode,
      );
    }

    try {
      final decoded = jsonDecode(rawBody) as Map<String, dynamic>;
      final success = decoded['success'] == true;
      final data = decoded['data'];

      if (!success || data is! Map<String, dynamic>) {
        return ApiResponse.failure(
          (decoded['message'] as String?) ?? 'Login failed. Please try again.',
          statusCode: statusCode,
        );
      }

      final user = AuthUserModel.fromJson(data);
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

  String? _messageFrom(String rawBody) {
    if (!rawBody.trim().startsWith('{')) return null;
    try {
      final decoded = jsonDecode(rawBody) as Map<String, dynamic>;
      return decoded['message'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ADD THESE METHODS INSIDE SAME CLASS (no changes to existing code)

  // ================= FORGOT PASSWORD =================
  Future<ApiResponse<void>> forgotPassword(String email) async {
    try {
      final response = await _client.post(ApiEndpoints.forgotPassword, {
        'email': email,
      });

      return _handleVoidResponse(response.statusCode, response.body);
    } on HttpApiClientException catch (e) {
      return ApiResponse.failure(e.message);
    } catch (_) {
      return ApiResponse.failure('Something went wrong.');
    }
  }

  // ================= VERIFY OTP =================
  Future<ApiResponse<void>> verifyOtp(String otp) async {
    try {
      final response = await _client.post(ApiEndpoints.verifyOtp, {'otp': otp});

      return _handleVoidResponse(response.statusCode, response.body);
    } on HttpApiClientException catch (e) {
      return ApiResponse.failure(e.message);
    } catch (_) {
      return ApiResponse.failure('Something went wrong.');
    }
  }

  // ================= RESET PASSWORD =================
  Future<ApiResponse<void>> resetPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _client.post(ApiEndpoints.resetPassword, {
        'old_password': oldPassword,
        'new_password': newPassword,
      });

      return _handleVoidResponse(response.statusCode, response.body);
    } on HttpApiClientException catch (e) {
      return ApiResponse.failure(e.message);
    } catch (_) {
      return ApiResponse.failure('Something went wrong.');
    }
  }

  // ================= COMMON VOID HANDLER =================
  ApiResponse<void> _handleVoidResponse(int statusCode, String rawBody) {
    if (statusCode == 200) {
      return ApiResponse.success(
        null,
        message: _messageFrom(rawBody),
        statusCode: statusCode,
      );
    }

    return ApiResponse.failure(
      _messageFrom(rawBody) ?? 'Request failed',
      statusCode: statusCode,
    );
  }
}
