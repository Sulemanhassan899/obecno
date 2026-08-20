import 'package:Obecno/shared/location/service/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Location exceptions', () {
    test('MockLocationDetectedException message', () {
      expect(
        const MockLocationDetectedException().toString(),
        contains('mock'),
      );
    });

    test('accuracy exception includes meters', () {
      expect(
        const LocationAccuracyTooLowException(120).toString(),
        contains('120'),
      );
    });

    test('max acceptable accuracy is 50m', () {
      expect(LocationServiceImpl.maxAcceptableAccuracyMeters, 50);
    });
  });
}
