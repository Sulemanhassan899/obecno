import './api_cancel_token.dart';
import './api_client.dart';
import './api_error.dart';
import './api_response.dart';

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
      () => apiClient.get(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
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
      () => apiClient.post(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
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
      () => apiClient.put(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
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
      () => apiClient.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
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
      () => apiClient.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
      parser,
    );
  }

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
        if (parseError is ApiError) rethrow;
        throw ApiError(
          type: ApiErrorType.parsing,
          message: 'Failed to read server response. Please try again.',
          statusCode: response.statusCode,
        );
      }
    } on ApiError catch (e) {
      return ApiResponse.failure(
        e.message,
        statusCode: e.statusCode,
        fieldErrors: e.fieldErrors,
      );
    } catch (e) {
      final apiError = ApiError.fromException(e);
      return ApiResponse.failure(
        apiError.message,
        statusCode: apiError.statusCode,
        fieldErrors: apiError.fieldErrors,
      );
    }
  }
}
