import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodify_flutter/features/catalog/domain/catalog_models.dart';
import 'package:moodify_flutter/features/search/data/search_history_repository.dart';
import 'package:moodify_flutter/features/search/presentation/search_history_controller.dart';
import 'package:moodify_flutter/features/search/presentation/search_controller.dart';
import '../../support/auth_harness.dart';
import '../../support/music_harness.dart';

class MoodRepository extends MusicRepositoryFake {
  final pending = Completer<MoodResult>();
  @override
  Future<MoodResult> mood(String text, CancelToken cancel) => pending.future;
}

void main() {
  test(
    'mood history waits for valid result; selection belongs to submitted query',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'));
      dio.httpClientAdapter = TestAdapter((options) {
        requests.add(options);
        return jsonResponse(
          options.method == 'GET' ? {'content': []} : {'id': 7},
        );
      });
      final history = SearchHistoryController(
        SearchHistoryRepository(dio),
        true,
      );
      final repository = MoodRepository();
      final search = SearchController(
        repository,
        onSubmitted: (query, mood, result) => history.record(
          query,
          mood,
          emotion: result?.emotion,
          confidence: result?.confidence,
        ),
      );
      search.mode(true);
      search.change('Một tối yên tĩnh');
      final work = search.submit(recordHistory: true);
      expect(requests, isEmpty);
      repository.pending.complete(
        const MoodResult(tracks: [], emotion: 'CALM', confidence: 0.82),
      );
      await work;
      final body = requests.first.data as Map;
      expect(body['searchType'], 'EMOTION');
      expect(body['detectedEmotion'], 'CALM');
      expect(body['emotionConfidence'], 0.82);
      await history.select('other query', true, 'track');
      expect(requests.where((r) => r.method == 'PATCH'), isEmpty);
      await history.select('Một tối yên tĩnh', true, 'track');
      expect(requests.last.method, 'PATCH');
      expect(requests.last.data, {'targetType': 'TRACK', 'targetId': 'track'});
      search.dispose();
      history.dispose();
      dio.close();
      repository.remote.dio.close();
    },
  );

  test(
    'invalid mood is not fabricated and history error stays visible',
    () async {
      final dio = Dio();
      var calls = 0;
      dio.httpClientAdapter = TestAdapter((_) {
        calls++;
        return jsonResponse({});
      });
      final history = SearchHistoryController(
        SearchHistoryRepository(dio),
        true,
      );
      await history.record('mood', true);
      expect(calls, 0);
      expect(history.state.hasError, true);
      history.dispose();
      dio.close();
    },
  );

  test('late mood result never records history for a replaced query', () async {
    final repository = MoodRepository();
    var calls = 0;
    final search = SearchController(
      repository,
      onSubmitted: (_, _, _) async {
        calls++;
      },
    );
    search.mode(true);
    search.change('old');
    final work = search.submit(recordHistory: true);
    search.change('new');
    repository.pending.complete(
      const MoodResult(tracks: [], emotion: 'CALM', confidence: 0.8),
    );
    await work;
    expect(calls, 0);
    search.dispose();
    repository.remote.dio.close();
  });
}
