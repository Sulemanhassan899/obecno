import 'dart:convert';

import 'package:Obecno/core/api/constants.dart';
import 'package:flutter/foundation.dart';

/// Dependency-free logger for the API layer.
///
/// Uses [debugPrint] (not just `dart:developer`'s `log`) so every request,
/// response, and error shows up directly in the plain `flutter run` /
/// terminal console, not only in DevTools. Kept as its own class (rather
/// than the `logger` package) to avoid an extra dependency in a "core"
/// layer that every module imports.
class AppLogger {
  AppLogger._();

  static bool _enabled = AppConstants.enableApiLogging;

  /// Allows runtime toggling, e.g. disabling logs after login in a
  /// screen-recorded demo, or enabling verbose logs from a debug menu.
  static void setEnabled(bool value) => _enabled = value;

  static void request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParams,
  }) {
    if (!_enabled) return;
    _printBlock('➡️ REQUEST', '$method $path', {
      if (queryParams != null && queryParams.isNotEmpty) 'query': queryParams,
      if (data != null) 'body': data,
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
      'data': _truncate(data),
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

    // debugPrint chunks long strings automatically so nothing gets
    // truncated by the platform's line-length limits, unlike a raw print().
    debugPrint(buffer.toString());
  }

  /// Avoids flooding logs with huge payloads (file uploads, big lists).
  static dynamic _truncate(dynamic data) {
    final str = data.toString();
    if (str.length <= 2000) return data;
    return '${str.substring(0, 2000)}... [truncated ${str.length - 2000} chars]';
  }
}
