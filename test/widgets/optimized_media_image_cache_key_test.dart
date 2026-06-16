import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirror of OptimizedMediaImage._generateCacheKey for unit testing.
///
/// Kept in sync with the production implementation so we can verify
/// endpoint-stability without widget plumbing.
String generateCacheKey(String imageUrl) {
  try {
    final uri = Uri.parse(imageUrl);
    final query = uri.queryParameters;
    final innerUrl = query['url'];
    if (innerUrl != null) {
      final w = query['width'] ?? '';
      final h = query['height'] ?? '';
      return 'plex_optimized_${sha1.convert(utf8.encode('$innerUrl|$w|$h'))}';
    }
    return 'plex_optimized_${sha1.convert(utf8.encode('${uri.path}?${uri.query}'))}';
  } catch (_) {
    return 'plex_optimized_${sha1.convert(utf8.encode(imageUrl))}';
  }
}

void main() {
  group('_generateCacheKey endpoint-independence', () {
    test('Plex transcode URLs with different base URLs produce the same key', () {
      const endpointA =
          'https://192-168-1-100.plex.direct:32400/photo/:/transcode?width=400&height=600&minSize=1&upscale=1'
          '&url=%2Flibrary%2Fmetadata%2F123%2Fthumb%2F456%3FX-Plex-Token%3Dabc&X-Plex-Token=abc';
      const endpointB =
          'https://10-0-0-50.plex.direct:32400/photo/:/transcode?width=400&height=600&minSize=1&upscale=1'
          '&url=%2Flibrary%2Fmetadata%2F123%2Fthumb%2F456%3FX-Plex-Token%3Dabc&X-Plex-Token=abc';

      expect(generateCacheKey(endpointA), equals(generateCacheKey(endpointB)));
    });

    test('Plex transcode URLs with different images produce different keys', () {
      const imageA =
          'https://192-168-1-100.plex.direct:32400/photo/:/transcode?width=400&height=600&minSize=1&upscale=1'
          '&url=%2Flibrary%2Fmetadata%2F123%2Fthumb%2F456%3FX-Plex-Token%3Dabc&X-Plex-Token=abc';
      const imageB =
          'https://192-168-1-100.plex.direct:32400/photo/:/transcode?width=400&height=600&minSize=1&upscale=1'
          '&url=%2Flibrary%2Fmetadata%2F999%2Fthumb%2F789%3FX-Plex-Token%3Dabc&X-Plex-Token=abc';

      expect(generateCacheKey(imageA), isNot(equals(generateCacheKey(imageB))));
    });

    test('Plex transcode URLs with different dimensions produce different keys', () {
      const small =
          'https://server.plex.direct:32400/photo/:/transcode?width=200&height=300&minSize=1&upscale=1'
          '&url=%2Flibrary%2Fmetadata%2F123%2Fthumb%2F456%3FX-Plex-Token%3Dabc&X-Plex-Token=abc';
      const large =
          'https://server.plex.direct:32400/photo/:/transcode?width=400&height=600&minSize=1&upscale=1'
          '&url=%2Flibrary%2Fmetadata%2F123%2Fthumb%2F456%3FX-Plex-Token%3Dabc&X-Plex-Token=abc';

      expect(generateCacheKey(small), isNot(equals(generateCacheKey(large))));
    });

    test('Non-transcode Plex URLs with different base URLs produce the same key', () {
      const endpointA =
          'https://192-168-1-100.plex.direct:32400/library/metadata/123/thumb/456?X-Plex-Token=abc';
      const endpointB =
          'https://10-0-0-50.plex.direct:32400/library/metadata/123/thumb/456?X-Plex-Token=abc';

      expect(generateCacheKey(endpointA), equals(generateCacheKey(endpointB)));
    });

    test('Jellyfin URLs with same path produce the same key regardless of host', () {
      const hostA =
          'https://jellyfin-a.local:8096/Items/abc/Images/Primary?maxWidth=400&maxHeight=600&api_key=xyz';
      const hostB =
          'https://jellyfin-b.local:8096/Items/abc/Images/Primary?maxWidth=400&maxHeight=600&api_key=xyz';

      expect(generateCacheKey(hostA), equals(generateCacheKey(hostB)));
    });

    test('cache key starts with expected prefix', () {
      const url =
          'https://server:32400/photo/:/transcode?width=400&height=600&url=%2Fthumb%2F1&X-Plex-Token=t';
      expect(generateCacheKey(url), startsWith('plex_optimized_'));
    });
  });
}
