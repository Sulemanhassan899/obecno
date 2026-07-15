// import 'dart:convert';
// import 'dart:io';

// import 'package:Obecno/core/api/constants.dart';
// import 'package:Obecno/core/api/cookie_service.dart';
// import 'package:Obecno/core/api/session_cookie_store.dart';
// import 'package:Obecno/core/services/logger.dart';
// import 'package:Obecno/core/services/network_checker.dart';
// import 'package:http/http.dart' as http;

// class HttpApiClient {
//   HttpApiClient({
//     NetworkChecker? networkChecker,
//     SessionCookieStore? cookieStore,
//     String? baseUrl,
//     required CookieService cookieService,
//   }) : _networkChecker = networkChecker ?? NetworkCheckerImpl(),
//        _cookieStore = cookieStore ?? SessionCookieStore(),
//        _cookieService = cookieService,
//        _baseUrl = baseUrl ?? AppConstants.baseUrl;

//   final NetworkChecker _networkChecker;
//   final SessionCookieStore _cookieStore;
//   final CookieService _cookieService;
//   final String _baseUrl;

//   Future<Map<String, String>> _headers() async {
//     final headers = <String, String>{
//       'Content-Type': 'application/json',
//       'Accept': 'application/json',
//     };

//     final cookie = await _cookieStore.read();
//     if (cookie != null && cookie.isNotEmpty) {
//       headers['Cookie'] = cookie;
//     }

//     return headers;
//   }

//   Uri _resolve(String endpoint) {
//     final base = _baseUrl.endsWith('/')
//         ? _baseUrl.substring(0, _baseUrl.length - 1)
//         : _baseUrl;

//     final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
//     return Uri.parse('$base$path');
//   }

//   Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
//     if (!await _networkChecker.isConnected) {
//       throw const HttpApiClientException(
//         'No internet connection. Please check your network.',
//       );
//     }

//     final uri = _resolve(endpoint);
//     final headers = await _headers();

//     AppLogger.request('POST', uri.toString(), data: body);

//     late final http.Response response;
//     try {
//       response = await http
//           .post(uri, headers: headers, body: jsonEncode(body))
//           .timeout(AppConstants.receiveTimeout);
//     } catch (e) {
//       AppLogger.error('POST', uri.toString(), e);
//       throw HttpApiClientException(
//         'Something went wrong. Please try again.',
//         cause: e,
//       );
//     }

//     AppLogger.response(
//       'POST',
//       uri.toString(),
//       response.statusCode,
//       response.body,
//     );

//     // 🔥 CRITICAL FIX: Sync cookie to BOTH storage systems
//     final setCookie = response.headers['set-cookie'];

//     if (setCookie != null && setCookie.isNotEmpty) {
//       // 1️⃣ Save for http client (existing behavior)
//       await _cookieStore.save(setCookie);

//       // 2️⃣ ALSO save into Dio CookieService (THIS FIXES YOUR 401)
//       try {
//         final uri = Uri.parse(_baseUrl);

//         // A combined `set-cookie` string can hold several cookies joined by
//         // ",". Naively splitting on every "," also breaks the comma that
//         // appears *inside* an Expires date (e.g. "Expires=Thu, 21-Jul-2026
//         // ..."), producing a fragment like "...Expires=Thu" that
//         // Cookie.fromSetCookieValue rejects with "Invalid cookie date Thu".
//         //
//         // Only split on a "," that is followed by the start of a new
//         // "name=" pair (optionally preceded by whitespace). A comma inside
//         // "Thu, 21-Jul-2026" is followed by " 21-Jul-2026 ..." which has no
//         // "=" immediately after the token, so it's left alone.
//         final cookieParts = setCookie.split(RegExp(r',(?=\s*[^;=\s]+=)'));

//         final cookies = <Cookie>[];
//         for (final part in cookieParts) {
//           final trimmed = part.trim();
//           if (trimmed.isEmpty) continue;
//           try {
//             cookies.add(Cookie.fromSetCookieValue(trimmed));
//           } catch (e) {
//             // Don't let one malformed cookie discard all the others.
//             AppLogger.error('Cookie Parse Failed', trimmed, e);
//           }
//         }

