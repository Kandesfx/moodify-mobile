import 'dart:async';

import 'package:dio/dio.dart';
import 'package:moodify_flutter/core/config/app_config.dart';
import 'package:moodify_flutter/features/catalog/data/catalog_repository.dart';
import 'package:moodify_flutter/features/catalog/domain/catalog_models.dart';
import 'package:moodify_flutter/features/player/data/playback_engine.dart';

const firstTrack = Track(
  id: 'internal-1',
  spotifyId: 'spotify-1',
  name: 'Test song one',
  artist: 'Test artist',
  localPath: 'audio/one.mp3',
  durationMs: 120000,
);
const secondTrack = Track(
  id: 'internal-2',
  spotifyId: 'spotify-2',
  name: 'Test song two',
  artist: 'Test artist',
  localPath: 'audio/two.mp3',
  durationMs: 120000,
);

class MusicRepositoryFake extends CatalogRepository {
  MusicRepositoryFake()
    : super(
        CatalogRemoteService(Dio()),
        AppConfig(apiBaseUrl: 'https://api.example.test/api'),
      );
  Future<Track> Function(String)? onTrack;
  Future<TrackPage> Function(int, String?)? onTracks;
  final queries = <String?>[];
  @override
  Future<Track> track(String id) async => onTrack != null
      ? onTrack!(id)
      : id == firstTrack.id
      ? firstTrack
      : secondTrack;
  @override
  Future<Uri> stream(Track track) async =>
      Uri.parse('https://media.example.test/${track.id}.mp3');
  @override
  Future<TrackPage> tracks({
    int page = 0,
    String? query,
    String? genre,
    String? artistId,
    CancelToken? cancel,
  }) async {
    queries.add(query);
    return onTracks != null
        ? onTracks!(page, query)
        : const TrackPage([firstTrack], 0, 1, 1);
  }

  @override
  Future<MoodResult> mood(String text, CancelToken cancel) async {
    queries.add(text);
    return const MoodResult(tracks: []);
  }
}

class PlaybackEngineFake implements PlaybackEngine {
  @override
  Future<void> volume(double value) async {}
  final controller = StreamController<EngineEvent>.broadcast(sync: true);
  final loaded = <String>[];
  int resumes = 0, pauses = 0, stops = 0;
  bool disposed = false;
  Duration sought = Duration.zero;
  Duration resumeDuration = const Duration(minutes: 2);
  PlayerCommands? commands;
  @override
  Stream<EngineEvent> get events => controller.stream;
  @override
  void bind(PlayerCommands commands) => this.commands = commands;
  @override
  Future<void> load(Uri uri, Track track) async {
    loaded.add(track.id);
  }

  final ads = <String>[];
  @override
  Future<Duration?> loadAd(String asset) async {
    ads.add(asset);
    return const Duration(seconds: 30);
  }

  @override
  Future<void> resume() async {
    resumes++;
    controller.add(EngineEvent(playing: true, duration: resumeDuration));
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> seek(Duration position) async {
    sought = position;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }
}

Future<void> flushMusic() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
