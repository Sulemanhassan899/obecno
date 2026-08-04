import 'dart:convert';

import 'package:Obecno/core/api/constants.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static bool _enabled = AppConstants.enableApiLogging;

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

    debugPrint(buffer.toString());
  }

  static dynamic _truncate(dynamic data) {
    final str = data.toString();
    if (str.length <= 2000) return data;
    return '${str.substring(0, 2000)}... [truncated ${str.length - 2000} chars]';
  }
}
