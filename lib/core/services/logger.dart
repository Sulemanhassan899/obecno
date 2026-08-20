import 'dart:convert';

import 'package:Obecno/core/api/constants.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  /// Release builds never log unless [AppConstants.enableApiLogging] is forced
  /// via `--dart-define=OBECNO_DEBUG_LOGS=true` *and* we are in debug/profile.
  static bool _enabled =
      AppConstants.enableApiLogging && !kReleaseMode;

  static bool get isEnabled => _enabled;

  static void setEnabled(bool value) => _enabled = value && !kReleaseMode;

  static const _sensitiveKeys = {
    'password',
    'current_password',
    'new_password',
    'new_password_confirm',
    'access_token',
    'refresh_token',
    'token',
    'authorization',
    'lat',
    'lon',
    'latitude',
    'longitude',
    'lat_lon',
    'latlon',
  };

  static void request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParams,
  }) {
    if (!_enabled) return;
    _printBlock('➡️ REQUEST', '$method $path', {
      if (queryParams != null && queryParams.isNotEmpty)
        'query': redact(queryParams),
      if (data != null) 'body': redact(data),
    });
  }

  static void response(
    String method,
    String path,
    int? statusCode,
    dynamic data,
  ) {
    if (!_enabled) return;
    _printBlock('✅ RESPONSE', '$method $path [$statusCode]', {
      'data': _truncate(redact(data)),
    });
  }

  static void error(
    String method,
    String path,
    Object error, {
    StackTrace? stackTrace,
  }) {
    if (!_enabled) return;
    _printBlock(
      '❌ ERROR',
      '$method $path -> $error',
      stackTrace != null ? {'stackTrace': stackTrace.toString()} : null,
    );
  }

  static void info(String message) {
    if (!_enabled) return;
    debugPrint('ℹ️ [ObecnoAPI] $message');
  }

  /// Redacts passwords, tokens, and coordinates from log payloads.
  /// Exposed for unit tests.
  static dynamic redact(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      return data.map((key, value) {
        final k = key.toString().toLowerCase();
        if (_sensitiveKeys.contains(k) ||
            k.contains('password') ||
            k.contains('token') ||
            k == 'authorization') {
          return MapEntry(key, '***');
        }
        return MapEntry(key, redact(value));
      });
    }
    if (data is List) {
      return data.map(redact).toList();
    }
    if (data is String) {
      var s = data;
      if (s.toLowerCase().startsWith('bearer ')) {
        return 'Bearer ***';
      }
      return s;
    }
    return data;
  }

  static void _printBlock(
    String tag,
    String message,
    Map<String, dynamic>? extra,
  ) {
    final buffer = StringBuffer()
      ..writeln('')
      ..writeln('=========== $tag ===========')
      ..writeln(message);

    if (extra != null && extra.isNotEmpty) {
      try {
        buffer.writeln(const JsonEncoder.withIndent('  ').convert(extra));
      } catch (_) {
        buffer.writeln(extra.toString());
      }
    }
    buffer.writeln('=====================================');

    debugPrint(buffer.toString());
  }

  static dynamic _truncate(dynamic data) {
    final str = data.toString();
    if (str.length <= 2000) return data;
    return '${str.substring(0, 2000)}... [truncated ${str.length - 2000} chars]';
  }
}
