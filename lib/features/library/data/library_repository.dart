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

  Future<void> delete(String path) async => dio.delete<void>(path);
  Future<void> visibility(String id, bool value) async => dio.patch<Object?>(
    'playlists/${segment(id)}/visibility',
    queryParameters: {'isPublic': value},
  );
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
  Future<void> removeTrack(String id, String trackId) =>
      remote.delete('playlists/${segment(id)}/tracks/${segment(trackId)}');
  Future<void> deletePlaylist(String id) =>
      remote.delete('playlists/${segment(id)}');
  Future<void> visibility(String id, bool value) =>
      remote.visibility(id, value);
  Future<List<MusicCollection>> favoriteAlbums() async {
    final json = await remote.get('albums/favorites/me');
    if (json is! List) throw const FormatException('Invalid favorite albums');
    return json
        .map((e) => MusicCollection.fromJson(objectJson(e), album: true))
        .toList();
  }

  Future<bool> albumFavorite(String id) async =>
      objectJson(
        await remote.get('albums/${segment(id)}/favorite/status'),
      )['favorited'] ==
      true;
  Future<bool> toggleAlbum(String id) async {
    final json = objectJson(
      (await remote.dio.post<Object?>('albums/${segment(id)}/favorite')).data,
    );
    if (json['favorited'] is! bool) {
      throw const FormatException('Invalid favorite status');
    }
    return json['favorited'] as bool;
  }
}
