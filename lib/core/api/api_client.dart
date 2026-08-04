import 'dart:convert';

import 'package:Obecno/core/api/session_manager.dart';
import 'package:Obecno/core/api/api_cancel_token.dart';
import 'package:Obecno/core/api/api_error.dart';
import 'package:Obecno/core/api/constants.dart';
import 'package:Obecno/core/services/interceptor.dart';
import 'package:Obecno/core/services/logger.dart';
import 'package:Obecno/core/services/network_checker.dart';
import 'package:Obecno/core/services/retry_interceptor.dart';
import 'package:Obecno/core/services/token_service.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({
    required TokenService tokenService,
    required NetworkChecker networkChecker,
    Future<void> Function()? onUnauthorized,
    String? baseUrl,
    http.Client? httpClient,

    SessionManager? sessionManager,
  }) : _tokenService = tokenService,
       _networkChecker = networkChecker,
       _baseUrl = baseUrl ?? AppConstants.baseUrl,
       _http = httpClient ?? http.Client(),
       _retryPolicy = RetryPolicy(),
       _sessionManager = sessionManager,
       _authFailureHandler = AuthFailureHandler(
         tokenService: tokenService,
         onUnauthorized: onUnauthorized,
       );

  final TokenService _tokenService;
  final NetworkChecker _networkChecker;
  final String _baseUrl;
  final http.Client _http;
  final RetryPolicy _retryPolicy;
  final SessionManager? _sessionManager;
  final AuthFailureHandler _authFailureHandler;

  Uri _resolve(String path, Map<String, dynamic>? queryParameters) {
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;

    var normalizedPath = path.startsWith('/') ? path : '/$path';
    final version = AppConstants.apiVersion.trim();
    if (version.isNotEmpty) {
      final normalizedVersion = version.startsWith('/') ? version : '/$version';
      if (!normalizedPath.startsWith(normalizedVersion)) {
        normalizedPath = '$normalizedVersion$normalizedPath';
      }
    }

    final uri = Uri.parse('$base$normalizedPath');

    if (queryParameters == null || queryParameters.isEmpty) return uri;

    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        ...queryParameters.map((k, v) => MapEntry(k, v.toString())),
      },
    );
  }

  dynamic _normalizeResponse(dynamic decoded) {
    if (decoded is Map && decoded.containsKey('data')) {
      final inner = decoded['data'];

      // 🔥 If inner data is JSON string → decode it
      if (inner is String) {
        final trimmed = inner.trim();

        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
          try {
            decoded['data'] = jsonDecode(inner);
          } catch (_) {}
        }
      }
    }

    return decoded;
  }

  Future<Map<String, String>> _headers(Uri uri) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final authHeader = await _tokenService.authorizationHeader;

    if (authHeader != null && authHeader.isNotEmpty) {
      headers['Authorization'] = authHeader;
    }

    return headers;
  }

  /// Races [body] against [token]'s cancellation so an already-started
  /// attempt is abandoned (from this call site's perspective -- the
  /// underlying socket read may still finish in the background, package:http
  /// gives no lower-level abort) the instant cancel() fires, rather than
  /// waiting for the current attempt/timeout to run its course.
  Future<T> _runCancellable<T>(
    Future<T> Function() body,
    ApiCancelToken? token,
  ) {
    final future = body();
    if (token == null) return future;
    return Future.any([
      future,
      token.whenCancelled.then(
        (_) => throw ApiError(
          type: ApiErrorType.cancelled,
          message: token.reason ?? 'Request cancelled',
        ),
      ),
    ]);
  }

  Future<RawApiResponse> _guard(
    String method,
    Uri uri,
    Future<http.Response> Function() call, {
    bool skipAuthInterceptor = false,
    ApiCancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled == true) {
      throw ApiError(
        type: ApiErrorType.cancelled,
        message: cancelToken?.reason ?? 'Request cancelled',
      );
    }

    if (!await _networkChecker.isConnected) {
      throw const ApiError(
        type: ApiErrorType.network,
        message: 'No internet connection.',
      );
    }

    AppLogger.request(method, uri.toString());

    late final http.Response response;

    try {
      response = await _runCancellable(
        () => _retryPolicy.run(
          uri.path,
          () => call().timeout(AppConstants.receiveTimeout),
          method: method,
          cancelToken: cancelToken,
        ),
        cancelToken,
      );
    } catch (e) {
      final apiError = ApiError.fromException(e);
      AppLogger.error(method, uri.toString(), apiError);
      throw apiError;
    }

    AppLogger.response(
      method,
      uri.toString(),
      response.statusCode,
      response.body,
    );

    if (!skipAuthInterceptor &&
        (response.statusCode == 401 || response.statusCode == 419)) {
      if (_sessionManager != null) {
        AppLogger.info(
          '[Interceptor] Received ${response.statusCode} for ${uri.path} -- validating session',
        );
        final isValid = await _sessionManager.handleUnauthorized();

        if (isValid) {
          if (cancelToken?.isCancelled == true) {
            throw ApiError(
              type: ApiErrorType.cancelled,
              message: cancelToken?.reason ?? 'Request cancelled',
            );
          }
          AppLogger.info('[Interceptor] Retrying request for ${uri.path}');
          final retryResponse = await _retryPolicy.run(
            uri.path,
            () => call().timeout(AppConstants.receiveTimeout),
            method: method, // FIXED (issue #6)
            cancelToken: cancelToken,
          );

          if (retryResponse.statusCode >= 400) {
            throw ApiError.fromResponse(
              statusCode: retryResponse.statusCode,
              decodedBody: _tryDecode(retryResponse.body),
            );
          }

          return RawApiResponse(
            statusCode: retryResponse.statusCode,
            data: _tryDecode(retryResponse.body) ?? retryResponse.body,
            headers: retryResponse.headers,
          );
        }
      } else {
        final hasSession = await _tokenService.isSessionActive;

        if (hasSession) {
          if (cancelToken?.isCancelled == true) {
            throw ApiError(
              type: ApiErrorType.cancelled,
              message: cancelToken?.reason ?? 'Request cancelled',
            );
          }
          final retryResponse = await _retryPolicy.run(
            uri.path,
            () => call().timeout(AppConstants.receiveTimeout),
            method: method, // FIXED (issue #6)
            cancelToken: cancelToken,
          );

          return RawApiResponse(
            statusCode: retryResponse.statusCode,
            data: _tryDecode(retryResponse.body) ?? retryResponse.body,
            headers: retryResponse.headers,
          );
        }
      }
    }

    if (response.statusCode == 409 || response.body.contains('4001')) {
      AppLogger.info('[BUSINESS CONFLICT] ${response.body}');
      return RawApiResponse(
        statusCode: response.statusCode,
        data: _tryDecode(response.body) ?? response.body,
        headers: response.headers,
      );
    }

    if (response.statusCode == 404) {
      AppLogger.info('[404 ERROR] Endpoint not found');
      return RawApiResponse(
        statusCode: response.statusCode,
        data: _tryDecode(response.body) ?? response.body,
        headers: response.headers,
      );
    }

    if (response.statusCode >= 400) {
      if (!skipAuthInterceptor &&
          (response.statusCode == 401 ||
              response.statusCode == 403 ||
              response.statusCode == 419)) {
        if (_sessionManager != null) {
          if (response.statusCode == 403) {
            await _sessionManager.handleUnauthorized();
          }
        } else {
          await _authFailureHandler.handleUnauthorized();
        }
      }

      throw ApiError.fromResponse(
        statusCode: response.statusCode,
        decodedBody: _tryDecode(response.body),
      );
    }

    return RawApiResponse(
      statusCode: response.statusCode,
      data: _tryDecode(response.body) ?? response.body,
      headers: response.headers,
    );
  }

  dynamic _tryDecode(String body) {
    final jsonSlice = _extractJson(body);
    if (jsonSlice == null) return null;

    try {
      final decoded = jsonDecode(jsonSlice);

      // 🔥 NORMALIZE HERE
      return _normalizeResponse(decoded);
    } catch (_) {
      return null;
    }
  }

  String? _extractJson(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    final objStart = trimmed.indexOf('{');
    final arrStart = trimmed.indexOf('[');

    int start;
    String close;
    if (objStart == -1 && arrStart == -1) {
      return null;
    } else if (objStart == -1 || (arrStart != -1 && arrStart < objStart)) {
      start = arrStart;
      close = ']';
    } else {
      start = objStart;
      close = '}';
    }

    final end = trimmed.lastIndexOf(close);
    if (end == -1 || end < start) return null;

    return trimmed.substring(start, end + 1);
  }

  Future<RawApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    ApiCancelToken? cancelToken,

    bool skipAuthInterceptor = false,
  }) {
    final uri = _resolve(path, queryParameters);

    return _guard('GET', uri, () async {
      final headers = await _headers(uri);
      return _http.get(uri, headers: headers);
    }, skipAuthInterceptor: skipAuthInterceptor, cancelToken: cancelToken);
  }

  Future<RawApiResponse> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    ApiCancelToken? cancelToken,
  }) {
    final uri = _resolve(path, queryParameters);

    return _guard('POST', uri, () async {
      final headers = await _headers(uri);

      return _http.post(
        uri,
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );
    }, cancelToken: cancelToken);
  }

  Future<RawApiResponse> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    ApiCancelToken? cancelToken,
  }) {
    final uri = _resolve(path, queryParameters);

    return _guard('PUT', uri, () async {
      final headers = await _headers(uri);

      return _http.put(
        uri,
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );
    }, cancelToken: cancelToken);
  }

  Future<RawApiResponse> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    ApiCancelToken? cancelToken,
  }) {
    final uri = _resolve(path, queryParameters);

    return _guard('PATCH', uri, () async {
      final headers = await _headers(uri);

      return _http.patch(
        uri,
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );
    }, cancelToken: cancelToken);
  }

  Future<RawApiResponse> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    ApiCancelToken? cancelToken,
  }) {
    final uri = _resolve(path, queryParameters);

    return _guard('DELETE', uri, () async {
      final headers = await _headers(uri);

      return _http.delete(
        uri,
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );
    }, cancelToken: cancelToken);
  }

  Future<RawApiResponse> postMultipart(
    String path, {
    Map<String, String>? fields,
    String? fileFieldName,
    List<int>? fileBytes,
    String? fileName,
    ApiCancelToken? cancelToken,
  }) {
    final uri = _resolve(path, null);

    return _guard('POST', uri, () async {
      final headers = await _headers(uri);
      headers.remove('Content-Type');

      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers);

      if (fields != null && fields.isNotEmpty) {
        request.fields.addAll(fields);
      }

      if (fileFieldName != null && fileBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            fileFieldName,
            fileBytes,
            filename: fileName ?? 'photo.jpg',
          ),
        );
      }

      final streamedResponse = await _http.send(request);
      return http.Response.fromStream(streamedResponse);
    }, cancelToken: cancelToken);
  }
}

class RawApiResponse {
  const RawApiResponse({
    required this.statusCode,
    required this.data,
    this.headers = const {},
  });

  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;
}
