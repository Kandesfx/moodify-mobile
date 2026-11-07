import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/player/data/playback_engine.dart';

void main() {
  group('resolveNotificationArtUri', () {
    final streamUri = Uri.parse('https://media.moodify.click/audio/track1.mp3');

    test('returns null when rawImage is null or empty', () {
      expect(resolveNotificationArtUri(streamUri, null), isNull);
      expect(resolveNotificationArtUri(streamUri, ''), isNull);
      expect(resolveNotificationArtUri(streamUri, '   '), isNull);
    });

    test('keeps absolute https and http URLs intact', () {
      const spotifyUrl =
          'https://i.scdn.co/image/ab67616d0000b27373af43a330332f0ad89d160b';
      expect(
        resolveNotificationArtUri(streamUri, spotifyUrl),
        Uri.parse(spotifyUrl),
      );

      const httpUrl = 'http://images.moodify.test/cover.jpg';
      expect(resolveNotificationArtUri(streamUri, httpUrl), Uri.parse(httpUrl));
    });

    test('preserves file scheme URIs for offline or cached artwork', () {
      const fileUrl = 'file:///data/user/0/dev.moodify/cache/art.jpg';
      expect(resolveNotificationArtUri(streamUri, fileUrl), Uri.parse(fileUrl));
    });

    test('resolves relative image paths against stream host', () {
      final resolved = resolveNotificationArtUri(
        streamUri,
        '/uploads/songs/artworks/10-ngan-nam.jpg',
      );
      expect(
        resolved,
        Uri.parse(
          'https://media.moodify.click/uploads/songs/artworks/10-ngan-nam.jpg',
        ),
      );
    });

    test('ignores invalid non-http/file schemes', () {
      expect(
        resolveNotificationArtUri(streamUri, 'javascript:void(0)'),
        isNull,
      );
    });
  });
}
