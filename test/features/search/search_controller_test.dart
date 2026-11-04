import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/catalog/domain/catalog_models.dart';
import 'package:moodify_flutter/features/search/presentation/search_controller.dart';

import '../../support/music_harness.dart';

void main() {
  testWidgets(
    'debounce only requests final text and stale results cannot replace it',
    (tester) async {
      final repository = MusicRepositoryFake();
      final pending = Completer<TrackPage>();
      repository.onTracks = (_, query) async => query == 'first'
          ? pending.future
          : const TrackPage([secondTrack], 0, 1, 1);
      final search = SearchController(repository);
      search.change('f');
      await tester.pump(const Duration(milliseconds: 200));
      search.change('first');
      await tester.pump(const Duration(milliseconds: 400));
      expect(repository.queries, ['first']);
      search.change('second');
      await tester.pump(const Duration(milliseconds: 400));
      expect(search.state.tracks.single.id, secondTrack.id);
      pending.complete(const TrackPage([firstTrack], 0, 1, 1));
      await tester.pump();
      expect(search.state.tracks.single.id, secondTrack.id);
      search.dispose();
      repository.remote.dio.close();
    },
  );
  testWidgets(
    'mood waits for explicit submit and preserves empty recommendation',
    (tester) async {
      final repository = MusicRepositoryFake();
      final search = SearchController(repository);
      search.mode(true);
      search.change('A quiet evening');
      await tester.pump(const Duration(seconds: 1));
      expect(repository.queries, isEmpty);
      await search.submit();
      expect(repository.queries, ['A quiet evening']);
      expect(search.state.tracks, isEmpty);
      expect(search.state.submitted, true);
      search.change('');
      await search.submit();
      expect(repository.queries.length, 1);
      search.dispose();
      repository.remote.dio.close();
    },
  );
}
