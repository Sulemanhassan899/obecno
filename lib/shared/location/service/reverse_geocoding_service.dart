import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

abstract class ReverseGeocodingService {
  Future<String?> resolve({required double lat, required double lon});
}

class ReverseGeocodingServiceImpl implements ReverseGeocodingService {
  ReverseGeocodingServiceImpl({http.Client? client})
    : _client = client ?? http.Client();

  static final ReverseGeocodingServiceImpl instance =
      ReverseGeocodingServiceImpl();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 6);
  final Map<String, String?> _cache = {};

  String _cacheKey(double lat, double lon) =>
      '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';

  @override
  Future<String?> resolve({required double lat, required double lon}) async {
    final key = _cacheKey(lat, lon);
    if (_cache.containsKey(key)) return _cache[key];

    try {
      var name = await _lookup(lat, lon).timeout(_timeout);

      if (name != null && !_isEnglishSafe(name)) {
        name = await _translateToEnglish(name).timeout(_timeout);
      }

      _cache[key] = name;
      return name;
    } catch (e, st) {
      debugPrint('[ReverseGeocodingService] resolve failed: $e\n$st');
      _cache[key] = null;
      return null;
    }
  }

  Future<String?> _lookup(double lat, double lon) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': '$lat',
      'lon': '$lon',
      'zoom': '16',
      'accept-language': 'en',
    });

    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent': 'Obecno-Attendance-App/1.0 (reverse-geocode)',
        'Accept-Language': 'en',
      },
    );

    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;

    final address = decoded['address'];
    if (address is Map) {
      final parts = <String>[
        for (final key in [
          'suburb',
          'neighbourhood',
          'city_district',
          'city',
          'town',
          'village',
          'state',
        ])
          if (address[key] is String &&
              (address[key] as String).trim().isNotEmpty)
            (address[key] as String).trim(),
      ];

      if (parts.isNotEmpty) {
        final seen = <String>{};
        final picked = <String>[];
        for (final part in parts) {
          if (seen.add(part)) picked.add(part);
          if (picked.length == 2) break;
        }
        return picked.join(', ');
      }
    }

    final displayName = decoded['display_name'];
    if (displayName is String && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    return null;
  }

  Future<String?> _translateToEnglish(String text) async {
    try {
      final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
        'client': 'gtx',
        'sl': 'auto',
        'tl': 'en',
        'dt': 't',
        'q': text,
      });

      final response = await _client.get(uri);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List || decoded.isEmpty || decoded[0] is! List) {
        return null;
      }

      final buffer = StringBuffer();
      for (final segment in decoded[0] as List) {
        if (segment is List && segment.isNotEmpty && segment[0] is String) {
          buffer.write(segment[0] as String);
        }
      }

      final translated = buffer.toString().trim();
      if (translated.isEmpty || !_isEnglishSafe(translated)) return null;
      return translated;
    } catch (e, st) {
      debugPrint('[ReverseGeocodingService] translate failed: $e\n$st');
      return null;
    }
  }

  static final RegExp _nonLatinScript = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F' // Arabic & Urdu
    r'\u0900-\u097F' // Devanagari
    r'\u0980-\u09FF' // Bengali
    r'\u4E00-\u9FFF' // CJK
    r'\u3040-\u30FF' // Hiragana/Katakana
    r'\u0400-\u04FF' // Cyrillic
    r'\u0E00-\u0E7F]', // Thai
  );

  bool _isEnglishSafe(String text) => !_nonLatinScript.hasMatch(text);
}
