import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../app/bootstrap.dart';
import '../../auth/domain/session_state.dart';
import '../data/ad_policy.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_models.dart';
import '../data/playback_engine.dart';
import '../domain/offline_playback.dart';
import '../data/listening_reporter.dart';

final playbackEngineFactoryProvider =
    Provider<Future<PlaybackEngine> Function()>((ref) => createNativeEngine);
final adPolicyProvider = Provider<AdPolicyService>(
  (ref) => AdPolicyService(
    ref.watch(apiDioProvider),
    ref.watch(keyValueStoreProvider),
    ref.watch(appConfigProvider).apiBaseUri.toString(),
  ),
);
final offlinePlaybackAccessProvider = Provider<OfflinePlaybackAccess?>(
  (ref) => null,
);
final playerControllerProvider =
    StateNotifierProvider<PlayerController, PlayerState>((ref) {
      final controller = PlayerController(
        ref.watch(catalogRepositoryProvider),
        ref.watch(playbackEngineFactoryProvider),
        adPolicy: ref.watch(adPolicyProvider),
        currentUser: () {
          final session = ref.read(sessionControllerProvider);
          if (session.phase == SessionPhase.signedOut) return null;
          if (session.phase != SessionPhase.signedIn ||
              session.session == null) {
            throw const AppFailure(
              'Chưa thể kiểm tra phiên đăng nhập. Vui lòng thử lại.',
            );
          }
          return session.session!.user.id;
        },
        offline: (track) async => ref
            .read(offlinePlaybackAccessProvider)
            ?.playback(track, required: true),
        releaseOffline: () async =>
            ref.read(offlinePlaybackAccessProvider)?.releasePlayback(),
        report: (event) => ref.read(listeningReporterProvider)?.record(event),
      );
      ref.listen(
        sessionControllerProvider.select(
          (s) => s.session?.user.id ?? s.offlineUserId,
        ),
        (previous, next) {
          if (previous != next) unawaited(controller.clear());
        },
      );
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
    this.isAd = false,
    this.adCanSkip = false,
    this.volume = 1,
    this.sleepUntil,
    this.offline = false,
    this.source = 'OTHER',
    this.completed = false,
  });
  final List<Track> queue;
  final int index;
  final Track? track;
  final bool playing, loading, shuffle, isAd, adCanSkip;
  final Duration position, duration;
  final PlaybackRepeat repeat;
  final AppFailure? failure;
  final double volume;
  final DateTime? sleepUntil;
  final bool offline;
  final String source;
  final bool completed;
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
    bool? isAd,
    bool? adCanSkip,
    AppFailure? failure,
    bool clearFailure = false,
    double? volume,
    DateTime? sleepUntil,
    bool clearSleep = false,
    bool? offline,
    String? source,
    bool? completed,
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
    isAd: isAd ?? this.isAd,
    adCanSkip: adCanSkip ?? this.adCanSkip,
    failure: clearFailure ? null : failure ?? this.failure,
    volume: volume ?? this.volume,
    sleepUntil: clearSleep ? null : sleepUntil ?? this.sleepUntil,
    offline: offline ?? this.offline,
    source: source ?? this.source,
    completed: completed ?? this.completed,
  );
}

class PlayerController extends StateNotifier<PlayerState> {
  PlayerController(
    this.repository,
    this.createEngine, {
    this.adPolicy,
    this.currentUser,
    this.offline,
    this.releaseOffline,
    this.report,
  }) : super(const PlayerState());
  final CatalogRepository repository;
  final Future<PlaybackEngine> Function() createEngine;
  final AdPolicyService? adPolicy;
  final String? Function()? currentUser;
  final Future<OfflineSource?> Function(Track)? offline;
  final Future<void> Function()? releaseOffline;
  final void Function(ListeningEvent)? report;
  PlayerState get current => state;
  Object? get karaokeOwner => _karaokeOwner;
  final _adRandom = Random();
  int? _lastAd;
  String? _adAsset;
  (List<Track>, int)? _pendingAdTrack;
  bool _started = false, _actuallyPlaying = false;
  DateTime? _heartbeatAt;
  Duration _heartbeatPosition = Duration.zero;
  Timer? _sleepTimer, _licenseTimer;
  PlaybackEngine? _engine;
  Future<PlaybackEngine>? _engineFuture;
  StreamSubscription<EngineEvent>? _subscription;
  Future<void> _serial = Future.value();
  int _generation = 0;
  // A retry can change the load generation without changing the performance.
  Object? _karaokeOwner;
  bool _wantedPlaying = false;
  bool _switching = false;
  bool _completed = false;
  Uri? _karaokeSource;
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

