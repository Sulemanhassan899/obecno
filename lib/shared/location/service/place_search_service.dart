import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  final String displayName;
  final double lat;
  final double lon;
}

/// Forward geocoding via Nominatim (same provider as reverse geocoding).
class PlaceSearchService {
  PlaceSearchService({http.Client? client}) : _client = client ?? http.Client();

  static final PlaceSearchService instance = PlaceSearchService();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 8);

  Future<List<PlaceSearchResult>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'q': q,
        'limit': '8',
        'addressdetails': '1',
        'accept-language': 'en',
      });

      final response = await _client
          .get(
            uri,
            headers: const {
              'User-Agent': 'Obecno-Attendance-App/1.0 (place-search)',
              'Accept-Language': 'en',
            },
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map((item) {
            final lat = double.tryParse('${item['lat']}');
            final lon = double.tryParse('${item['lon']}');
            final name = (item['display_name'] as String?)?.trim();
            if (lat == null || lon == null || name == null || name.isEmpty) {
              return null;
            }
            return PlaceSearchResult(displayName: name, lat: lat, lon: lon);
          })
          .whereType<PlaceSearchResult>()
          .toList();
    } catch (e, st) {
      debugPrint('[PlaceSearchService] search failed: $e\n$st');
      return const [];
    }
  }
}
