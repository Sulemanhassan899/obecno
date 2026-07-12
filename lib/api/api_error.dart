import 'dart:async';
import 'dart:io';

/// Classification of failures so the UI layer can decide *how* to react
/// (retry button, login redirect, generic toast) without parsing strings.
enum ApiErrorType {
  network,
  timeout,
  server,
  unauthorized,
  validation,
  parsing,
  cancelled,
  unknown,
}

class ApiError implements Exception {
  const ApiError({
    required this.type,
    required this.message,
    this.statusCode,
    this.fieldErrors,
  });

  final ApiErrorType type;
  final String message;
  final int? statusCode;

  /// Backend validation errors keyed by field name, e.g. {"email": "invalid"}.
  final Map<String, dynamic>? fieldErrors;

  /// Converts any thrown object into an [ApiError]. This is the single
  /// funnel every failure (network, timeout, or the guard's own
  /// status-code check) routes exceptions through — mirrors what the old
  /// Dio-based `fromException` did with `DioException`.
  factory ApiError.fromException(Object error) {
    if (error is ApiError) return error;

    if (error is SocketException) {
      return const ApiError(
        type: ApiErrorType.network,
        message: 'No internet connection. Please check your network.',
      );
    }

    if (error is TimeoutException) {
      return const ApiError(
        type: ApiErrorType.timeout,
        message: 'The request timed out. Please try again.',
      );
    }

    if (error is HttpException) {
      return ApiError(
        type: ApiErrorType.network,
        message: error.message.isNotEmpty ? error.message : 'A network error occurred.',
      );
    }

    if (error is FormatException) {
      return const ApiError(
        type: ApiErrorType.parsing,
        message: 'Failed to read server response. Please try again.',
      );
    }

    return ApiError(type: ApiErrorType.unknown, message: error.toString());
  }

  /// Builds an [ApiError] from a completed HTTP response whose status code
  /// signals failure (>= 400). [decodedBody] is the already-safely-parsed
  /// JSON map, or null if the body wasn't valid JSON.
  factory ApiError.fromResponse({required int? statusCode, Map<String, dynamic>? decodedBody}) {
    String message = 'Something went wrong. Please try again.';
    Map<String, dynamic>? fieldErrors;

    if (decodedBody != null) {
      message = (decodedBody['message'] ?? decodedBody['error'] ?? message).toString();
      final errors = decodedBody['errors'];
      if (errors is Map<String, dynamic>) fieldErrors = errors;
    }

    if (statusCode == 401 || statusCode == 403) {
      return ApiError(
        type: ApiErrorType.unauthorized,
        message: message == 'Something went wrong. Please try again.'
            ? 'Your session has expired. Please log in again.'
            : message,
        statusCode: statusCode,
      );
    }

    if (statusCode == 422 || statusCode == 400) {
      return ApiError(
        type: ApiErrorType.validation,
        message: message,
        statusCode: statusCode,
        fieldErrors: fieldErrors,
      );
    }

    if (statusCode != null && statusCode >= 500) {
      return ApiError(
        type: ApiErrorType.server,
        message: 'Server error. Please try again shortly.',
        statusCode: statusCode,
      );
    }

    return ApiError(type: ApiErrorType.unknown, message: message, statusCode: statusCode);
  }

  @override
  String toString() => 'ApiError(type: $type, statusCode: $statusCode, message: $message)';
}
