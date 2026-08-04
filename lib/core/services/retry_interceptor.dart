import 'dart:async';
import 'dart:io';

import 'package:Obecno/core/api/api_cancel_token.dart';
import 'package:Obecno/core/api/api_error.dart';
import 'package:Obecno/core/api/constants.dart';
import 'package:http/http.dart' as http;

import 'logger.dart';

class RetryPolicy {
  RetryPolicy({this.maxRetries = AppConstants.maxRetries});

  final int maxRetries;

  Future<T> run<T>(
    String path,
    Future<T> Function() request, {
    String? method,
    ApiCancelToken? cancelToken,
  }) async {
    var attempt = 0;

    while (true) {
      if (cancelToken?.isCancelled == true) {
        throw ApiError(
          type: ApiErrorType.cancelled,
          message: cancelToken?.reason ?? 'Request cancelled',
        );
      }

      try {
        return await request();
      } catch (e) {
        final isIdempotent = method == null || method.toUpperCase() == 'GET';
        if (!isIdempotent || !_shouldRetry(e) || attempt >= maxRetries) {
          rethrow;
        }

        attempt++;
        final delay =
            AppConstants.retryBaseDelay *
            (1 << (attempt - 1)); // exponential backoff
        AppLogger.info(
          'RetryPolicy: retry #$attempt for $path after ${delay.inMilliseconds}ms',
        );

        if (cancelToken == null) {
          await Future.delayed(delay);
          continue;
        }

        // Don't sleep out the full backoff after cancellation -- abandon
        // as soon as cancel() fires instead of waiting for the timer.
        final cancelledDuringWait = await Future.any([
          Future.delayed(delay, () => false),
          cancelToken.whenCancelled.then((_) => true),
        ]);
        if (cancelledDuringWait) {
          throw ApiError(
            type: ApiErrorType.cancelled,
            message: cancelToken.reason ?? 'Request cancelled',
          );
        }
      }
    }
  }

  bool _shouldRetry(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException;
  }
}
