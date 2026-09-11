import 'package:flutter_test/flutter_test.dart';
import 'package:obecno/core/utils/maps_launcher.dart';

void main() {
  group('MapsLauncher.pinUris', () {
    test('opens a pin, not turn-by-turn directions', () {
      final uris = MapsLauncher.pinUris(
        lat: 37.4219983,
        lon: -122.084,
        label: 'islamabad blue area',
      );

      expect(uris, isNotEmpty);
      expect(uris.first.path, '/maps/search/');
      expect(uris.first.queryParameters['query'], '37.4219983,-122.084');

      for (final uri in uris) {
        final value = uri.toString();
        expect(uri.scheme, isNot('google.navigation'));
        expect(value, isNot(contains('/maps/dir')));
        expect(value, isNot(contains('daddr=')));
        expect(value, isNot(contains('saddr=')));
        expect(value, isNot(contains('navigation')));
      }
    });
  });
}
