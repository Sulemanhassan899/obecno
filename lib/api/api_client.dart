import 'dart:convert';
import 'dart:io';

import 'package:Obecno/api/api_cancel_token.dart';
import 'package:Obecno/api/api_error.dart';
import 'package:Obecno/api/constants.dart';
import 'package:Obecno/api/cookie_service.dart';
import 'package:Obecno/core/services/interceptor.dart';
import 'package:Obecno/core/services/logger.dart';
import 'package:Obecno/core/services/network_checker.dart';
import 'package:Obecno/core/services/retry_interceptor.dart';
import 'package:Obecno/core/services/token_service.dart';
import 'package:http/http.dart' as http;

/// The single client for the whole app. Nothing outside `api/` should
/// import `package:http` directly — repositories talk to this class, and
/// this class is the only place that knows about cookies, retries, and
/// request/response logging.
///
/// FIXED: previously built on `package:dio` + `dio_cookie_manager` with an
/// interceptor chain (`CookieManager`, `AuthInterceptor`, `RetryInterceptor`,
/// a logging `InterceptorsWrapper`). None of that is available without
/// Dio, so this rewrite folds the same behavior into one guarded call
/// path instead of an interceptor pipeline:
///
///   1. connectivity check
///   2. attach cookies from [CookieService]'s jar
///   3. send via `package:http`, wrapped in [RetryPolicy]
///   4. log request/response via [AppLogger]
///   5. persist any `set-cookie` back into the jar
///   6. on 401/403, hand off to [AuthFailureHandler]; on any 4xx/5xx,
///      throw an [ApiError]
class ApiClient {
  ApiClient({
    required CookieService cookieService,
    required TokenService tokenService,
    required NetworkChecker networkChecker,
    Future<void> Function()? onUnauthorized,
    String? baseUrl,
    http.Client? httpClient,
  }) : _cookieService = cookieService,
       _networkChecker = networkChecker,
       _baseUrl = baseUrl ?? AppConstants.baseUrl,
       _http = httpClient ?? http.Client(),
       _retryPolicy = RetryPolicy(),
       _authFailureHandler = AuthFailureHandler(
         tokenService: tokenService,
         onUnauthorized: onUnauthorized,
       );

  final CookieService _cookieService;
  final NetworkChecker _networkChecker;
  final String _baseUrl;
  final http.Client _http;
  final RetryPolicy _retryPolicy;
  final AuthFailureHandler _authFailureHandler;

  Uri _resolve(String path, Map<String, dynamic>? queryParameters) {
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) return uri;
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        ...queryParameters.map((k, v) => MapEntry(k, v.toString())),
      },
    );
  }

  Future<Map<String, String>> _headers(Uri uri) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept':
          'application/json', // missing this can make the backend return HTML instead of JSON
    };
    final cookies = await _cookieService.jar.loadForRequest(uri);
    if (cookies.isNotEmpty) {
      headers['Cookie'] = cookies.map((c) => '${c.name}=${c.value}').join('; ');
    }
    return headers;
  }

  /// Every public method funnels through here so offline detection,
  /// retry, cookie handling, logging, and status-code -> ApiError
  /// conversion happen exactly once.
  Future<RawApiResponse> _guard(
    String method,
    Uri uri,
    Future<http.Response> Function() call,
  ) async {
    if (!await _networkChecker.isConnected) {
      throw const ApiError(
        type: ApiErrorType.network,
        message: 'No internet connection. Please check your network.',
      );
    }

    AppLogger.request(method, uri.toString());

    late final http.Response response;
    try {
      response = await _retryPolicy.run(
        uri.path,
        () => call().timeout(AppConstants.receiveTimeout),
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

    // Persist any cookie the backend set, same job the Dio CookieManager
    // interceptor used to do.
    final rawSetCookie = response.headers['set-cookie'];
    if (rawSetCookie != null && rawSetCookie.isNotEmpty) {
      final cookies = _splitSetCookieHeader(
        rawSetCookie,
      ).map(Cookie.fromSetCookieValue).toList();
      await _cookieService.jar.saveFromResponse(uri, cookies);
    }

    if (response.statusCode >= 400) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _authFailureHandler.handleUnauthorized();
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

  /// Never blindly `jsonDecode`s a body — returns null (not a throw) for
  /// anything that isn't a JSON object, so callers can fall back to the
  /// raw string instead of crashing on an HTML error page.
  dynamic _tryDecode(String body) {
    if (!body.trim().startsWith('{') && !body.trim().startsWith('['))
      return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// `package:http` merges repeated response headers (like multiple
  /// `Set-Cookie` lines) into one comma-joined string, which collides
  /// with the comma inside `Expires=Wed, 21 Oct ...`. This splits only on
  /// commas that are actually followed by the start of a new
  /// `name=value` cookie pair, not commas inside a date.
  List<String> _splitSetCookieHeader(String raw) {
    final parts = <String>[];
    var start = 0;
    final newCookieStart = RegExp(r'^\s*[^=;,\s]+=');
    for (var i = 0; i < raw.length; i++) {
      if (raw[i] != ',') continue;
      final ahead = raw.substring(i + 1);
      if (newCookieStart.hasMatch(ahead)) {
        parts.add(raw.substring(start, i).trim());
        start = i + 1;
      }
    }
    parts.add(raw.substring(start).trim());
    return parts;
  }

  Future<RawApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    ApiCancelToken? cancelToken,
  }) {
    final uri = _resolve(path, queryParameters);
    return _guard('GET', uri, () async {
      final headers = await _headers(uri);
      return _http.get(uri, headers: headers);
    });
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
    });
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
    });
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
    });
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
    });
  }
}

/// Uniform transport-level result, replacing Dio's `Response<dynamic>`.
/// [data] is the JSON-decoded body when possible, otherwise the raw
/// string — `BaseRepository` still does its own parsing on top of this.
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
