import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:obecno/core/services/network_image_auth.dart';

/// Cache manager for avatars / location photos.
///
/// - Attaches the session Bearer token when available
/// - Refuses to cache HTML/JSON/plain error bodies as "images"
class ObecnoImageCache {
  ObecnoImageCache._();

  static const key = 'obecnoImageCache_v1';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 300,
      fileService: _ImageOnlyFileService(),
    ),
  );
}

class _ImageOnlyFileService extends FileService {
  _ImageOnlyFileService({http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final http.Client _client;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final merged = <String, String>{
      'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      ...?headers,
    };
    final auth = await NetworkImageAuth.headers();
    for (final entry in auth.entries) {
      merged.putIfAbsent(entry.key, () => entry.value);
    }

    final req = http.Request('GET', Uri.parse(url));
    req.headers.addAll(merged);
    final httpResponse = await _client.send(req);

    if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
      unawaited(_drain(httpResponse));
      throw HttpExceptionWithStatus(
        httpResponse.statusCode,
        'Image request failed (${httpResponse.statusCode}) for $url',
      );
    }

    final contentType = httpResponse.headers['content-type'] ?? '';
    final mime = contentType.split(';').first.trim().toLowerCase();
    if (!mime.startsWith('image/')) {
      unawaited(_drain(httpResponse));
      throw HttpExceptionWithStatus(
        httpResponse.statusCode,
        'Not an image (Content-Type: $contentType) for $url',
      );
    }

    return HttpGetResponse(httpResponse);
  }

  Future<void> _drain(http.StreamedResponse response) async {
    try {
      await response.stream.drain<void>();
    } catch (_) {}
  }
}
