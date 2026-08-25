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
      fieldErrors = mapApiFieldErrors(decodedBody);
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

Map<String, dynamic>? mapApiFieldErrors(Map<String, dynamic> body) {
  final raw =
      body['errors'] ??
      body['field_errors'] ??
      (body['data'] is Map ? (body['data'] as Map)['errors'] : null);
  if (raw is! Map) return null;
  return {for (final entry in raw.entries) entry.key.toString(): entry.value};
}

String? fieldErrorText(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
  if (value is List) {
    for (final item in value) {
      final text = fieldErrorText(item);
      if (text != null) return text;
    }
    return null;
  }
  if (value is Map) {
    return fieldErrorText(value['message']) ??
        fieldErrorText(value['error']) ??
        fieldErrorText(value['0']) ??
        fieldErrorText(value.values.isEmpty ? null : value.values.first);
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
