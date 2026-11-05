import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:moodify_flutter/features/player/data/ad_policy.dart';
import '../../support/auth_harness.dart' show MemoryStore;
import 'package:moodify_flutter/features/player/data/playback_engine.dart';
import 'package:moodify_flutter/features/player/presentation/player_controller.dart';

import '../../support/music_harness.dart';

class FixedAdPolicy extends AdPolicyService {
  FixedAdPolicy(this.decision) : super(Dio(), MemoryStore(), 'test');
  final AdDecision decision;
  @override
  Future<AdDecision> decide(String? userId) async => decision;
}

void main() {
  late MusicRepositoryFake repository;
  late PlaybackEngineFake engine;
  late PlayerController player;
  var created = 0;
  setUp(() {
    created = 0;
    repository = MusicRepositoryFake();
    engine = PlaybackEngineFake();
    player = PlayerController(repository, () async {
      created++;
      return engine;
    });
  });
  tearDown(() async {
    player.dispose();
    await flushMusic();
    repository.remote.dio.close();
  });

  test(
    'ad plays before track, blocks seek and skips, then resumes selected track',
    () async {
      player.dispose();
      player = PlayerController(
        repository,
        () async => engine,
        adPolicy: FixedAdPolicy(const AdDecision(true, false)),
      );
      await player.select([firstTrack, secondTrack], 0);
      expect(player.state.isAd, true);
      expect(engine.ads, hasLength(1));
      expect(engine.loaded, isEmpty);
      await player.next();
      await player.seek(const Duration(seconds: 20));
      await player.skipAd();
      expect(engine.loaded, isEmpty);
      expect(engine.sought, Duration.zero);
      await player.select([firstTrack, secondTrack], 1);
      engine.controller.add(const EngineEvent(completed: true));
      await flushMusic();
      expect(player.state.isAd, false);
      expect(engine.loaded, [secondTrack.id]);
      expect(player.state.track?.id, secondTrack.id);
    },
  );

  test('ad duration remains available when the start event omits it', () async {
    player.dispose();
    engine.resumeDuration = Duration.zero;
    player = PlayerController(
      repository,
      () async => engine,
      adPolicy: FixedAdPolicy(const AdDecision(true, false)),
    );
    await player.select([firstTrack], 0);
    expect(player.state.duration, const Duration(seconds: 30));
  });

  test('basic tier can skip only after five seconds of ad audio', () async {
    player.dispose();
    player = PlayerController(
      repository,
      () async => engine,
      adPolicy: FixedAdPolicy(const AdDecision(true, true)),
    );
    await player.select([firstTrack], 0);
    engine.controller.add(
      const EngineEvent(playing: true, position: Duration(seconds: 4)),
    );
    await player.skipAd();
    expect(engine.loaded, isEmpty);
    engine.controller.add(
      const EngineEvent(playing: true, position: Duration(seconds: 5)),
    );
    await player.skipAd();
    expect(engine.loaded, [firstTrack.id]);
  });

  test('clearing during an ad does not start the pending track', () async {
    player.dispose();
    player = PlayerController(
      repository,
      () async => engine,
      adPolicy: FixedAdPolicy(const AdDecision(true, false)),
    );
    await player.select([firstTrack], 0);
    await player.clear();
    engine.controller.add(const EngineEvent(completed: true));
    await flushMusic();
    expect(engine.loaded, isEmpty);
    expect(player.state.track, isNull);
  });

  test('one engine serves selection and OS controls', () async {
    await player.select([firstTrack, secondTrack], 0);
    await engine.commands!.pause();
    await engine.commands!.play();
    await engine.commands!.next();
    expect(created, 1);
    expect(engine.loaded, [firstTrack.id, secondTrack.id]);
    expect(player.state.track!.id, secondTrack.id);
    await engine.commands!.stop();
    expect(player.state.track, isNull);
    expect(player.state.queue, isEmpty);
  });
  test('pause during source loading prevents autoplay', () async {
    final pending = Completer<void>();
    repository.onTrack = (_) async {
      await pending.future;
      return firstTrack;
    };
    final selection = player.select([firstTrack], 0);
    await flushMusic();
    final pause = player.pause();
    pending.complete();
    await selection;
    await pause;
    expect(engine.resumes, 0);
    expect(player.state.playing, false);
  });
  test('late failure from old selection cannot poison new track', () async {
    final pending = Completer<void>();
    repository.onTrack = (id) async {
      if (id == firstTrack.id) {
        await pending.future;
        throw StateError('Old request failed');
      }
      return secondTrack;
    };
    final old = player.select([firstTrack, secondTrack], 0);
    await flushMusic();
    final current = player.select([firstTrack, secondTrack], 1);
    pending.complete();
    await old;
    await current;
    expect(engine.loaded, [secondTrack.id]);
    expect(engine.resumes, 1);
    expect(player.state.failure, isNull);
    expect(player.state.playing, true);
  });
  test('logout clear during source loading cannot restart old audio', () async {
    final pending = Completer<void>();
    repository.onTrack = (_) async {
      await pending.future;
      return firstTrack;
    };
    final selection = player.select([firstTrack], 0);
    await flushMusic();
    final cleared = player.clear();
    pending.complete();
    await selection;
    await cleared;
    expect(engine.loaded, isEmpty);
    expect(engine.resumes, 0);
    expect(player.state.track, isNull);
  });
  test(
    'last track with repeat off stops and play restarts from zero',
    () async {
      await player.select([firstTrack], 0);
      engine.controller.add(
        const EngineEvent(
          completed: true,
          playing: true,
          position: Duration(minutes: 2),
          duration: Duration(minutes: 2),
        ),
      );
      await flushMusic();
      expect(engine.loaded.length, 1);
      expect(player.state.playing, false);
      await player.play();
      expect(engine.sought, Duration.zero);
      expect(engine.resumes, 2);
    },
  );
  test('repeat all wraps; repeat one reloads only current track', () async {
    player.cycleRepeat();
    await player.select([firstTrack, secondTrack], 1);
    engine.controller.add(const EngineEvent(completed: true));
    await flushMusic();
    expect(player.state.index, 0);
    player.cycleRepeat();
    engine.controller.add(const EngineEvent(completed: true));
    await flushMusic();
    expect(player.state.index, 0);
    expect(engine.loaded, [secondTrack.id, firstTrack.id, firstTrack.id]);
  });
  test(
    'seek clamps to real duration; media errors pause without fallback',
    () async {
      await player.select([firstTrack], 0);
      await player.seek(const Duration(hours: 1));
      expect(engine.sought, const Duration(minutes: 2));
      engine.controller.add(const EngineEvent(failed: true));
      await flushMusic();
      expect(player.state.failure, isNotNull);
      expect(engine.loaded.length, 1);
      expect(player.state.playing, false);
    },
  );
  test('failed engine initialization can be retried', () async {
    player.dispose();
    var attempts = 0;
    player = PlayerController(repository, () async {
      if (++attempts == 1) throw StateError('Native initialization failed');
      return engine;
    });
    await player.select([firstTrack], 0);
    expect(player.state.failure, isNotNull);
    await player.play();
    expect(player.state.failure, isNull);
    expect(engine.resumes, 1);
  });
  test(
    'shuffle visits each queued track once and previous follows actual playback',
    () async {
      await player.select([firstTrack, secondTrack], 0);
      player.toggleShuffle();
      await player.next();
      expect(player.state.index, 1);
      await player.previous();
      expect(player.state.index, 0);
      await player.next();
      expect(player.state.index, 1);
      final loaded = engine.loaded.length;
      engine.controller.add(const EngineEvent(completed: true));
      await flushMusic();
      expect(engine.loaded.length, loaded);
      expect(player.state.playing, false);
    },
  );
}
