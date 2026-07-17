import 'package:Obecno/core/api/api_client.dart';
import 'package:Obecno/core/api/api_endpoints.dart';
import 'package:Obecno/core/api/api_error.dart';
import 'package:Obecno/core/api/api_response.dart';
import 'package:Obecno/features/auth/data/models/auth_user_model.dart';

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Map<String, dynamic>? _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : null;

  // ================= CHECK EMAIL (STEP 1) =================
  /// POSTs email ONLY to [ApiEndpoints.login]. Backend responds with
  /// `data.exists` (bool). Used by [LoginEmailScreen] before moving to
  /// [LoginPasswordScreen].
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

  // ================= SIGN IN (STEP 2) =================
  /// POSTs email + password to [ApiEndpoints.login] in a single request.
  /// The session cookie itself is captured by [ApiClient] from the
  /// response headers; this method only worries about the response body.
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

  // ================= CURRENT USER =================
  /// GET /api/auth/me — refreshes the session user (name/email/role) from
  /// the server. Used on app resume / session-restore instead of blindly
  /// trusting whatever role was last persisted locally.
  Future<ApiResponse<AuthUserModel>> getCurrentUser() async {
    try {
      final response = await _client.get(ApiEndpoints.currentUser);
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

  /// Shared parser for the two endpoints that return a `{success, data:
  /// {...user...}, message}` envelope wrapping an [AuthUserModel] --
  /// login and /api/auth/me.
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

  // ================= CHANGE PASSWORD =================
  /// POST /api/auth/change-password
  ///
  /// FIXED: the confirmation field was being sent as
  /// `new_password_confirmation`, but the backend's validator actually
  /// reads it as `new_password_confirm` (confirmed by the 422 body:
  /// `{"errors":{"new_password_confirm":"Please confirm your new
  /// password."}}`). Because the key never matched, the backend always
  /// treated the confirmation as missing and rejected the request with a
  /// 422 even when the user had typed a matching confirmation.
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

  /// Prefers a 422-style `errors.<field>` validation message over the
  /// error's general `message`, mirroring the old manual
  /// `_fieldErrorFrom`/`_messageFrom` helpers -- but now reading off the
  /// already-parsed [ApiError] instead of re-decoding the raw body.
  String _fieldOrGeneralMessage(ApiError error, String field) {
    final fieldError = error.fieldErrors?[field];
    if (fieldError is String) return fieldError;
    if (fieldError is List && fieldError.isNotEmpty)
      return fieldError.first.toString();
    return error.message;
  }

  /// FIXED: change-password validation can fail on *any* of three fields
  /// (`current_password`, `new_password`, `new_password_confirm`), but the
  /// old code only ever looked at `current_password` -- so a "New password
  /// must be at least 8 characters" or "Please confirm your new password"
  /// error from the server was silently swallowed, and the user either saw
  /// nothing useful or an unrelated message. This checks all three, in the
  /// order the user fills the form, and falls back to the error's general
  /// `message` only if none of them have a field-specific error.
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
