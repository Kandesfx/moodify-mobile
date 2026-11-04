import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_models.dart';
import '../data/playback_engine.dart';

final playbackEngineFactoryProvider =
    Provider<Future<PlaybackEngine> Function()>((ref) => createNativeEngine);
final playerControllerProvider =
    StateNotifierProvider<PlayerController, PlayerState>((ref) {
      final controller = PlayerController(
        ref.watch(catalogRepositoryProvider),
        ref.watch(playbackEngineFactoryProvider),
      );
      ref.listen(sessionControllerProvider.select((s) => s.session?.user.id), (
        previous,
        next,
      ) {
        if (previous != next) unawaited(controller.clear());
      });
      return controller;
    });

enum PlaybackRepeat { off, all, one }

class PlayerState {
  const PlayerState({
    this.queue = const [],
    this.index = -1,
    this.track,
    this.playing = false,
    this.loading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.repeat = PlaybackRepeat.off,
    this.shuffle = false,
    this.failure,
  });
  final List<Track> queue;
  final int index;
  final Track? track;
  final bool playing, loading, shuffle;
  final Duration position, duration;
  final PlaybackRepeat repeat;
  final AppFailure? failure;
  PlayerState copy({
    List<Track>? queue,
    int? index,
    Track? track,
    bool? playing,
    bool? loading,
    Duration? position,
    Duration? duration,
    PlaybackRepeat? repeat,
    bool? shuffle,
    AppFailure? failure,
    bool clearFailure = false,
  }) => PlayerState(
    queue: queue ?? this.queue,
    index: index ?? this.index,
    track: track ?? this.track,
    playing: playing ?? this.playing,
    loading: loading ?? this.loading,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    repeat: repeat ?? this.repeat,
    shuffle: shuffle ?? this.shuffle,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

class PlayerController extends StateNotifier<PlayerState> {
  PlayerController(this.repository, this.createEngine)
    : super(const PlayerState());
  final CatalogRepository repository;
  final Future<PlaybackEngine> Function() createEngine;
  PlaybackEngine? _engine;
  Future<PlaybackEngine>? _engineFuture;
  StreamSubscription<EngineEvent>? _subscription;
  Future<void> _serial = Future.value();
  int _generation = 0;
  bool _wantedPlaying = false;
  bool _switching = false;
  bool _completed = false;
  final _history = <int>[];
  int _historyCursor = -1;
  final _shuffleRemaining = <int>[];

  Future<PlaybackEngine> _getEngine() => _engineFuture ??= () async {
    late final PlaybackEngine engine;
    try {
      engine = await createEngine();
    } catch (_) {
      _engineFuture = null;
      rethrow;
    }
    _engine = engine;
    engine.bind(
      PlayerCommands(
        play: play,
        pause: pause,
        next: next,
        previous: previous,
        seek: seek,
        stop: clear,
      ),
    );
    _subscription = engine.events.listen(_event);
    return engine;
  }();

  // Serialize native mutations; only the newest track selection may start audio.
  Future<void> _run(Future<void> Function() action, {int? generation}) {
    final requestedGeneration = generation ?? _generation;
    final result = _serial.then((_) async {
      if (!mounted || requestedGeneration != _generation) return;
      try {
        await action();
      } catch (error) {
        if (!mounted || requestedGeneration != _generation) return;
        _wantedPlaying = false;
        _switching = false;
        state = state.copy(
          playing: false,
          loading: false,
          failure: AppFailure.from(error),
        );
      }
    });
    _serial = result;
    return result;
  }

  Future<void> select(List<Track> queue, int index) async {
    if (index < 0 || index >= queue.length) return;
    _history.clear();
    _historyCursor = -1;
    _resetShuffle(queue.length, index);
    await _select(queue, index);
  }

  void _resetShuffle(int length, int current) {
    _shuffleRemaining
      ..clear()
      ..addAll([
        for (var i = 0; i < length; i++)
          if (i != current) i,
      ])
      ..shuffle(Random());
  }

  Future<void> _select(
    List<Track> queue,
    int index, {
    bool remember = true,
  }) async {
    if (index < 0 || index >= queue.length) return;
    if (remember) {
      if (_historyCursor + 1 < _history.length) {
        _history.removeRange(_historyCursor + 1, _history.length);
      }
      _history.add(index);
      if (_history.length > 100) {
        _history.removeAt(0);
      }
      _historyCursor = _history.length - 1;
    }
    final generation = ++_generation;
    _wantedPlaying = true;
    _switching = true;
    _completed = false;
    state = state.copy(
      queue: List.unmodifiable(queue),
      index: index,
      track: queue[index],
      playing: false,
      loading: true,
      position: Duration.zero,
      duration: Duration(milliseconds: queue[index].durationMs),
      clearFailure: true,
    );
    await _run(() async {
      if (generation != _generation) return;
      final engine = await _getEngine();
      await engine.stop();
      if (generation != _generation) return;
      final track = await repository.track(queue[index].id);
      if (generation != _generation) return;
      final uri = await repository.stream(track);
      if (generation != _generation) return;
      try {
        await engine.load(uri, track);
      } catch (_) {
        throw const AppFailure(
          'Không tải được âm thanh của bài hát này. Kiểm tra mạng hoặc chọn bài khác.',
          code: 'MEDIA',
        );
      }
      if (generation != _generation) return;
      _switching = false;
      state = state.copy(track: track, loading: false);
      if (_wantedPlaying) await engine.resume();
    }, generation: generation);
  }

  void _event(EngineEvent event) {
    if (!mounted || _switching || state.track == null) return;
    if (event.failed) {
      _wantedPlaying = false;
      state = state.copy(
        playing: false,
        loading: false,
        failure: const AppFailure(
          'Không phát được bài hát. Kiểm tra mạng rồi thử lại.',
        ),
      );
      unawaited(_run(() async => _engine?.pause()));
      return;
    }
    state = state.copy(
      playing: event.playing && !event.completed,
      loading: event.buffering,
      position: event.position,
      duration: event.duration > Duration.zero
          ? event.duration
          : state.duration,
    );
    if (event.completed && _wantedPlaying && !_completed) {
      _completed = true;
      unawaited(_advance(completion: true));
    }
  }

  Future<void> play() async {
    if (state.track == null) return;
    if (state.failure != null) {
      await _select(state.queue, state.index, remember: false);
      return;
    }
    _wantedPlaying = true;
    await _run(() async {
      final engine = await _getEngine();
      if (_completed) {
        await engine.seek(Duration.zero);
        _completed = false;
      }
      await engine.resume();
    });
  }

  Future<void> pause() {
    _wantedPlaying = false;
    if (mounted) state = state.copy(playing: false);
    return _run(() async => _engine?.pause());
  }

  Future<void> seek(Duration position) => _run(() async {
    if (state.track == null || state.loading) return;
    final maximum = state.duration.inMilliseconds;
    final ms = position.inMilliseconds.clamp(0, maximum > 0 ? maximum : 0);
    await _engine?.seek(Duration(milliseconds: ms));
    _completed = false;
  });
  Future<void> next() => _advance();
  Future<void> previous() async {
    if (state.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    if (_historyCursor > 0) {
      _historyCursor--;
      await _select(state.queue, _history[_historyCursor], remember: false);
    } else {
      await seek(Duration.zero);
    }
  }

  Future<void> _advance({bool completion = false}) async {
    if (state.queue.isEmpty) return;
    if (completion && state.repeat == PlaybackRepeat.one) {
      await _select(state.queue, state.index, remember: false);
      return;
    }
    if (_historyCursor + 1 < _history.length) {
      _historyCursor++;
      await _select(state.queue, _history[_historyCursor], remember: false);
      return;
    }
    int nextIndex = state.index + 1;
    if (state.shuffle) {
      if (_shuffleRemaining.isEmpty && state.repeat == PlaybackRepeat.all) {
        _resetShuffle(state.queue.length, state.index);
      }
      nextIndex = _shuffleRemaining.isEmpty
          ? state.queue.length
          : _shuffleRemaining.removeLast();
    }
    if (nextIndex >= state.queue.length) {
      if (state.repeat == PlaybackRepeat.all) {
        nextIndex = 0;
      } else {
        await pause();
        return;
      }
    }
    await _select(state.queue, nextIndex);
  }

  void cycleRepeat() => state = state.copy(
    repeat: PlaybackRepeat
        .values[(state.repeat.index + 1) % PlaybackRepeat.values.length],
  );
  void toggleShuffle() {
    _resetShuffle(state.queue.length, state.index);
    state = state.copy(shuffle: !state.shuffle);
  }

  Future<void> clear() {
    _generation++;
    _wantedPlaying = false;
    _switching = false;
    _completed = false;
    _history.clear();
    _historyCursor = -1;
    _shuffleRemaining.clear();
    if (mounted) state = const PlayerState();
    return _run(() async => _engine?.stop());
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_subscription?.cancel());
    // Wait for an in-flight load before disposing its single native engine.
    unawaited(
      _serial.whenComplete(() async {
        final future = _engineFuture;
        if (future != null) {
          try {
            await (await future).dispose();
          } catch (_) {}
        }
      }),
    );
    super.dispose();
  }
}
