import 'package:http/http.dart' as http;

/// Extracts lat/lng from Google Maps share / copy links.
class GoogleMapsLinkParser {
  GoogleMapsLinkParser._();

  static final _urlPattern = RegExp(
    r'https?:\/\/(?:maps\.app\.goo\.gl|goo\.gl\/maps|maps\.google\.[^\s]+|www\.google\.[^\s]*\/maps)[^\s]*',
    caseSensitive: false,
  );

  static final _coordPatterns = <RegExp>[
    RegExp(r'@(-?\d+\.?\d*),\s*(-?\d+\.?\d*)'),
    RegExp(r'!3d(-?\d+\.?\d*)!4d(-?\d+\.?\d*)'),
    RegExp(r'[?&](?:q|query|ll)=(-?\d+\.?\d*),\s*(-?\d+\.?\d*)'),
    RegExp(r'/search/(-?\d+\.?\d*),\+?(-?\d+\.?\d*)'),
    RegExp(r'geo:(-?\d+\.?\d*),(-?\d+\.?\d*)'),
    RegExp(r'destination=(-?\d+\.?\d*),(-?\d+\.?\d*)'),
  ];

  static final _placeNamePattern = RegExp(r'/maps/place/([^/@]+)');

  /// Returns coordinates parsed from free-form clipboard/share text.
  static Future<GoogleMapsParsedLocation?> parseText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final direct = _coordsFrom(text);
    if (direct != null) {
      return GoogleMapsParsedLocation(
        latitude: direct.$1,
        longitude: direct.$2,
        label: _placeNameFrom(text),
        sourceUrl: _firstUrl(text),
      );
    }

    final url = _firstUrl(text);
    if (url == null) return null;

    final expanded = await _expandIfNeeded(url);
    final coords = _coordsFrom(expanded) ?? _coordsFrom(url);
    if (coords == null) return null;

    return GoogleMapsParsedLocation(
      latitude: coords.$1,
      longitude: coords.$2,
      label: _placeNameFrom(expanded) ?? _placeNameFrom(url),
      sourceUrl: expanded,
    );
  }

  static bool looksLikeMapsLink(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return false;
    if (_coordsFrom(text) != null) return true;
    return _firstUrl(text) != null;
  }

  static String? _firstUrl(String text) {
    final match = _urlPattern.firstMatch(text);
    return match?.group(0);
  }

  static String? _placeNameFrom(String text) {
    final match = _placeNamePattern.firstMatch(text);
    if (match == null) return null;
    final raw = match.group(1);
    if (raw == null || raw.isEmpty) return null;
    return Uri.decodeComponent(raw.replaceAll('+', ' ')).trim();
  }

  static (double, double)? _coordsFrom(String text) {
    for (final pattern in _coordPatterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final lat = double.tryParse(match.group(1) ?? '');
      final lng = double.tryParse(match.group(2) ?? '');
      if (lat == null || lng == null) continue;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
      return (lat, lng);
    }
    return null;
  }

  static Future<String> _expandIfNeeded(String url) async {
    final lower = url.toLowerCase();
    final isShort =
        lower.contains('maps.app.goo.gl') || lower.contains('goo.gl/maps');
    if (!isShort) return url;

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: const {
              'User-Agent': 'Obecno-Attendance-App/1.0 (maps-link)',
              'Accept-Language': 'en',
            },
          )
          .timeout(const Duration(seconds: 8));
      final finalUrl = response.request?.url.toString();
      if (finalUrl != null && finalUrl.isNotEmpty) return finalUrl;
      // Some short links expose coords only after redirect chain in body/@.
      if (_coordsFrom(response.body) != null) return response.body;
    } catch (_) {}
    return url;
  }
}

class GoogleMapsParsedLocation {
  const GoogleMapsParsedLocation({
    required this.latitude,
    required this.longitude,
    this.label,
    this.sourceUrl,
  });

  final double latitude;
  final double longitude;
  final String? label;
  final String? sourceUrl;
}
