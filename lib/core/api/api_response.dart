import './api_error.dart';

class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
    this.fieldErrors,
  });

  final bool success;
  final T? data;
  final String? message;
  final int? statusCode;
  final Map<String, dynamic>? fieldErrors;

  factory ApiResponse.success(T data, {String? message, int? statusCode}) {
    return ApiResponse<T>(
      success: true,
      data: data,
      message: message,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.failure(
    String message, {
    int? statusCode,
    Map<String, dynamic>? fieldErrors,
  }) {
    return ApiResponse<T>(
      success: false,
      data: null,
      message: message,
      statusCode: statusCode,
      fieldErrors: fieldErrors,
    );
  }

  String? messageForFields(List<String> keys) {
    final errors = fieldErrors;
    if (errors == null || errors.isEmpty) return null;
    for (final key in keys) {
      final text = fieldErrorText(errors[key]);
      if (text != null) return text;
    }
    return null;
  }

  String? get firstFieldMessage {
    final errors = fieldErrors;
    if (errors == null) return null;
    for (final value in errors.values) {
      final text = fieldErrorText(value);
      if (text != null) return text;
    }
    return null;
  }

  @override
  String toString() =>
      'ApiResponse(success: $success, statusCode: $statusCode, message: $message)';
}
