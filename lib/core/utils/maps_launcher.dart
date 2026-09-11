import 'package:url_launcher/url_launcher.dart';

class MapsLauncher {
  MapsLauncher._();

  /// URIs that drop a pin at [lat],[lon]. Never use navigation / directions
  /// schemes (`google.navigation`, `/maps/dir`, `daddr`) — those start routing.
  static List<Uri> pinUris({
    required double lat,
    required double lon,
    String? label,
  }) {
    final query = '$lat,$lon';
    final encoded = Uri.encodeComponent(query);
    final pinLabel = (label == null || label.trim().isEmpty)
        ? 'Location'
        : label.trim();
    final labeledQuery = Uri.encodeComponent('$query($pinLabel)');
    final encodedLabel = Uri.encodeComponent(pinLabel);

    return [
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': query,
      }),
      Uri.parse('geo:0,0?q=$labeledQuery'),
      Uri.parse('maps://?ll=$query&q=$encodedLabel'),
      Uri.parse('comgooglemaps://?q=$encoded&center=$query&zoom=16'),
      Uri.https('maps.apple.com', '/', {'ll': query, 'q': pinLabel}),
    ];
  }

  static Future<bool> open({
    required double lat,
    required double lon,
    String? label,
  }) async {
    final candidates = pinUris(lat: lat, lon: lon, label: label);
    final fallback = candidates.first;

    for (final uri in candidates) {
      if (await _tryLaunch(uri, LaunchMode.externalNonBrowserApplication)) {
        return true;
      }
      if (await _tryLaunch(uri, LaunchMode.externalApplication)) return true;
    }

    return _tryLaunch(fallback, LaunchMode.platformDefault);
  }

  static Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }
}
