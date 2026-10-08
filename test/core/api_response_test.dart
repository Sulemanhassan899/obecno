import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/api/api_response.dart';

void main() {
  group('ApiResponse.isHttpOk', () {
    test('is false when success is false even with 2xx status', () {
      const response = ApiResponse<bool>(
        success: false,
        statusCode: 200,
      );
      expect(response.isHttpOk, isFalse);
    });

    test('is false when success is true with 404 status', () {
      const response = ApiResponse<bool>(
        success: true,
        statusCode: 404,
      );
      expect(response.isHttpOk, isFalse);
    });

    test('is true when success is true with 2xx status', () {
      const response = ApiResponse<bool>(
        success: true,
        statusCode: 200,
      );
      expect(response.isHttpOk, isTrue);
    });
  });
}
