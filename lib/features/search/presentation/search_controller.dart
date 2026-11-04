import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_models.dart';

final searchControllerProvider =
    StateNotifierProvider.autoDispose<SearchController, SearchState>(
      (ref) => SearchController(ref.watch(catalogRepositoryProvider)),
    );

class SearchState {
  const SearchState({
    this.query = '',
    this.mood = false,
    this.loading = false,
    this.submitted = false,
    this.tracks = const [],
    this.failure,
    this.nextPage = 0,
    this.hasMore = false,
  });
  final String query;
  final bool mood, loading, submitted, hasMore;
  final List<Track> tracks;
  final AppFailure? failure;
  final int nextPage;
}

class SearchController extends StateNotifier<SearchState> {
  SearchController(this.repository) : super(const SearchState());
  final CatalogRepository repository;
  Timer? _timer;
  CancelToken? _cancel;
  int _generation = 0;
  void change(String text) {
    _timer?.cancel();
    _cancel?.cancel();
    _generation++;
    state = SearchState(query: text, mood: state.mood);
    if (!state.mood && text.trim().isNotEmpty) {
      _timer = Timer(const Duration(milliseconds: 400), submit);
    }
  }

  void mode(bool mood) {
    _timer?.cancel();
    _cancel?.cancel();
    _generation++;
    state = SearchState(query: state.query, mood: mood);
    if (!mood && state.query.trim().isNotEmpty) unawaited(submit());
  }

  Future<void> submit({bool more = false}) async {
    _timer?.cancel();
    if (state.query.trim().isEmpty ||
        (more && (state.loading || !state.hasMore))) {
      return;
    }
    _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    final generation = ++_generation;
    final previous = state;
    state = SearchState(
      query: previous.query,
      mood: previous.mood,
      loading: true,
      submitted: true,
      tracks: more ? previous.tracks : const [],
      nextPage: more ? previous.nextPage : 0,
      hasMore: previous.hasMore,
    );
    try {
      final page = previous.mood
          ? null
          : await repository.tracks(
              query: previous.query.trim(),
              page: more ? previous.nextPage : 0,
              cancel: cancel,
            );
      final tracks =
          page?.tracks ?? await repository.mood(previous.query.trim(), cancel);
      if (!mounted || generation != _generation) return;
      final unique = {
        if (more)
          for (final t in previous.tracks) t.id: t,
        for (final t in tracks) t.id: t,
      };
      state = SearchState(
        query: previous.query,
        mood: previous.mood,
        submitted: true,
        tracks: List.unmodifiable(unique.values),
        nextPage: (page?.page ?? 0) + 1,
        hasMore: page?.hasMore ?? false,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = SearchState(
        query: previous.query,
        mood: previous.mood,
        submitted: true,
        tracks: more ? previous.tracks : const [],
        failure: AppFailure.from(error),
        nextPage: more ? previous.nextPage : 0,
        hasMore: more && previous.hasMore,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancel?.cancel();
    _generation++;
    super.dispose();
  }
}
