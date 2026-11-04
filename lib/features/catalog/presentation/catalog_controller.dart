import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog_models.dart';

typedef CatalogQuery = ({String? genre, String? query, String? artistId});
const allMusic = (genre: null, query: null, artistId: null);
final catalogControllerProvider = StateNotifierProvider.autoDispose
    .family<CatalogController, CatalogState, CatalogQuery>(
      (ref, query) =>
          CatalogController(ref.watch(catalogRepositoryProvider), query)
            ..load(),
    );
final albumsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(catalogRepositoryProvider).albums(),
);
final artistsProvider = FutureProvider.autoDispose.family<List<Artist>, String>(
  (ref, query) => ref.watch(catalogRepositoryProvider).artists(query),
);

class CatalogState {
  const CatalogState({
    this.tracks = const [],
    this.loading = false,
    this.failure,
    this.nextPage = 0,
    this.hasMore = true,
  });
  final List<Track> tracks;
  final bool loading, hasMore;
  final AppFailure? failure;
  final int nextPage;
}

class CatalogController extends StateNotifier<CatalogState> {
  CatalogController(this.repository, this.query) : super(const CatalogState());
  final CatalogRepository repository;
  final CatalogQuery query;
  CancelToken? _cancel;
  int _generation = 0;
  Future<void> load({bool reset = false}) async {
    if (!reset && (state.loading || !state.hasMore)) return;
    final generation = ++_generation;
    _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    final previous = reset ? const CatalogState() : state;
    state = CatalogState(
      tracks: previous.tracks,
      loading: true,
      nextPage: previous.nextPage,
      hasMore: previous.hasMore,
    );
    try {
      final page = await repository.tracks(
        page: previous.nextPage,
        query: query.query,
        genre: query.genre,
        artistId: query.artistId,
        cancel: cancel,
      );
      if (!mounted || generation != _generation) return;
      final unique = {for (final t in previous.tracks) t.id: t};
      for (final track in page.tracks) {
        unique[track.id] = track;
      }
      state = CatalogState(
        tracks: List.unmodifiable(unique.values),
        nextPage: page.page + 1,
        hasMore: page.hasMore,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = CatalogState(
        tracks: previous.tracks,
        nextPage: previous.nextPage,
        hasMore: previous.hasMore,
        failure: AppFailure.from(error),
      );
    }
  }

  @override
  void dispose() {
    _generation++;
    _cancel?.cancel();
    super.dispose();
  }
}
