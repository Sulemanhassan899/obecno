import 'dart:async';
import 'dart:io';

import 'package:Obecno/api/constants.dart';

import 'logger.dart';

/// Retries idempotent, connectivity-related failures (timeouts, dropped
/// connections) up to [maxRetries] times with exponential backoff.
/// Deliberately does NOT retry on 4xx/5xx server responses — those are
/// application-level failures, not transient network blips, and
/// blind-retrying a POST on a 500 can duplicate side effects.
///
/// Rewritten from the old Dio `RetryInterceptor`: there's no
/// interceptor chain with `package:http`, so `ApiClient` wraps each call
/// with [run] directly instead of Dio re-entering the same client on
/// error.
class RetryPolicy {
  RetryPolicy({this.maxRetries = AppConstants.maxRetries});

  final int maxRetries;

  Future<T> run<T>(String path, Future<T> Function() request) async {
    var attempt = 0;

    while (true) {
      try {
        return await request();
      } catch (e) {
        if (!_shouldRetry(e) || attempt >= maxRetries) rethrow;

        attempt++;
        final delay = AppConstants.retryBaseDelay * (1 << (attempt - 1)); // exponential backoff
        AppLogger.info('RetryPolicy: retry #$attempt for $path after ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
      }
    }
  }

  bool _shouldRetry(Object error) {
    return error is SocketException || error is TimeoutException;
  }
}
