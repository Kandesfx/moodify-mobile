import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as audio;

import '../../catalog/domain/catalog_models.dart';
import '../../player/presentation/player_controller.dart';

final karaokePlaybackFactoryProvider = Provider<KaraokePlayback Function()>((
  ref,
) {
  final controller = ref.watch(playerControllerProvider.notifier);
  return () => KaraokePlayback(controller);
});

/// Adapts karaoke controls to the app's single playback coordinator and engine.
class KaraokePlayback {
  KaraokePlayback(this._controller);
  final PlayerController _controller;
  final Object _owner = Object();

  bool get _ownsPlayback =>
      _controller.mounted &&
      _controller.current.source == 'KARAOKE' &&
      identical(_owner, _controller.karaokeOwner);
  bool get playing => _ownsPlayback && _controller.current.playing;
  Duration get position =>
      _ownsPlayback ? _controller.current.position : Duration.zero;
  Duration? get duration => _ownsPlayback ? _controller.current.duration : null;
  audio.ProcessingState get processingState => _processing(_controller.current);
  audio.PlayerState get playerState =>
      audio.PlayerState(playing, processingState);

  Stream<audio.PlayerState> get playerStateStream => _controller.stream.map(
    (state) =>
        audio.PlayerState(_ownsPlayback && state.playing, _processing(state)),
  );
  Stream<Duration> get positionStream => _controller.stream
      .map((state) => _ownsPlayback ? state.position : Duration.zero)
      .distinct();

  audio.ProcessingState _processing(PlayerState state) {
    if (!_ownsPlayback || state.track == null) {
      return audio.ProcessingState.idle;
    }
    if (state.completed) return audio.ProcessingState.completed;
    if (state.loading) return audio.ProcessingState.loading;
    return audio.ProcessingState.ready;
  }

  Future<void> loadTrack(Map<String, dynamic> metadata) async {
    // Solo/catalog trả "songId", playback phòng hát trả "trackId" — cùng một
    // ObjectId bài hát trên máy chủ.
    final id =
        optionalText(metadata['songId']) ?? requiredText(metadata, 'trackId');
    final operation = _controller.loadKaraoke(
      Track(
        id: id,
        spotifyId: id,
        name: optionalText(metadata['title']) ?? 'Bài hát',
        artist: optionalText(metadata['artist']) ?? 'Chưa rõ nghệ sĩ',
        image: optionalText(metadata['imageUrl']),
        durationMs: (metadata['durationMs'] as num?)?.toInt() ?? 0,
      ),
      Uri.parse(requiredText(metadata, 'instrumentalUrl')),
      owner: _owner,
    );
    await operation;
  }

  Future<void> play() async {
    if (!_ownsPlayback) return;
    final operation = _controller.play();
    await operation;
    if (_ownsPlayback && _controller.current.failure != null) {
      throw _controller.current.failure!;
    }
  }

  Future<void> pause() => _ownsPlayback ? _controller.pause() : Future.value();
  Future<void> seek(Duration value) =>
      _ownsPlayback ? _controller.seek(value) : Future.value();
  Future<void> stop() async {
    // Screens may release playback during widget disposal.
    await Future<void>.value();
    if (_ownsPlayback) await _controller.clear();
  }
}
