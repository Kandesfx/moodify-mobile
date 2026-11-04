import 'dart:async';

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
  Future<void> resume();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
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
      androidStopForegroundOnPause: false,
    ),
  );
  return _NativePlaybackEngine(handler);
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
    handler.mediaItem.add(
      MediaItem(
        id: track.id,
        title: track.displayName,
        artist: track.artist,
        duration: Duration(milliseconds: track.durationMs),
      ),
    );
    await handler.player.setUrl(uri.toString());
  }

  @override
  Future<void> resume() async {
    // just_audio's play future completes when playback stops, not when it starts.
    unawaited(handler.player.play().catchError((Object _) => handler.fail()));
  }

  @override
  Future<void> pause() => handler.player.pause();
  @override
  Future<void> seek(Duration position) => handler.player.seek(position);
  @override
  Future<void> stop() async {
    await handler.player.stop();
    handler.mediaItem.add(null);
    handler.publish();
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
    subscriptions.add(player.playbackEventStream.listen((_) => publish()));
    subscriptions.add(player.playerStateStream.listen((_) => publish()));
    subscriptions.add(player.positionStream.listen((_) => publish()));
    subscriptions.add(player.errorStream.listen((_) => fail()));
  }
  final player = AudioPlayer();
  final events = StreamController<EngineEvent>.broadcast();
  final subscriptions = <StreamSubscription<dynamic>>[];
  PlayerCommands? commands;

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

  void publish() {
    final processing = player.processingState;
    events.add(
      EngineEvent(
        playing: player.playing,
        buffering:
            processing == ProcessingState.loading ||
            processing == ProcessingState.buffering,
        completed: processing == ProcessingState.completed,
        position: player.position,
        duration: player.duration ?? Duration.zero,
      ),
    );
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (processing) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: player.playing,
        updatePosition: player.position,
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
