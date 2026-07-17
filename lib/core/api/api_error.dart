import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

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
        message: error.message.isNotEmpty
            ? error.message
            : 'A network error occurred.',
      );
    }

    if (error is FormatException) {
      return const ApiError(
        type: ApiErrorType.parsing,
        message: 'Failed to read server response. Please try again.',
      );
    }

    // FIXED: package:http's IOClient wraps connection-level failures
    // (server closed the socket mid-response, dropped connection, reset,
    // etc. -- e.g. "Connection closed before full header was received")
    // in its own `http.ClientException`, which is neither a
    // `SocketException` nor a `HttpException`. Every branch above missed
    // it, so this was falling through to `ApiErrorType.unknown` with the
    // raw exception text as the message -- and, critically, skipping
    // whatever retry-on-network-error logic keys off `ApiErrorType
    // .network`. Classified as `network` here so it's both retried and
    // shown to the user the same way any other dropped connection is.
    if (error is http.ClientException) {
      return const ApiError(
        type: ApiErrorType.network,
        message: 'Connection was interrupted. Please try again.',
      );
    }

    return ApiError(type: ApiErrorType.unknown, message: error.toString());
  }

  /// Builds an [ApiError] from a completed HTTP response whose status code
  /// signals failure (>= 400). [decodedBody] is the already-safely-parsed
  /// JSON map, or null if the body wasn't valid JSON.
  factory ApiError.fromResponse({
    required int? statusCode,
    Map<String, dynamic>? decodedBody,
  }) {
    String message = 'Something went wrong. Please try again.';
    Map<String, dynamic>? fieldErrors;

    if (decodedBody != null) {
      message = (decodedBody['message'] ?? decodedBody['error'] ?? message)
          .toString();
      final errors = decodedBody['errors'];
      if (errors is Map<String, dynamic>) fieldErrors = errors;
    }

    // FIXED: 419 (session/CSRF timeout -- the code this backend uses
    // alongside 401 for an expired session, per the spec's "IF statusCode
    // == 401 OR 419" interceptor rule) was falling through to the generic
    // `unknown` branch below and surfacing a confusing raw message instead
    // of "Your session has expired. Please log in again."
    if (statusCode == 401 || statusCode == 403 || statusCode == 419) {
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

    return ApiError(
      type: ApiErrorType.unknown,
      message: message,
      statusCode: statusCode,
    );
  }

  @override
  String toString() =>
      'ApiError(type: $type, statusCode: $statusCode, message: $message)';
}
