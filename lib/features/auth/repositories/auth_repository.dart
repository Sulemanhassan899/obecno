
// import 'dart:convert';

// import 'package:Obecno/core/api/api.dart';
// import 'package:Obecno/core/api/api_endpoints.dart';
// import 'package:Obecno/core/api/api_response.dart';
// import 'package:Obecno/features/auth/data/models/auth_user_model.dart';

// class AuthRepository {
//   AuthRepository(this._client);

//   final HttpApiClient _client;

//   /// Decodes the JSON object embedded in [rawBody], tolerating leading
//   /// (or trailing) junk that isn't part of the JSON itself.
//   ///
//   /// The backend sometimes leaks a PHP warning/notice (HTML like
//   /// `<br />\n<b>Warning</b>: ... on line 198<br />`) in front of the
//   /// actual JSON payload -- see `obecno_session.php:198`. A strict
//   /// `rawBody.startsWith('{')` check rejects that whole response as
//   /// "unexpected" even though a valid JSON object is sitting right there
//   /// at the end of the string. Instead, find the outermost `{ ... }` in
//   /// the body and decode just that slice.
//   ///
//   /// Returns null (never throws) if no JSON object can be found/decoded.
//   Map<String, dynamic>? _decodeJson(String rawBody) {
//     final start = rawBody.indexOf('{');
//     final end = rawBody.lastIndexOf('}');
//     if (start == -1 || end == -1 || end < start) return null;

//     try {
//       final decoded = jsonDecode(rawBody.substring(start, end + 1));
//       return decoded is Map<String, dynamic> ? decoded : null;
//     } catch (_) {
//       return null;
//     }
//   }

//   // ================= CHECK EMAIL (STEP 1) =================
//   /// POSTs email ONLY to [ApiEndpoints.login]. Backend responds with
//   /// `data.exists` (bool). Used by [LoginEmailScreen] before moving to
//   /// [LoginPasswordScreen].
//   Future<ApiResponse<bool>> checkEmail(String email) async {
//     try {
//       final response = await _client.post(ApiEndpoints.login, {'email': email});

//       return _handleCheckEmailResponse(response.statusCode, response.body);
//     } on HttpApiClientException catch (e) {
//       return ApiResponse.failure(e.message);
//     } catch (_) {
//       return ApiResponse.failure('Something went wrong. Please try again.');
//     }
//   }

//   ApiResponse<bool> _handleCheckEmailResponse(int statusCode, String rawBody) {
//     switch (statusCode) {
//       case 200:
//         return _parseCheckEmailSuccess(rawBody, statusCode);
//       case 422:
//         return ApiResponse.failure(
//           _messageFrom(rawBody) ?? 'Please enter a valid email.',
//           statusCode: statusCode,
//         );
//       case 500:
//         return ApiResponse.failure(
//           'Server error. Please try again shortly.',
//           statusCode: statusCode,
//         );
//       default:
//         return ApiResponse.failure(
//           _messageFrom(rawBody) ?? 'Something went wrong. Please try again.',
//           statusCode: statusCode,
//         );
//     }
//   }

//   ApiResponse<bool> _parseCheckEmailSuccess(String rawBody, int statusCode) {
//     final decoded = _decodeJson(rawBody);
//     if (decoded == null) {
//       return ApiResponse.failure(
//         'Unexpected response from server. Please try again.',
//         statusCode: statusCode,
//       );
//     }

//     final success = decoded['success'] == true;

//     if (!success) {
//       return ApiResponse.failure(
//         (decoded['message'] as String?) ?? 'Failed to verify email.',
//         statusCode: statusCode,
//       );
//     }

//     final data = decoded['data'];
//     bool exists = false;
//     if (data is Map<String, dynamic>) {
//       exists = data['exists'] == true;
//     } else if (data is bool) {
//       exists = data;
//     }

//     return ApiResponse.success(
//       exists,
//       message: decoded['message'] as String?,
//       statusCode: statusCode,
//     );
//   }

//   // ================= SIGN IN (STEP 2) =================
//   /// POSTs email + password to [ApiEndpoints.login] in a single request.
//   /// The session cookie itself is captured by [HttpApiClient] from the
//   /// response headers; this method only worries about the response body.
//   Future<ApiResponse<AuthUserModel>> login({
//     required String email,
//     required String password,
//     bool rememberMe = true,
//   }) async {
//     try {
//       final response = await _client.post(ApiEndpoints.login, {
//         'email': email,
//         'password': password,
//         'remember_me': rememberMe,
//       });

