import 'dart:async';
import 'dart:io';

import 'package:obecno/core/api/api_cancel_token.dart';
import 'package:obecno/core/api/api_error.dart';
import 'package:obecno/core/services/retry_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RetryPolicy', () {
    test('retries GET on SocketException then succeeds', () async {
      var attempts = 0;
      final policy = RetryPolicy(maxRetries: 3);

      final result = await policy.run(
        '/ping',
        () async {
          attempts++;
          if (attempts < 3) throw const SocketException('down');
          return 'ok';
        },
        method: 'GET',
      );

      expect(result, 'ok');
      expect(attempts, 3);
    });

    test('never retries POST', () async {
      var attempts = 0;
      final policy = RetryPolicy(maxRetries: 5);

      await expectLater(
        () => policy.run(
          '/employee/attendance',
          () async {
            attempts++;
            throw TimeoutException('slow');
          },
          method: 'POST',
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(attempts, 1);
    });

    test('respects cancel token before attempt', () async {
      final token = ApiCancelToken();
      token.cancel('stop');
      final policy = RetryPolicy(maxRetries: 3);

      await expectLater(
        () => policy.run(
          '/x',
          () async => 'never',
          method: 'GET',
          cancelToken: token,
        ),
        throwsA(
          isA<ApiError>().having(
            (e) => e.type,
            'type',
            ApiErrorType.cancelled,
          ),
        ),
      );
    });
  });
}
