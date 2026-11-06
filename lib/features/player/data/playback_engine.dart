import 'dart:async';
import 'dart:ui' show Color;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../catalog/domain/catalog_models.dart';

class EngineEvent {
  const EngineEvent({
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.failed = false,
  });
  final bool playing, buffering, completed, failed;
  final Duration position, duration;
}

class PlayerCommands {
  const PlayerCommands({
    required this.play,
    required this.pause,
    required this.next,
    required this.previous,
    required this.seek,
    required this.stop,
  });
  final Future<void> Function() play, pause, next, previous, stop;
  final Future<void> Function(Duration) seek;
}

abstract interface class PlaybackEngine {
  Stream<EngineEvent> get events;
  void bind(PlayerCommands commands);
  Future<void> load(Uri uri, Track track);
  Future<Duration?> loadAd(String asset);
  Future<void> resume();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> volume(double value);
  Future<void> dispose();
}

Future<PlaybackEngine> createNativeEngine() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  final handler = await AudioService.init<_MoodifyAudioHandler>(
    builder: _MoodifyAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'dev.moodify.playback',
      androidNotificationChannelName: 'Phát nhạc Moodify',
      androidNotificationIcon: 'drawable/ic_stat_moodify',
      notificationColor: Color(0xFF14161D),
      androidStopForegroundOnPause: false,
      preloadArtwork: true,
    ),
  );
  return _NativePlaybackEngine(handler);
}

Uri? _resolveNotificationArtUri(Uri streamUri, String? rawImage) {
  if (rawImage == null || rawImage.trim().isEmpty) return null;
  final parsed = Uri.tryParse(rawImage.trim());
  if (parsed == null) return null;
  if (parsed.hasScheme &&
      (parsed.scheme == 'https' || parsed.scheme == 'http')) {
    return parsed;
  }
  if (streamUri.scheme == 'https' || streamUri.scheme == 'http') {
    return streamUri
        .replace(path: '/', query: null, fragment: null)
        .resolveUri(parsed);
  }
  return null;
}

class _NativePlaybackEngine implements PlaybackEngine {
  _NativePlaybackEngine(this.handler);
  final _MoodifyAudioHandler handler;
  @override
  Stream<EngineEvent> get events => handler.events.stream;
  @override
  void bind(PlayerCommands commands) => handler.commands = commands;
  @override
  Future<void> load(Uri uri, Track track) async {
    handler.adMode = false;
    handler.mediaItem.add(
      MediaItem(
        id: track.id,
        title: track.displayName,
        artist: track.artist,
        duration: Duration(milliseconds: track.durationMs),
        artUri: _resolveNotificationArtUri(uri, track.image),
      ),
    );
    await handler.player.setUrl(uri.toString());
  }

  @override
  Future<Duration?> loadAd(String asset) async {
    handler.adMode = true;
    handler.mediaItem.add(
      const MediaItem(id: 'moodify-ad', title: 'Quảng cáo', artist: 'Moodify'),
    );
    return handler.player.setAsset(asset);
  }

  @override
  Future<void> resume() async {
    // just_audio's play future completes when playback stops, not when it starts.
    unawaited(handler.player.play().catchError((Object _) => handler.fail()));
  }

  @override
  Future<void> pause() => handler.player.pause();
  @override
  Future<void> seek(Duration position) async {
    await handler.player.seek(position);
    handler.publish(force: true);
  }

  @override
  Future<void> volume(double value) => handler.player.setVolume(value);
  @override
  Future<void> stop() async {
    await handler.player.stop();
    handler.mediaItem.add(null);
    handler.publish(force: true);
  }

  @override
  Future<void> dispose() async {
    for (final subscription in handler.subscriptions) {
      await subscription.cancel();
    }
    await handler.player.dispose();
    await handler.events.close();
  }
}

class _MoodifyAudioHandler extends BaseAudioHandler {
  _MoodifyAudioHandler() {
    subscriptions.add(
      player.playbackEventStream.listen((_) => publish(force: true)),
    );
    subscriptions.add(
      player.playerStateStream.listen((_) => publish(force: true)),
    );
    subscriptions.add(
      player.positionStream.listen((_) => publish(positionOnly: true)),
    );
    subscriptions.add(player.errorStream.listen((_) => fail()));
  }
  final player = AudioPlayer();
  final events = StreamController<EngineEvent>.broadcast();
  final subscriptions = <StreamSubscription<dynamic>>[];
  PlayerCommands? commands;
  bool adMode = false;
  Duration _lastEmittedPosition = Duration.zero;
  bool? _lastPlaying;
  ProcessingState? _lastProcessing;
  bool? _lastAdMode;

  void fail() {
    events.add(const EngineEvent(failed: true));
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
        errorCode: 1,
        errorMessage: 'Không phát được nguồn âm thanh.',
      ),
    );
  }

  void publish({bool positionOnly = false, bool force = false}) {
    final processing = player.processingState;
    final pos = player.position;
    final stateChanged =
        force ||
        _lastPlaying != player.playing ||
        _lastProcessing != processing ||
        _lastAdMode != adMode;

    if (positionOnly && !stateChanged) {
      final deltaMs = (pos - _lastEmittedPosition).inMilliseconds.abs();
      if (pos != Duration.zero && deltaMs < 200) {
        return;
      }
    }
    _lastEmittedPosition = pos;
    _lastPlaying = player.playing;
    _lastProcessing = processing;
    _lastAdMode = adMode;

    events.add(
      EngineEvent(
        playing: player.playing,
        buffering:
            processing == ProcessingState.loading ||
            processing == ProcessingState.buffering,
        completed: processing == ProcessingState.completed,
        position: pos,
        duration: player.duration ?? Duration.zero,
      ),
    );
    if (!stateChanged) return;

    playbackState.add(
      PlaybackState(
        controls: adMode
            ? [player.playing ? MediaControl.pause : MediaControl.play]
            : [
                MediaControl.skipToPrevious,
                player.playing ? MediaControl.pause : MediaControl.play,
                MediaControl.skipToNext,
              ],
        systemActions: adMode
            ? const {}
            : const {
                MediaAction.seek,
                MediaAction.seekForward,
                MediaAction.seekBackward,
              },
        androidCompactActionIndices: adMode ? const [0] : const [0, 1, 2],
        processingState: switch (processing) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: player.playing,
        updatePosition: pos,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
      ),
    );
  }

  @override
  Future<void> play() async => commands?.play();
  @override
  Future<void> pause() async => commands?.pause();
  @override
  Future<void> seek(Duration position) async => commands?.seek(position);
  @override
  Future<void> skipToNext() async => commands?.next();
  @override
  Future<void> skipToPrevious() async => commands?.previous();
  @override
  Future<void> stop() async => commands?.stop();
  @override
  Future<void> onTaskRemoved() async => commands?.stop();
}
