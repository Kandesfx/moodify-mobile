import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/player/data/listening_reporter.dart';
import 'package:moodify_flutter/features/player/domain/lyric_line.dart';
import 'package:moodify_flutter/features/player/presentation/player_controller.dart';
import '../../support/auth_harness.dart';
import '../../support/music_harness.dart';

void main() {
  test(
    'LRC supports multiple timestamps, fractions and metadata without fabricated lines',
    () {
      final lines = parseLrc(
        '[ar:Artist]\n[00:01.2][00:03.045]Line\n[00:70]invalid\n[00:05]Next',
      );
      expect(lines.map((e) => e.at.inMilliseconds), [1200, 3045, 5000]);
      expect(lines.map((e) => e.text), ['Line', 'Line', 'Next']);
      expect(parseLrc('plain lyrics'), isEmpty);
    },
  );
  test(
    'sleep timer pauses the existing engine and clears its deadline',
    () async {
      final repository = MusicRepositoryFake();
      final engine = PlaybackEngineFake();
      final player = PlayerController(repository, () async => engine);
      await player.select([firstTrack], 0);
      player.sleep(const Duration(milliseconds: 20));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(player.state.playing, false);
      expect(engine.pauses, 1);
      expect(player.state.sleepUntil, isNull);
      player.dispose();
      await flushMusic();
      repository.remote.dio.close();
    },
  );
  test(
    'offline selection uses the existing engine without catalog requests or revenue events',
    () async {
      final repository = MusicRepositoryFake()
        ..onTrack = (_) async => throw StateError('Must not use network');
      final engine = PlaybackEngineFake();
      final events = <ListeningEvent>[];
      final player = PlayerController(
        repository,
        () async => engine,
        offline: (_) async => (
          uri: Uri.file('/test-only/song.mp3'),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        report: events.add,
      );
      await player.select([firstTrack], 0, offline: true);
      expect(engine.loaded, [firstTrack.id]);
      expect(events, isEmpty);
      expect(player.state.offline, true);
      player.dispose();
      await flushMusic();
      repository.remote.dio.close();
    },
  );
  test(
    'reporter uses one session key, ordered actual events and one terminal event',
    () async {
      final requests = <Map<String, dynamic>>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/'))
        ..httpClientAdapter = TestAdapter((o) {
          requests.add(Map<String, dynamic>.from(o.data as Map));
          return jsonResponse({'success': true});
        });
      final reporter = ListeningReporter(dio, 'ANDROID');
      void send(String event, int position) => reporter.record((
        generation: 1,
        trackId: firstTrack.id,
        event: event,
        positionMs: position,
        targetPositionMs: position,
        source: 'SEARCH',
      ));
      send('PAUSE', 0);
      send('PLAY', 0);
      send('HEARTBEAT', 8000);
      send('SEEK', 9000);
      send('COMPLETE', 120000);
      send('TRACK_CHANGED', 120000);
      await reporter.settled;
      expect(requests.map((e) => e['eventType']), [
        'PLAY',
        'HEARTBEAT',
        'SEEK',
        'COMPLETE',
      ]);
      expect(requests.map((e) => e['sessionKey']).toSet(), hasLength(1));
      expect(requests.every((e) => !e.containsKey('durationMs')), true);
      reporter.dispose();
      dio.close();
    },
  );
}
