import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../../core/config/app_config.dart';
import '../../catalog/domain/catalog_models.dart';
import '../domain/recommendation_models.dart';

final recommendationRepositoryProvider = Provider<RecommendationRepository>(
  (ref) => RecommendationRepository(
    ref.watch(apiDioProvider),
    ref.watch(appConfigProvider),
  ),
);

class RecommendationRepository {
  RecommendationRepository(this.dio, this.config);
  final Dio dio;
  final AppConfig config;

  Future<RecommendationHome> fetchHome({
    String? genre,
    CancelToken? cancel,
  }) async {
    final query = <String, dynamic>{};
    if (genre != null && genre.trim().isNotEmpty && genre != 'ALL') {
      query['genre'] = genre;
    }
    final res = await dio.get<Object?>(
      'recommendations/home',
      queryParameters: query.isEmpty ? null : query,
      cancelToken: cancel,
    );
    return RecommendationHome.fromJson(objectJson(res.data));
  }

  Future<void> sendFeedback({
    required String entityType,
    required String entityId,
    required String feedbackType,
    required bool enabled,
  }) async {
    await dio.put<void>(
      'recommendations/feedback',
      data: {
        'entityType': entityType,
        'entityId': entityId,
        'feedbackType': feedbackType,
        'enabled': enabled,
      },
    );
  }

  Future<void> recordEvent({
    required String eventType,
    required String attributionToken,
  }) async {
    if (attributionToken.isEmpty) return;
    try {
      await dio.post<void>(
        'recommendations/events',
        data: {
          'events': [
            {
              'eventId': DateTime.now().microsecondsSinceEpoch.toString(),
              'eventType': eventType,
              'attributionToken': attributionToken,
              'occurredAt': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        },
      );
    } catch (_) {
      // Event logging should never block user interaction
    }
  }

  Future<PersonalizedMix> fetchPersonalizedMix(
    String mixId, {
    CancelToken? cancel,
  }) async {
    final res = await dio.get<Object?>(
      'me/personalized-playlists/${segment(mixId)}',
      cancelToken: cancel,
    );
    return PersonalizedMix.fromJson(objectJson(res.data));
  }

  Future<PersonalizedMix> refreshPersonalizedMix(String mixId) async {
    final res = await dio.post<Object?>(
      'me/personalized-playlists/${segment(mixId)}/refresh',
    );
    return PersonalizedMix.fromJson(objectJson(res.data));
  }

  Future<Map<String, dynamic>> copyPersonalizedMix(
    String mixId, {
    required String versionId,
    required String requestId,
  }) async {
    final res = await dio.post<Object?>(
      'me/personalized-playlists/${segment(mixId)}/copies',
      data: {'versionId': versionId, 'requestId': requestId},
    );
    return objectJson(res.data);
  }

  Future<List<Track>> fetchMixTracks(
    String mixId, {
    CancelToken? cancel,
  }) async {
    final mix = await fetchPersonalizedMix(mixId, cancel: cancel);
    return mix.tracks;
  }
}
