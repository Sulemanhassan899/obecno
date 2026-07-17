

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:Obecno/core/api/api_cancel_token.dart';
import 'package:Obecno/core/api/api_error.dart';
import 'package:Obecno/core/api/constants.dart';
import 'package:Obecno/core/api/cookie_service.dart';
import 'package:Obecno/core/services/interceptor.dart';
import 'package:Obecno/core/services/logger.dart';
import 'package:Obecno/core/services/network_checker.dart';
import 'package:Obecno/core/services/retry_interceptor.dart';
import 'package:Obecno/core/services/token_service.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({
    required CookieService cookieService,
    required TokenService tokenService,
    required NetworkChecker networkChecker,
    Future<void> Function()? onUnauthorized,
    String? baseUrl,
    http.Client? httpClient,
  }) : _cookieService = cookieService,
       _tokenService = tokenService,
       _networkChecker = networkChecker,
       _baseUrl = baseUrl ?? AppConstants.baseUrl,
       _http = httpClient ?? http.Client(),
       _retryPolicy = RetryPolicy(),
       _authFailureHandler = AuthFailureHandler(
         tokenService: tokenService,
         onUnauthorized: onUnauthorized,
       );

  final CookieService _cookieService;
  final TokenService _tokenService;
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

  dynamic _normalizeResponse(dynamic decoded) {
    if (decoded is Map && decoded.containsKey('data')) {
      final inner = decoded['data'];

      // 🔥 If inner data is JSON string → decode it
      if (inner is String) {
        final trimmed = inner.trim();

        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
          try {
            decoded['data'] = jsonDecode(inner);
          } catch (_) {
            // leave as is if parsing fails
          }
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

    // ✅ SINGLE SOURCE OF TRUTH FOR OUTGOING COOKIES
    //
    // `_cookieService.jar` is a PersistCookieJar that already parses each
    // `Set-Cookie` value into a proper `Cookie(name, value)` pair (see the
    // `saveFromResponse` call below). `loadForRequest` reassembles those
    // into the only format a `Cookie:` request header is allowed to use:
    // `name=value; name2=value2`.
    //
    // Previously this was overwritten with `_tokenService.getCookie()`,
    // which stores the *raw* `Set-Cookie` response header verbatim
    // (including `Path=`, `HttpOnly`, `Expires=...` attributes). Sending
    // that raw string back as a `Cookie` request header is invalid and is
    // what caused the first request after login to work (jar cookie was
    // still in use) and every request after that to 401 (as soon as any
    // response re-issued `Set-Cookie`, the malformed raw value took over).
    final cookies = await _cookieService.jar.loadForRequest(uri);

    if (cookies.isNotEmpty) {
      headers['Cookie'] = cookies.map((c) => '${c.name}=${c.value}').join('; ');
    }

    return headers;
  }

  Future<RawApiResponse> _guard(
    String method,
    Uri uri,
    Future<http.Response> Function() call,
  ) async {
    if (!await _networkChecker.isConnected) {
      throw const ApiError(
        type: ApiErrorType.network,
        message: 'No internet connection.',
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

    if (kDebugMode) {
      AppLogger.info('[URL] ${uri.toString()}');
      AppLogger.info('[STATUS] ${response.statusCode}');
      AppLogger.info('[BODY] ${response.body}');
      AppLogger.info('[HEADERS] ${response.headers}');
    }

    // ✅ COOKIE HANDLING
    final rawSetCookie = response.headers['set-cookie'];
    if (rawSetCookie != null && rawSetCookie.isNotEmpty) {
      final cookies = _splitSetCookieHeader(rawSetCookie)
          .map(Cookie.fromSetCookieValue)
          .toList();

      // `saveFromResponse` merges into whatever's already in the jar for
      // this host rather than blowing it away, so a response that only
      // re-sends one cookie (e.g. just the session id) won't drop others.
      await _cookieService.jar.saveFromResponse(uri, cookies);
    }

    if (response.statusCode == 401 || response.statusCode == 419) {
      final hasSession = await _tokenService.isSessionActive;

      if (hasSession) {
        final retryResponse = await _retryPolicy.run(
          uri.path,
          () => call().timeout(AppConstants.receiveTimeout),
        );

        return RawApiResponse(
          statusCode: retryResponse.statusCode,
          data: _tryDecode(retryResponse.body) ?? retryResponse.body,
          headers: retryResponse.headers,
        );
      }
    }

    // ✅ BUSINESS ERRORS
    if (response.statusCode == 409 || response.body.contains('4001')) {
      AppLogger.info('[BUSINESS CONFLICT] ${response.body}');
      return RawApiResponse(
        statusCode: response.statusCode,
        data: _tryDecode(response.body) ?? response.body,
        headers: response.headers,
      );
    }

    // ✅ 404 HANDLING
    if (response.statusCode == 404) {
      AppLogger.info('[404 ERROR] Endpoint not found');
      return RawApiResponse(
        statusCode: response.statusCode,
        data: _tryDecode(response.body) ?? response.body,
        headers: response.headers,
      );
    }

    // ✅ ERROR HANDLING
    if (response.statusCode >= 400) {
      // FIXED: 419 now routes through the same "session died" handler as
      // 401/403 -- see AuthFailureHandler.onUnauthorized, wired in
      // binding/app_binding.dart to AuthProvider.validateSessionOnUnauthorized.
      if (response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 419) {
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

  /// The backend sometimes leaks a PHP warning/notice (HTML like
  /// `<br />\n<b>Warning</b>: session_set_cookie_params(): ... <br />`)
  /// in front of the actual JSON payload. A strict `startsWith('{')`
  /// check rejects that whole response even though a valid JSON
  /// object/array is sitting right there in the string. Instead, find
  /// the outermost `{...}` or `[...]` in the body and decode just that
  /// slice. Returns null (never throws) if none is found.
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

  /// Multipart POST for endpoints that accept a binary field alongside
  /// plain form fields (e.g. `POST /api/employee/profile/photo`'s `photo`
  /// file / `remove_photo` flag). Kept separate from [post] because
  /// `http.MultipartRequest` needs its own request object — the `Content-
  /// Type: application/json` header [_headers] sets by default would be
  /// wrong here, so it's dropped in favor of the boundary header
  /// `MultipartRequest` sets itself. Goes through the same [_guard] (auth
  /// cookie handling, retry, error normalization) as every other verb.
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

      final request = http.MultipartRequest('POST', uri)..headers.addAll(headers);

      if (fields != null && fields.isNotEmpty) {
        request.fields.addAll(fields);
      }

      if (fileFieldName != null && fileBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(fileFieldName, fileBytes, filename: fileName ?? 'photo.jpg'),
        );
      }

      final streamedResponse = await _http.send(request);
      return http.Response.fromStream(streamedResponse);
    });
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