import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/core/config/app_config.dart';
import 'package:moodify_flutter/core/errors/app_failure.dart';
import 'package:moodify_flutter/features/catalog/data/catalog_repository.dart';
import 'package:moodify_flutter/features/catalog/domain/catalog_models.dart';
import 'package:moodify_flutter/features/catalog/presentation/catalog_controller.dart';

import '../../support/auth_harness.dart';
import '../../support/music_harness.dart';

void main() {
  test(
    'mood results preserve limited matches and actual emotion without inventing tracks',
    () {
      final result = MoodResult.fromJson({
        'tracks': [],
        'matchStatus': 'LIMITED',
        'emotion': {'label': 'sadness'},
      });
      expect(result.tracks, isEmpty);
      expect(result.matchStatus, 'LIMITED');
      expect(result.emotion, 'sadness');
      expect(
        () => MoodResult.fromJson({'tracks': null}),
        throwsFormatException,
      );
    },
  );
  test(
    'track ids remain strings and audioUrl does not imply source availability',
    () {
      final track = Track.fromJson({
        'id': '123',
        'name': 'Test',
        'audioUrl': 'https://media.example.test/fallback.mp3',
      });
      expect(track.id, '123');
      expect(track.spotifyId, '123');
      expect(track.hasAudio, false);
    },
  );
  test('catalog and library use their actual different page envelopes', () {
    final page = TrackPage.fromJson({
      'tracks': [],
      'currentPage': 1,
      'totalPages': 3,
      'totalElements': 60,
    }, library: true);
    expect(page.page, 1);
    expect(page.hasMore, true);
    expect(() => TrackPage.fromJson({'tracks': []}), throwsFormatException);
  });
  test('stock album cover is removed and numeric id preserved', () {
    final album = MusicCollection.fromJson({
      'id': 42,
      'title': 'Album',
      'coverUrl':
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300',
    }, album: true);
    expect(album.id, '42');
    expect(album.image, isNull);
  });
  test(
    'pagination deduplicates without losing order and keeps list on next-page error',
    () async {
      final repository = MusicRepositoryFake();
      repository.onTracks = (page, _) async => page == 0
          ? const TrackPage([firstTrack], 0, 3, 3)
          : const TrackPage([firstTrack, secondTrack], 1, 3, 3);
      final controller = CatalogController(repository, allMusic);
      await controller.load();
      await controller.load();
      expect(controller.state.tracks.map((t) => t.id), [
        firstTrack.id,
        secondTrack.id,
      ]);
      repository.onTracks = (_, _) async =>
          throw const AppFailure('Unavailable');
      await controller.load();
      expect(controller.state.tracks.length, 2);
      expect(controller.state.nextPage, 2);
      expect(controller.state.failure, isNotNull);
      controller.dispose();
      repository.remote.dio.close();
    },
  );
  test('reset ignores a stale response from previous page load', () async {
    final repository = MusicRepositoryFake();
    final pending = Completer<TrackPage>();
    repository.onTracks = (_, _) => pending.future;
    final controller = CatalogController(repository, allMusic);
    final old = controller.load();
    repository.onTracks = (_, _) async =>
        const TrackPage([secondTrack], 0, 1, 1);
    await controller.load(reset: true);
    pending.complete(const TrackPage([firstTrack], 0, 1, 1));
    await old;
    expect(controller.state.tracks.single.id, secondTrack.id);
    controller.dispose();
    repository.remote.dio.close();
  });
  test(
    'stream refuses missing source and validates redirect without credentials',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/'));
      var calls = 0;
      dio.httpClientAdapter = TestAdapter((options) {
        calls++;
        expect(options.headers['Authorization'], isNull);
        expect(options.headers['Range'], 'bytes=0-0');
        expect(options.followRedirects, false);
        return ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['https://media.example.test/song.mp3'],
          },
        );
      });
      final repository = CatalogRepository(
        CatalogRemoteService(dio),
        AppConfig(apiBaseUrl: 'https://api.example.test/api'),
      );
      await expectLater(
        repository.stream(
          const Track(
            id: 'no-audio',
            spotifyId: 'n',
            name: 'No audio',
            artist: 'A',
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(calls, 0);
      expect((await repository.stream(firstTrack)).host, 'media.example.test');
      dio.httpClientAdapter = TestAdapter(
        (_) => ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['http://media.example.test/song.mp3'],
          },
        ),
      );
      await expectLater(
        repository.stream(firstTrack),
        throwsA(isA<AppFailure>()),
      );
      expect(repository.artwork('javascript:alert(1)'), isNull);
      expect(
        repository.artwork('/uploads/cover.jpg')!.path,
        '/uploads/cover.jpg',
      );
      dio.close();
    },
  );
}
