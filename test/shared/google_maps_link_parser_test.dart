import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/shared/bottom_sheets/location_sheet/google_maps_link_parser.dart';

void main() {
  group('GoogleMapsLinkParser', () {
    test('parses @lat,lng URLs', () async {
      const url =
          'https://www.google.com/maps/place/Office/@33.5714237,73.1442313,17z';
      final parsed = await GoogleMapsLinkParser.parseText(url);
      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(33.5714237, 0.0000001));
      expect(parsed.longitude, closeTo(73.1442313, 0.0000001));
      expect(parsed.label, 'Office');
    });

    test('parses query=lat,lng search links', () async {
      const url =
          'https://www.google.com/maps/search/?api=1&query=33.5714237,73.1442313';
      final parsed = await GoogleMapsLinkParser.parseText(url);
      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(33.5714237, 0.0000001));
      expect(parsed.longitude, closeTo(73.1442313, 0.0000001));
    });

    test('parses plain lat,lng text', () async {
      final parsed = await GoogleMapsLinkParser.parseText(
        'geo:52.4862,-1.8904',
      );
      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(52.4862, 0.0001));
      expect(parsed.longitude, closeTo(-1.8904, 0.0001));
    });
  });
}
