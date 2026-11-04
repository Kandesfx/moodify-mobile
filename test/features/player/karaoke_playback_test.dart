import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as audio;
import 'package:moodify_flutter/features/karaoke/data/karaoke_playback.dart';
import 'package:moodify_flutter/features/catalog/domain/catalog_models.dart';
import 'package:moodify_flutter/features/player/data/listening_reporter.dart';
import 'package:moodify_flutter/features/player/data/playback_engine.dart';
import 'package:moodify_flutter/features/player/presentation/player_controller.dart';

import '../../support/music_harness.dart';

const _karaokeTrack = {
  'songId': 'karaoke-song',
  'title': 'Test instrumental',
  'artist': 'Test artist',
  'durationMs': 120000,
  'instrumentalUrl': 'https://moodify.click/instrumentals/song.mp3',
};

class _RecordingEngine extends PlaybackEngineFake {
  final sources = <Uri>[];
  bool failNextLoad = false;

  @override
  Future<void> load(Uri uri, Track track) async {
    sources.add(uri);
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('Source unavailable');
    }
    await super.load(uri, track);
  }
}

void main() {
  late MusicRepositoryFake repository;
  late _RecordingEngine engine;
  late PlayerController player;
  late KaraokePlayback karaoke;
  late List<ListeningEvent> telemetry;
  var engineCreations = 0;

  setUp(() {
    repository = MusicRepositoryFake();
    engine = _RecordingEngine();
    telemetry = [];
    engineCreations = 0;
    player = PlayerController(repository, () async {
      engineCreations++;
      return engine;
    }, report: telemetry.add);
    karaoke = KaraokePlayback(player);
  });
  tearDown(() async {
    player.dispose();
    await flushMusic();
    repository.remote.dio.close();
  });

  test(
    'music and karaoke share engine, OS commands and actual progress',
    () async {
      await player.select([firstTrack, secondTrack], 0);
      player.cycleRepeat();
      final musicEvents = telemetry.length;
      repository.onTrack = (_) async => throw StateError('No catalog fallback');
      await karaoke.loadTrack(_karaokeTrack);
      expect(engineCreations, 1);
      expect(engine.loaded, [firstTrack.id, 'karaoke-song']);
      expect(karaoke.playing, false);
      await engine.commands!.play();
      engine.controller.add(
        const EngineEvent(
          playing: true,
          position: Duration(seconds: 8),
          duration: Duration(minutes: 2),
        ),
      );
      expect(karaoke.playing, true);
      expect(karaoke.position, const Duration(seconds: 8));
      await engine.commands!.pause();
      expect(karaoke.playing, false);
      engine.controller.add(
        const EngineEvent(
          completed: true,
          position: Duration(minutes: 2),
          duration: Duration(minutes: 2),
        ),
      );
      await flushMusic();
      expect(karaoke.processingState, audio.ProcessingState.completed);
      expect(engine.loaded, hasLength(2));
      expect(
        telemetry.skip(musicEvents).every((e) => e.source != 'KARAOKE'),
        true,
      );
    },
  );

  test(
    'failed karaoke load retries its instrumental, never the music catalog',
    () async {
      repository.onTrack = (_) async => throw StateError('No catalog fallback');
      engine.failNextLoad = true;
      await expectLater(karaoke.loadTrack(_karaokeTrack), throwsA(isNotNull));
      await karaoke.play();
      expect(engine.sources.map((e) => e.toString()), [
        _karaokeTrack['instrumentalUrl'],
        _karaokeTrack['instrumentalUrl'],
      ]);
      expect(karaoke.playing, true);
      expect(engineCreations, 1);
      expect(telemetry, isEmpty);
    },
  );

  test(
    'return to music and late karaoke stop cannot clear the new queue',
    () async {
      await karaoke.loadTrack(_karaokeTrack);
      await karaoke.play();
      await player.select([firstTrack], 0);
      await karaoke.stop();
      expect(player.current.track?.id, firstTrack.id);
      expect(player.current.playing, true);
      expect(karaoke.playing, false);
      expect(engineCreations, 1);
      await player.clear();
      expect(karaoke.processingState, audio.ProcessingState.idle);
      expect(player.current.queue, isEmpty);
    },
  );

  for (final failed in [false, true]) {
    test(
      'OS play keeps karaoke controls after ${failed ? 'failure' : 'completion'}',
      () async {
        await karaoke.loadTrack(_karaokeTrack);
        await karaoke.play();
        engine.controller.add(
          EngineEvent(
            failed: failed,
            completed: !failed,
            position: const Duration(minutes: 2),
            duration: const Duration(minutes: 2),
          ),
        );
        await flushMusic();
        await engine.commands!.play();
        expect(karaoke.playing, true);
        expect(karaoke.processingState, audio.ProcessingState.ready);
        expect(engine.sources, hasLength(2));
        expect(engineCreations, 1);
        await karaoke.seek(const Duration(seconds: 10));
        expect(engine.sought, const Duration(seconds: 10));
        await karaoke.stop();
        expect(player.current.queue, isEmpty);
      },
    );
  }

  test(
    'a previous karaoke screen cannot stop or seek the next performance',
    () async {
      await karaoke.loadTrack(_karaokeTrack);
      final nextPerformance = KaraokePlayback(player);
      await nextPerformance.loadTrack(_karaokeTrack);
      await nextPerformance.play();
      await karaoke.stop();
      await karaoke.seek(const Duration(seconds: 90));
      expect(nextPerformance.playing, true);
      expect(karaoke.playing, false);
      expect(engine.sought, Duration.zero);
      expect(engineCreations, 1);
    },
  );

  test('rejected source cannot take ownership of active karaoke', () async {
    await karaoke.loadTrack(_karaokeTrack);
    await karaoke.play();
    final rejected = KaraokePlayback(player);
    await expectLater(
      rejected.loadTrack({
        ..._karaokeTrack,
        'instrumentalUrl': 'https://example.test/song.mp3',
      }),
      throwsA(isNotNull),
    );
    await rejected.stop();
    await rejected.seek(const Duration(seconds: 90));
    expect(karaoke.playing, true);
    expect(rejected.playing, false);
    expect(engine.sought, Duration.zero);
  });
}
