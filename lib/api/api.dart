import 'dart:convert';

import 'package:Obecno/api/constants.dart';
import 'package:Obecno/api/cookie_service.dart';
import 'package:Obecno/api/session_cookie_store.dart';
import 'package:Obecno/core/services/logger.dart';
import 'package:Obecno/core/services/network_checker.dart';
import 'package:http/http.dart' as http;

/// Lightweight `package:http` client used ONLY by the auth module's
/// `AuthRepository`.
///
/// FIXED (this file used to be named `ApiClient`, same as the Dio class in
/// `api_client.dart`):
///  - Renamed to `HttpApiClient`. Two top-level classes both called
///    `ApiClient` in the same folder is a compile hazard the moment any
///    file needs both — the Dio one stays exactly as-is for every other
///    module (attendance, employee, ...), this one only serves auth.
///  - `baseUrl` no longer hardcoded to `"https://app.obecno.com/"` — it
///    now reads `AppConstants.baseUrl`, same source of truth the Dio
///    client uses, so the two never silently diverge.
///  - Session cookie is now actually read/attached and captured, per the
///    cookie-session auth rule (previously this file didn't touch cookies
///    at all).
///  - Logging goes through `AppLogger` instead of raw `debugPrint`, so it
///    respects `AppConstants.enableApiLogging` like the rest of the app.
class HttpApiClient {
  HttpApiClient({
    NetworkChecker? networkChecker,
    SessionCookieStore? cookieStore,
    String? baseUrl,
    required CookieService cookieService,
  }) : _networkChecker = networkChecker ?? NetworkCheckerImpl(),
       _cookieStore = cookieStore ?? SessionCookieStore(),
       _baseUrl = baseUrl ?? AppConstants.baseUrl;

  final NetworkChecker _networkChecker;
  final SessionCookieStore _cookieStore;
  final String _baseUrl;

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json', // missing this caused HTML responses before
    };
    final cookie = await _cookieStore.read();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  /// baseUrl + endpoint, without ever producing a double slash.
  Uri _resolve(String endpoint) {
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$base$path');
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    if (!await _networkChecker.isConnected) {
      throw const HttpApiClientException(
        'No internet connection. Please check your network.',
      );
    }

    final uri = _resolve(endpoint);
    final headers = await _headers();

    AppLogger.request('POST', uri.toString(), data: body);

    late final http.Response response;
    try {
      response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(AppConstants.receiveTimeout);
    } catch (e) {
      AppLogger.error('POST', uri.toString(), e);
      throw HttpApiClientException(
        'Something went wrong. Please try again.',
        cause: e,
      );
    }

    AppLogger.response(
      'POST',
      uri.toString(),
      response.statusCode,
      response.body,
    );

    // Capture any session cookie the backend set, so the *next* call
    // (handled entirely here — repositories never touch cookies directly)
    // is authenticated.
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      await _cookieStore.save(setCookie);
    }

    return response;
  }
}

/// Thrown for transport-level failures (no connection, timeout) before a
/// response is even available. Status-code/JSON-shape failures are
/// handled by `AuthRepository`, not here.
class HttpApiClientException implements Exception {
  const HttpApiClientException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'HttpApiClientException: $message';
}
