import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../catalog/domain/catalog_models.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(LibraryRemoteService(ref.watch(apiDioProvider))),
);

class LibraryRemoteService {
  LibraryRemoteService(this.dio);
  final Dio dio;
  Future<Object?> get(String path, {Map<String, dynamic>? query}) async =>
      (await dio.get<Object?>(path, queryParameters: query)).data;
  Future<void> like(String id, bool liked) async {
    final path = 'users/me/library/tracks/${segment(id)}';
    if (liked) {
      await dio.post<void>(path);
    } else {
      await dio.delete<void>(path);
    }
  }

  Future<Object?> create(String name) async => (await dio.post<Object?>(
    'playlists',
    data: {'name': name, 'description': '', 'isPublic': false},
  )).data;
  Future<void> add(String playlistId, String trackId) async {
    await dio.post<Object?>(
      'playlists/${segment(playlistId)}/tracks',
      data: {'trackSpotifyId': trackId},
    );
  }
}

class LibraryRepository {
  LibraryRepository(this.remote);
  final LibraryRemoteService remote;
  Future<TrackPage> tracks(int page) async => TrackPage.fromJson(
    objectJson(
      await remote.get(
        'users/me/library/tracks',
        query: {'page': page, 'size': 24},
      ),
    ),
    library: true,
  );
  Future<Set<String>> likedIds() async {
    final json = await remote.get('users/me/library/track-ids');
    if (json is! List) throw const FormatException('Invalid library ids');
    return json.map((e) => e.toString()).toSet();
  }

  Future<List<MusicCollection>> playlists() async {
    final json = await remote.get('playlists/me');
    if (json is! List) throw const FormatException('Invalid playlists');
    return json.map((e) => MusicCollection.fromJson(objectJson(e))).toList();
  }

  Future<MusicCollection> playlist(String id) async => MusicCollection.fromJson(
    objectJson(await remote.get('playlists/${segment(id)}')),
  );
  Future<void> like(String id, bool liked) => remote.like(id, liked);
  Future<MusicCollection> create(String name) async =>
      MusicCollection.fromJson(objectJson(await remote.create(name.trim())));
  Future<void> add(String id, String trackId) => remote.add(id, trackId);
}
