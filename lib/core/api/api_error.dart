import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

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

  final Map<String, dynamic>? fieldErrors;

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

    if (error is http.ClientException) {
      return const ApiError(
        type: ApiErrorType.network,
        message: 'Connection was interrupted. Please try again.',
      );
    }

    return ApiError(type: ApiErrorType.unknown, message: error.toString());
  }

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