//       return _handleResponse(response.statusCode, response.body);
//     } on HttpApiClientException catch (e) {
//       return ApiResponse.failure(e.message);
//     } catch (_) {
//       return ApiResponse.failure('Something went wrong. Please try again.');
//     }
//   }

//   ApiResponse<AuthUserModel> _handleResponse(int statusCode, String rawBody) {
//     switch (statusCode) {
//       case 200:
//         return _parseSuccess(rawBody, statusCode);
//       case 400:
//         return ApiResponse.failure(
//           _messageFrom(rawBody) ??
//               'Please check your email and password and try again.',
//           statusCode: statusCode,
//         );
//       case 401:
//         return ApiResponse.failure(
//           _messageFrom(rawBody) ?? 'Invalid email or password.',
//           statusCode: statusCode,
//         );
//       case 500:
//         return ApiResponse.failure(
//           'Server error. Please try again shortly.',
//           statusCode: statusCode,
//         );
//       default:
//         return ApiResponse.failure(
//           _messageFrom(rawBody) ?? 'Something went wrong. Please try again.',
//           statusCode: statusCode,
//         );
//     }
//   }

//   /// Never blindly `jsonDecode`s -- checks the body looks like JSON first,
//   /// and wraps decoding in try/catch so a malformed or HTML body (e.g. a
//   /// proxy error page) surfaces as a clean failure instead of a crash.
//   ApiResponse<AuthUserModel> _parseSuccess(String rawBody, int statusCode) {
//     final decoded = _decodeJson(rawBody);
//     if (decoded == null) {
//       return ApiResponse.failure(
//         'Unexpected response from server. Please try again.',
//         statusCode: statusCode,
//       );
//     }

//     try {
//       final success = decoded['success'] == true;
//       final data = decoded['data'];

//       if (!success || data is! Map<String, dynamic>) {
//         return ApiResponse.failure(
//           (decoded['message'] as String?) ?? 'Login failed. Please try again.',
//           statusCode: statusCode,
//         );
//       }

//       final user = AuthUserModel.fromJson(data);
//       return ApiResponse.success(
//         user,
//         message: decoded['message'] as String?,
//         statusCode: statusCode,
//       );
//     } catch (_) {
//       return ApiResponse.failure(
//         'Failed to read server response. Please try again.',
//         statusCode: statusCode,
//       );
//     }
//   }

//   String? _messageFrom(String rawBody) {
//     final decoded = _decodeJson(rawBody);
//     return decoded?['message'] as String?;
//   }

//   Future<ApiResponse<void>> forgotPassword(String email) async {
//     try {
//       final response = await _client.post(ApiEndpoints.forgot, {
//         'email': email,
//       });

//       return _handleForgotPasswordResponse(response.statusCode, response.body);
//     } on HttpApiClientException catch (e) {
//       return ApiResponse.failure(e.message);
//     } catch (_) {
//       return ApiResponse.failure('Something went wrong. Please try again.');
//     }
//   }

//   ApiResponse<void> _handleForgotPasswordResponse(
//     int statusCode,
//     String rawBody,
//   ) {
//     if (statusCode == 200) {
//       return ApiResponse.success(
//         null,
//         message:
//             _messageFrom(rawBody) ??
//             'Please check your email for further instructions.',
//         statusCode: statusCode,
//       );
//     }

//     if (statusCode == 422) {
//       return ApiResponse.failure(
//         _fieldErrorFrom(rawBody, 'email') ??
//             _messageFrom(rawBody) ??
//             'Invalid email.',
//         statusCode: statusCode,
//       );
//     }

//     return ApiResponse.failure(
//       _messageFrom(rawBody) ?? 'Something went wrong. Please try again.',
//       statusCode: statusCode,
//     );
//   }

//   /// Extracts `errors.<field>` from a 422-style validation body, e.g.
//   /// `{"success":false,"message":"...","errors":{"email":"Invalid email"}}`.
//   /// Returns null (never throws) if the body isn't shaped that way.
//   String? _fieldErrorFrom(String rawBody, String field) {
//     final decoded = _decodeJson(rawBody);
//     if (decoded == null) return null;