//         if (cookies.isNotEmpty) {
//           await _cookieService.jar.saveFromResponse(uri, cookies);
//           AppLogger.info('Cookie synced to CookieService.jar');
//         }
//       } catch (e) {
//         AppLogger.error('Cookie Sync Failed', '', e);
//       }
//     }

//     return response;
//   }
// }

// class HttpApiClientException implements Exception {
//   const HttpApiClientException(this.message, {this.cause});

//   final String message;
//   final Object? cause;

//   @override
//   String toString() => 'HttpApiClientException: $message';
// }

import 'dart:convert';
import 'dart:io';

import 'package:Obecno/core/api/constants.dart';
import 'package:Obecno/core/api/cookie_service.dart';
import 'package:Obecno/core/api/session_cookie_store.dart';
import 'package:Obecno/core/services/logger.dart';
import 'package:Obecno/core/services/network_checker.dart';
import 'package:http/http.dart' as http;

class HttpApiClient {
  HttpApiClient({
    NetworkChecker? networkChecker,
    SessionCookieStore? cookieStore,
    String? baseUrl,
    required CookieService cookieService,
  }) : _networkChecker = networkChecker ?? NetworkCheckerImpl(),
       _cookieStore = cookieStore ?? SessionCookieStore(),
       _cookieService = cookieService,
       _baseUrl = baseUrl ?? AppConstants.baseUrl;

  final NetworkChecker _networkChecker;
  final SessionCookieStore _cookieStore;
  final CookieService _cookieService;
  final String _baseUrl;

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // ✅ Build the Cookie header from the parsed jar, not from the raw
    // `Set-Cookie` string in `_cookieStore`. A `Cookie:` request header
    // must only ever contain `name=value; name2=value2` pairs — the raw
    // stored string carries attributes like `Path=`, `HttpOnly`,
    // `Expires=...` which are invalid to echo back and can cause the
    // server to reject the session on a later request. `_cookieStore` is
    // still written on save() below for backwards compatibility/logout,
    // it's just no longer the source of truth for outgoing requests.
    final cookies = await _cookieService.jar.loadForRequest(
      Uri.parse(_baseUrl),
    );
    if (cookies.isNotEmpty) {
      headers['Cookie'] = cookies.map((c) => '${c.name}=${c.value}').join('; ');
    }

    return headers;
  }

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

    // 🔥 CRITICAL FIX: Sync cookie to BOTH storage systems
    final setCookie = response.headers['set-cookie'];

    if (setCookie != null && setCookie.isNotEmpty) {
      // 1️⃣ Save for http client (existing behavior)
      await _cookieStore.save(setCookie);

      // 2️⃣ ALSO save into Dio CookieService (THIS FIXES YOUR 401)
      try {
        final uri = Uri.parse(_baseUrl);

        // A combined `set-cookie` string can hold several cookies joined by
        // ",". Naively splitting on every "," also breaks the comma that
        // appears *inside* an Expires date (e.g. "Expires=Thu, 21-Jul-2026
        // ..."), producing a fragment like "...Expires=Thu" that
        // Cookie.fromSetCookieValue rejects with "Invalid cookie date Thu".
        //
        // Only split on a "," that is followed by the start of a new
        // "name=" pair (optionally preceded by whitespace). A comma inside
        // "Thu, 21-Jul-2026" is followed by " 21-Jul-2026 ..." which has no
        // "=" immediately after the token, so it's left alone.
        final cookieParts = setCookie.split(RegExp(r',(?=\s*[^;=\s]+=)'));

        final cookies = <Cookie>[];
        for (final part in cookieParts) {
          final trimmed = part.trim();
          if (trimmed.isEmpty) continue;
          try {
            cookies.add(Cookie.fromSetCookieValue(trimmed));
          } catch (e) {
            // Don't let one malformed cookie discard all the others.
            AppLogger.error('Cookie Parse Failed', trimmed, e);
          }
        }

        if (cookies.isNotEmpty) {
          await _cookieService.jar.saveFromResponse(uri, cookies);
          AppLogger.info('Cookie synced to CookieService.jar');
        }
      } catch (e) {
        AppLogger.error('Cookie Sync Failed', '', e);
      }
    }

    return response;
  }
}

class HttpApiClientException implements Exception {
  const HttpApiClientException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'HttpApiClientException: $message';
}