  Future<void> select(
    List<Track> queue,
    int index, {
    bool offline = false,
    String source = 'OTHER',
  }) async {
    if (index < 0 || index >= queue.length) return;
    state = state.copy(offline: offline, source: source);
    if (state.isAd) {
      _history
        ..clear()
        ..add(index);
      _historyCursor = 0;
      _resetShuffle(queue.length, index);
      _pendingAdTrack = (List.unmodifiable(queue), index);
      state = state.copy(
        queue: List.unmodifiable(queue),
        index: index,
        track: queue[index],
      );
      return;
    }
    _karaokeOwner = null;
    _history.clear();
    _historyCursor = -1;
    _resetShuffle(queue.length, index);
    _report('TRACK_CHANGED');
    _started = false;
    await _select(queue, index);
  }

  Future<void> loadKaraoke(
    Track track,
    Uri uri, {
    required Object owner,
  }) async {
    if (uri.scheme != 'https' ||
        uri.host != 'moodify.click' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const AppFailure('Đường dẫn nhạc nền không hợp lệ.');
    }
    _karaokeOwner = owner;
    _report('TRACK_CHANGED');
    _history.clear();
    _historyCursor = -1;
    _shuffleRemaining.clear();
    _sleepTimer?.cancel();
    state = state.copy(offline: false, source: 'KARAOKE', clearSleep: true);
    await _select([track], 0, sourceUri: uri, autoplay: false);
    if (state.failure != null) throw state.failure!;
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
    bool checkAds = true,
    Uri? sourceUri,
    bool autoplay = true,
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
    _report('TRACK_CHANGED');
    final generation = ++_generation;
    _karaokeSource = sourceUri;
    _started = false;
    _actuallyPlaying = false;
    _heartbeatAt = null;
    _licenseTimer?.cancel();
    _wantedPlaying = autoplay;
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
      isAd: false,
      adCanSkip: false,
      clearFailure: true,
      completed: false,
    );
    await _run(() async {
      if (generation != _generation) return;
      final engine = await _getEngine();
      await engine.stop();
      await releaseOffline?.call();
      if (generation != _generation) return;
      // Quảng cáo chỉ áp dụng cho luồng streaming bình thường: không chen vào
      // bản tải offline và không chen trước nhạc nền karaoke.
      if (checkAds && adPolicy != null && !state.offline && sourceUri == null) {
        final decision = await adPolicy!.decide(currentUser?.call());
        if (generation != _generation) return;
        if (decision.show) {
          var index = _adRandom.nextInt(9) + 1;
          while (index == _lastAd) {
            index = _adRandom.nextInt(9) + 1;
          }
          _lastAd = index;
          _adAsset = 'assets/ads/ad_mix_$index.mp3';
          _pendingAdTrack = (List.unmodifiable(queue), state.index);
          state = state.copy(
            isAd: true,
            adCanSkip: decision.canSkip,
            position: Duration.zero,
            duration: Duration.zero,
          );
          Duration? adDuration;
          try {
            adDuration = await engine.loadAd(_adAsset!);
          } catch (_) {
            throw const AppFailure(
              'Không tải được quảng cáo. Vui lòng thử lại.',
              code: 'AD_MEDIA',
            );
          }
          if (generation != _generation) return;
          _switching = false;
          state = state.copy(
            loading: false,
            duration: adDuration ?? Duration.zero,
          );
          if (_wantedPlaying) await engine.resume();
          return;
        }
      }
      final track = state.offline || sourceUri != null
          ? queue[index]
          : await repository.track(queue[index].id);
      if (generation != _generation) return;
      final local = state.offline ? await offline?.call(track) : null;
      if (state.offline && local == null) {
        throw const AppFailure('Chưa tìm thấy bản tải xuống của bài hát.');
      }
      final uri = sourceUri ?? local?.uri ?? await repository.stream(track);
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
      if (local != null) {
        final remaining = local.expiresAt.difference(DateTime.now().toUtc());
        if (remaining <= Duration.zero) {
          throw const AppFailure('Bản quyền offline đã hết hạn.');
        }
        _licenseTimer = Timer(remaining, () {
          if (!mounted || generation != _generation) return;
          _wantedPlaying = false;
          unawaited(
            _run(() async {
              await _engine?.stop();
              await releaseOffline?.call();
            }),
          );
          state = state.copy(
            playing: false,
            loading: false,
            failure: const AppFailure(
              'Bản quyền offline đã hết hạn. Kết nối mạng để gia hạn.',
            ),
          );
        });
      }
      state = state.copy(track: track, loading: false);
      await engine.volume(state.volume);
      if (_wantedPlaying) await engine.resume();
    }, generation: generation);
  }

  void _event(EngineEvent event) {
    if (!mounted || _switching || state.track == null) return;
    if (event.failed) {
      _report('PAUSE');
      _actuallyPlaying = false;
      _wantedPlaying = false;
      state = state.copy(
        playing: false,
        loading: false,
        failure: AppFailure(
          state.isAd
              ? 'Không phát được quảng cáo. Vui lòng thử lại.'
              : 'Không phát được bài hát. Kiểm tra mạng rồi thử lại.',
        ),
      );
      unawaited(_run(() async => _engine?.pause()));
      return;
    }
    if (event.completed) {
      _report('COMPLETE', position: event.position);
      _actuallyPlaying = false;
    } else if (event.playing && !event.buffering) {
      if (!_started || !_actuallyPlaying) {
        _report(_started ? 'RESUME' : 'PLAY', position: event.position);
        _started = true;
        _actuallyPlaying = true;
        _heartbeatAt = DateTime.now();
        _heartbeatPosition = event.position;
      } else if (_heartbeatAt != null &&
          DateTime.now().difference(_heartbeatAt!) >=
              const Duration(seconds: 8) &&
          event.position > _heartbeatPosition) {
        _report('HEARTBEAT', position: event.position);
        _heartbeatAt = DateTime.now();
        _heartbeatPosition = event.position;
      }
    } else if (!event.playing && _actuallyPlaying) {
      _report('PAUSE', position: event.position);
      _actuallyPlaying = false;
    }
    state = state.copy(
      playing: event.playing && !event.completed,
      loading: event.buffering,
      position: event.position,
      duration: event.duration > Duration.zero
          ? event.duration
          : state.duration,
      completed: event.completed,
    );
    if (event.completed &&
        state.source != 'KARAOKE' &&
        _wantedPlaying &&
        !_completed) {
      _completed = true;
      if (state.isAd) {
        unawaited(_finishAd());
      } else {
        unawaited(_advance(completion: true));
      }
    }
  }

  Future<void> play() async {
    if (state.track == null) return;
    if (state.failure != null && state.isAd && _adAsset != null) {
      _wantedPlaying = true;
      _switching = true;
      state = state.copy(loading: true, clearFailure: true);
      await _run(() async {
        final engine = await _getEngine();
        final duration = await engine.loadAd(_adAsset!);
        _switching = false;
        state = state.copy(loading: false, duration: duration ?? Duration.zero);
        if (_wantedPlaying) await engine.resume();
      });
      return;
    }
    if (state.failure != null || _completed || state.completed) {
      await _select(
        state.queue,
        state.index,
        remember: false,
        sourceUri: _karaokeSource,
      );
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
    if (state.track == null || state.loading || state.isAd) return;
    final maximum = state.duration.inMilliseconds;
    final ms = position.inMilliseconds.clamp(0, maximum > 0 ? maximum : 0);
    await _engine?.seek(Duration(milliseconds: ms));
    _report('SEEK', target: Duration(milliseconds: ms));
    if (!_actuallyPlaying) {
      _report('PAUSE', position: Duration(milliseconds: ms));
    }
    _heartbeatAt = DateTime.now();
    _heartbeatPosition = Duration(milliseconds: ms);
    _completed = false;
    state = state.copy(completed: false);
  });
  Future<void> next() =>
      state.isAd || state.source == 'KARAOKE' ? Future.value() : _advance();
  Future<void> previous() async {
    if (state.isAd || state.source == 'KARAOKE') return;
    if (state.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    if (_historyCursor > 0) {
      _report('SKIP_PREVIOUS');
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
      if (!completion) _report('SKIP_NEXT');
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
    if (!completion) _report('SKIP_NEXT');
    await _select(state.queue, nextIndex);
  }

  int get playbackGeneration => _generation;

  /// Mirrors the web upgrade action for the current advertisement only.
  Future<void> skipAdForUpgrade(int generation) async {
    if (!mounted || generation != _generation || !state.isAd) return;
    await _finishAd();
  }

  Future<void> skipAd() async {
    if (!state.isAd ||
        !state.adCanSkip ||
        state.position < const Duration(seconds: 5)) {
      return;
    }
    await _finishAd();
  }

  Future<void> _finishAd() async {
    final pending = _pendingAdTrack;
    if (!state.isAd || pending == null) return;
    _pendingAdTrack = null;
    _adAsset = null;
    state = state.copy(isAd: false, adCanSkip: false);
    await _select(pending.$1, pending.$2, remember: false, checkAds: false);
  }

  Future<void> playCollection(
    List<Track> tracks, {
    bool shuffled = false,
    String source = 'OTHER',
  }) async {
    if (tracks.isEmpty) return;
    final index = shuffled ? Random().nextInt(tracks.length) : 0;
    if (state.shuffle != shuffled) toggleShuffle();
    await select(tracks, index, source: source);
  }

  Future<bool> enqueue(Track track, {bool next = false}) async {
    if (state.offline ||
        state.source == 'KARAOKE' ||
        state.isAd ||
        state.loading ||
        state.queue.length >= 200) {
      return false;
    }
    if (state.queue.any((item) => item.id == track.id)) return false;
    if (state.track == null) {
      await select([track], 0);
      return state.failure == null;
    }
    final queue = [...state.queue];
    final insertion = next ? state.index + 1 : queue.length;
    queue.insert(insertion, track);
    for (var i = 0; i < _history.length; i++) {
      if (_history[i] >= insertion) _history[i]++;
    }
    state = state.copy(queue: List.unmodifiable(queue));
    _resetShuffle(queue.length, state.index);
    return true;
  }

  bool removeUpcoming(int index) {
    if (state.source == 'KARAOKE' ||
        state.isAd ||
        state.loading ||
        index <= state.index ||
        index >= state.queue.length) {
      return false;
    }
    final queue = [...state.queue]..removeAt(index);
    final history = <int>[];
    var cursor = -1;
    for (var i = 0; i < _history.length; i++) {
      final item = _history[i];
      if (item == index) continue;
      history.add(item > index ? item - 1 : item);
      if (i <= _historyCursor) cursor = history.length - 1;
    }
    _history
      ..clear()
      ..addAll(history);
    _historyCursor = cursor;
    state = state.copy(queue: List.unmodifiable(queue));
    _resetShuffle(queue.length, state.index);
    return true;
  }

  void cycleRepeat() => state = state.copy(
    repeat: PlaybackRepeat
        .values[(state.repeat.index + 1) % PlaybackRepeat.values.length],
  );
  void toggleShuffle() {
    _resetShuffle(state.queue.length, state.index);
    state = state.copy(shuffle: !state.shuffle);
  }

  Future<void> volume(double value) {
    state = state.copy(volume: value.clamp(0, 1));
    return _run(() async => _engine?.volume(state.volume));
  }

  void sleep(Duration? duration) {
    _sleepTimer?.cancel();
    state = state.copy(
      sleepUntil: duration == null ? null : DateTime.now().add(duration),
      clearSleep: duration == null,
    );
    if (duration != null) {
      _sleepTimer = Timer(duration, () {
        if (!mounted) return;
        unawaited(pause());
        state = state.copy(clearSleep: true);
      });
    }
  }

  Future<void> clear() {
    _karaokeOwner = null;
    _report('PLAYBACK_STOPPED');
    _started = false;
    _actuallyPlaying = false;
    _sleepTimer?.cancel();
    _licenseTimer?.cancel();
    _generation++;
    _wantedPlaying = false;
    _switching = false;
    _completed = false;
    _pendingAdTrack = null;
    _adAsset = null;
    _karaokeSource = null;
    _history.clear();
    _historyCursor = -1;
    _shuffleRemaining.clear();
    if (mounted) state = const PlayerState();
    return _run(() async {
      await _engine?.stop();
      await releaseOffline?.call();
    });
  }

  @override
  void dispose() {
    _karaokeOwner = null;
    _sleepTimer?.cancel();
    _licenseTimer?.cancel();
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

  void _report(String event, {Duration? position, Duration? target}) {
    final track = state.track;
    if (track == null ||
        state.offline ||
        state.source == 'KARAOKE' ||
        state.isAd ||
        (!_started && event != 'PLAY')) {
      return;
    }
    report?.call((
      generation: _generation,
      trackId: track.id,
      event: event,
      positionMs: (position ?? state.position).inMilliseconds,
      targetPositionMs: (target ?? position ?? state.position).inMilliseconds,
      source: state.source,
    ));
  }
}
