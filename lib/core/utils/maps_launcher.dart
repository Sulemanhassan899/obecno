import 'package:url_launcher/url_launcher.dart';

class MapsLauncher {
  MapsLauncher._();

  static Future<bool> open({required double lat, required double lon}) async {
    final query = '$lat,$lon';
    final encoded = Uri.encodeComponent(query);
    final web = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });

    final candidates = <Uri>[
      Uri.parse('comgooglemaps://?q=$encoded&center=$query'),
      Uri.parse('maps://?ll=$query&q=$encoded'),
      Uri.parse('google.navigation:q=$encoded'),
      Uri.parse('geo:$query?q=$encoded'),
      Uri.https('maps.google.com', '/', {'q': query}),
      web,
    ];

    for (final uri in candidates) {
      if (await _tryLaunch(uri, LaunchMode.externalNonBrowserApplication)) {
        return true;
      }
      if (await _tryLaunch(uri, LaunchMode.externalApplication)) return true;
    }

    return _tryLaunch(web, LaunchMode.platformDefault);
  }

  static Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }
}