//     final errors = decoded['errors'];
//     if (errors is Map<String, dynamic>) {
//       final fieldError = errors[field];
//       if (fieldError is String) return fieldError;
//       if (fieldError is List && fieldError.isNotEmpty) {
//         return fieldError.first.toString();
//       }
//     }
//     return null;
//   }
// }
import 'package:Obecno/core/api/api_client.dart';
import 'package:Obecno/core/api/api_endpoints.dart';
import 'package:Obecno/core/api/api_error.dart';
import 'package:Obecno/core/api/api_response.dart';
import 'package:Obecno/features/auth/data/models/auth_user_model.dart';

/// Talks to every `/api/auth/*` endpoint.
///
/// FIXED: this class used to depend on `HttpApiClient` (`core/api/api.dart`),
/// a stripped-down client that only had a bare `post()` and its own
/// `HttpApiClientException` type. That client was never wired to a `get`
/// call, so `/api/auth/me` couldn't be added without a parallel rewrite --
/// and it duplicated cookie/retry/error handling that [ApiClient] already
/// owns. This now depends on the real [ApiClient] (same one every other
/// module uses), so `AuthRepository` gets GET/PUT/POST/multipart for free
/// and there's only one HTTP client in the app.
///
/// Response-shape handling is unchanged from before: the backend reports
/// some business outcomes (e.g. "no account with this email") as HTTP 200
/// with `{"success": false, "message": "..."}` in the body, so those are
/// read from the decoded map. Anything the server signals via a non-2xx
/// status is already normalized into an [ApiError] by [ApiClient]'s
/// `_guard`, so those are caught once and turned into [ApiResponse.failure].
class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Map<String, dynamic>? _asMap(dynamic data) => data is Map<String, dynamic> ? data : null;

  // ================= CHECK EMAIL (STEP 1) =================
  /// POSTs email ONLY to [ApiEndpoints.login]. Backend responds with
  /// `data.exists` (bool). Used by [LoginEmailScreen] before moving to
  /// [LoginPasswordScreen].
  Future<ApiResponse<bool>> checkEmail(String email) async {
    try {
      final response = await _client.post(ApiEndpoints.login, data: {'email': email});
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
      return ApiResponse.failure('Unexpected response from server. Please try again.', statusCode: statusCode);
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

    return ApiResponse.success(exists, message: decoded['message'] as String?, statusCode: statusCode);
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
      return _parseUserEnvelope(response.data, response.statusCode, fallbackMessage: 'Login failed. Please try again.');
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
      return ApiResponse.failure('Unexpected response from server. Please try again.', statusCode: statusCode);
    }

    try {
      final success = decoded['success'] == true;
      final body = decoded['data'];

      if (!success || body is! Map<String, dynamic>) {
        return ApiResponse.failure((decoded['message'] as String?) ?? fallbackMessage, statusCode: statusCode);
      }

      final user = AuthUserModel.fromJson(body);
      return ApiResponse.success(user, message: decoded['message'] as String?, statusCode: statusCode);
    } catch (_) {
      return ApiResponse.failure('Failed to read server response. Please try again.', statusCode: statusCode);
    }
  }

  // ================= FORGOT PASSWORD =================
  Future<ApiResponse<void>> forgotPassword(String email) async {
    try {
      final response = await _client.post(ApiEndpoints.forgot, data: {'email': email});
      final decoded = _asMap(response.data);

      return ApiResponse.success(
        null,
        message: decoded?['message'] as String? ?? 'Please check your email for further instructions.',
        statusCode: response.statusCode,
      );
    } on ApiError catch (e) {
      return ApiResponse.failure(_fieldOrGeneralMessage(e, 'email'), statusCode: e.statusCode);
    } catch (_) {
      return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }

  // ================= CHANGE PASSWORD =================
  /// POST /api/auth/change-password
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
          'new_password_confirmation': newPasswordConfirmation,
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
        message: decoded?['message'] as String? ?? 'Password changed successfully.',
        statusCode: response.statusCode,
      );
    } on ApiError catch (e) {
      return ApiResponse.failure(_fieldOrGeneralMessage(e, 'current_password'), statusCode: e.statusCode);
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
    if (fieldError is List && fieldError.isNotEmpty) return fieldError.first.toString();
    return error.message;
  }
}