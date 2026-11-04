import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/catalog_models.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(
    CatalogRemoteService(ref.watch(authDioProvider)),
    ref.watch(appConfigProvider),
  ),
);

class CatalogRemoteService {
  CatalogRemoteService(this.dio);
  final Dio dio;
  Future<Object?> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancel,
  }) async => (await dio.get<Object?>(
    path,
    queryParameters: query,
    cancelToken: cancel,
  )).data;
  Future<Object?> recommend(String text, CancelToken cancel) async =>
      (await dio.post<Object?>(
        'emotions/recommend',
        data: {'text': text, 'strategy': 'empathy', 'limit': 30},
        cancelToken: cancel,
      )).data;
}

class CatalogRepository {
  CatalogRepository(this.remote, this.config);
  final CatalogRemoteService remote;
  final AppConfig config;
  Future<TrackPage> tracks({
    int page = 0,
    String? query,
    String? genre,
    String? artistId,
    CancelToken? cancel,
  }) async => TrackPage.fromJson(
    objectJson(
      await remote.get(
        artistId == null ? 'tracks' : 'artists/${segment(artistId)}/tracks',
        query: {'page': page, 'size': 24, 'query': ?query, 'genre': ?genre},
        cancel: cancel,
      ),
    ),
  );
  Future<Track> track(String id) async =>
      Track.fromJson(objectJson(await remote.get('tracks/${segment(id)}')));
  Future<List<MusicCollection>> albums() async {
    final json = objectJson(
      await remote.get('albums', query: {'page': 0, 'size': 10}),
    );
    if (json['content'] is! List) throw const FormatException('Invalid albums');
    return (json['content'] as List)
        .map((e) => MusicCollection.fromJson(objectJson(e), album: true))
        .toList();
  }

  Future<MusicCollection> album(String id) async => MusicCollection.fromJson(
    objectJson(await remote.get('albums/${segment(id)}')),
    album: true,
  );
  Future<List<Artist>> artists(String query) async {
    final json = await remote.get('artists', query: {'query': query});
    if (json is! List) throw const FormatException('Invalid artists');
    return json.map((e) => Artist.fromJson(objectJson(e))).take(12).toList();
  }

  Future<List<Track>> mood(String text, CancelToken cancel) async {
    final json = objectJson(await remote.recommend(text, cancel));
    if (json['tracks'] is! List) {
      throw const FormatException('Invalid recommendations');
    }
    return (json['tracks'] as List)
        .map((e) => Track.fromJson(objectJson(e)))
        .toList();
  }

  Uri? artwork(String? value) {
    if (value == null) return null;
    final parsed = Uri.tryParse(value);
    if (parsed == null) return null;
    final uri = config.apiBaseUri.replace(path: '/').resolveUri(parsed);
    if (uri.userInfo.isNotEmpty || !['https', 'http'].contains(uri.scheme)) {
      return null;
    }
    if (uri.scheme == 'http' && config.apiBaseUri.scheme == 'https') {
      return null;
    }
    return uri;
  }

  Future<Uri> stream(Track track) async {
    if (!track.hasAudio) {
      throw const AppFailure('Bài hát này chưa có nguồn âm thanh để phát.');
    }
    final endpoint = config.apiBaseUri.resolve(
      'tracks/${segment(track.id)}/stream',
    );
    // The public stream request never carries a bearer token to the media host.
    final response = await remote.dio.get<ResponseBody>(
      endpoint.toString(),
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: {'Range': 'bytes=0-0'},
        validateStatus: (status) =>
            status == 200 || status == 206 || status == 302 || status == 307,
      ),
    );
    await response.data?.stream.listen((_) {}).cancel();
    final location = response.headers.value('location');
    final uri = location == null ? endpoint : endpoint.resolve(location);
    if (uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(uri.scheme == 'https' ||
            (config.apiBaseUri.scheme == 'http' &&
                uri.origin == endpoint.origin))) {
      throw const AppFailure('Nguồn âm thanh trả về không hợp lệ.');
    }
    return uri;
  }
}
