import '../api/api_cancel_token.dart';
import '../api/api_client.dart';
import '../api/api_error.dart';
import '../api/api_response.dart';

/// Every feature repository (AttendanceRepository, EmployeeRepository, ...)
/// extends this. It owns zero business logic of its own — it exists so
/// "call the client, catch errors, parse JSON, wrap in ApiResponse" is
/// written exactly once instead of copy-pasted into every repository
/// method.
///
/// FIXED: `ApiClient` no longer wraps Dio, so this now talks in
/// [RawApiResponse]/[ApiCancelToken] instead of Dio's `Response`/
/// `CancelToken`. The public shape (`getRequest`/`postRequest`/... taking
/// a `parser` and returning `ApiResponse<T>`) is unchanged, so feature
/// repositories that extend this class don't need to change at all.
abstract class BaseRepository {
  BaseRepository(this.apiClient);

  final ApiClient apiClient;

  Future<ApiResponse<T>> getRequest<T>(
    String path, {
    required T Function(dynamic json) parser,
    Map<String, dynamic>? queryParameters,
    ApiCancelToken? cancelToken,
  }) {
    return _execute(
      () => apiClient.get(path, queryParameters: queryParameters, cancelToken: cancelToken),
      parser,
    );
  }

  Future<ApiResponse<T>> postRequest<T>(
    String path, {
    required T Function(dynamic json) parser,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    ApiCancelToken? cancelToken,
  }) {
    return _execute(
      () => apiClient.post(path, data: data, queryParameters: queryParameters, cancelToken: cancelToken),
      parser,
    );
  }

  Future<ApiResponse<T>> putRequest<T>(
    String path, {
    required T Function(dynamic json) parser,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    ApiCancelToken? cancelToken,
  }) {
    return _execute(
      () => apiClient.put(path, data: data, queryParameters: queryParameters, cancelToken: cancelToken),
      parser,
    );
  }

  Future<ApiResponse<T>> patchRequest<T>(
    String path, {
    required T Function(dynamic json) parser,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    ApiCancelToken? cancelToken,
  }) {
    return _execute(
      () => apiClient.patch(path, data: data, queryParameters: queryParameters, cancelToken: cancelToken),
      parser,
    );
  }

  Future<ApiResponse<T>> deleteRequest<T>(
    String path, {
    required T Function(dynamic json) parser,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    ApiCancelToken? cancelToken,
  }) {
    return _execute(
      () => apiClient.delete(path, data: data, queryParameters: queryParameters, cancelToken: cancelToken),
      parser,
    );
  }

  /// Shared success/error/parse-failure funnel for every verb above.
  Future<ApiResponse<T>> _execute<T>(
    Future<RawApiResponse> Function() call,
    T Function(dynamic json) parser,
  ) async {
    try {
      final response = await call();
      try {
        final parsed = parser(response.data);
        return ApiResponse.success(parsed, statusCode: response.statusCode);
      } catch (parseError) {
        throw ApiError(
          type: ApiErrorType.parsing,
          message: 'Failed to read server response. Please try again.',
          statusCode: response.statusCode,
        );
      }
    } on ApiError catch (e) {
      return ApiResponse.failure(e.message, statusCode: e.statusCode);
    } catch (e) {
      final apiError = ApiError.fromException(e);
      return ApiResponse.failure(apiError.message, statusCode: apiError.statusCode);
    }
  }
}
