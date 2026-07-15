/// Uniform envelope returned by [BaseRepository] for every call, so
/// providers never branch on Dio/HTTP types — only on this shape.
class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
  });

  final bool success;
  final T? data;
  final String? message;
  final int? statusCode;

  factory ApiResponse.success(T data, {String? message, int? statusCode}) {
    return ApiResponse<T>(success: true, data: data, message: message, statusCode: statusCode);
  }

  factory ApiResponse.failure(String message, {int? statusCode}) {
    return ApiResponse<T>(success: false, data: null, message: message, statusCode: statusCode);
  }

  @override
  String toString() => 'ApiResponse(success: $success, statusCode: $statusCode, message: $message)';
}
