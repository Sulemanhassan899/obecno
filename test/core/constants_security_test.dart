import 'package:Obecno/core/api/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API logging is off by default', () {
    expect(AppConstants.enableApiLogging, isFalse);
  });

  test('base URL is https', () {
    expect(AppConstants.baseUrl.startsWith('https://'), isTrue);
  });
}
