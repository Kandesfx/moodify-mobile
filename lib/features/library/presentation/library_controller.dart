import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/domain/catalog_models.dart';
import '../data/library_repository.dart';

final libraryControllerProvider =
    StateNotifierProvider.autoDispose<LibraryController, LibraryState>((ref) {
      final user = ref.watch(
        sessionControllerProvider.select((s) => s.session?.user.id),
      );
      return LibraryController(
        ref.watch(libraryRepositoryProvider),
        user != null,
      )..load();
    });

class LibraryState {
  const LibraryState({
    this.tracks = const [],
    this.playlists = const [],
    this.likedIds = const {},
    this.loading = false,
    this.busy = false,
    this.failure,
    this.nextPage = 0,
    this.hasMore = false,
  });
  final List<Track> tracks;
  final List<MusicCollection> playlists;
  final Set<String> likedIds;
  final bool loading, busy, hasMore;
  final AppFailure? failure;
  final int nextPage;
  LibraryState copy({
    List<Track>? tracks,
    List<MusicCollection>? playlists,
    Set<String>? likedIds,
    bool? loading,
    bool? busy,
    int? nextPage,
    bool? hasMore,
    AppFailure? failure,
  }) => LibraryState(
    tracks: tracks ?? this.tracks,
    playlists: playlists ?? this.playlists,
    likedIds: likedIds ?? this.likedIds,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    nextPage: nextPage ?? this.nextPage,
    hasMore: hasMore ?? this.hasMore,
    failure: failure,
  );
}

class LibraryController extends StateNotifier<LibraryState> {
  LibraryController(this.repository, this.authenticated)
    : super(const LibraryState());
  final LibraryRepository repository;
  final bool authenticated;
  Future<void> load({bool more = false}) async {
    if (!authenticated ||
        state.loading ||
        state.busy ||
        (more && !state.hasMore)) {
      return;
    }
    state = state.copy(loading: true);
    try {
      final values = await Future.wait<Object>([
        repository.tracks(more ? state.nextPage : 0),
        repository.playlists(),
        repository.likedIds(),
      ]);
      if (!mounted) return;
      final page = values[0] as TrackPage;
      final tracks = {
        if (more)
          for (final t in state.tracks) t.id: t,
        for (final t in page.tracks) t.id: t,
      };
      state = LibraryState(
        tracks: List.unmodifiable(tracks.values),
        playlists: values[1] as List<MusicCollection>,
        likedIds: values[2] as Set<String>,
        nextPage: page.page + 1,
        hasMore: page.hasMore,
      );
    } catch (error) {
      if (mounted) {
        state = state.copy(loading: false, failure: AppFailure.from(error));
      }
    }
  }

  Future<bool> _mutate(Future<void> Function() operation) async {
    if (!authenticated || state.busy || state.loading) return false;
    state = state.copy(busy: true);
    try {
      await operation();
      if (!mounted) return false;
      state = state.copy(busy: false);
      await load();
      return true;
    } catch (error) {
      if (mounted) {
        state = state.copy(busy: false, failure: AppFailure.from(error));
      }
      return false;
    }
  }

  Future<bool> toggleLike(Track track) => _mutate(() async {
    final liked = !state.likedIds.contains(track.spotifyId);
    await repository.like(track.spotifyId, liked);
    if (!mounted) return;
    final ids = {...state.likedIds};
    if (liked) {
      ids.add(track.spotifyId);
    } else {
      ids.remove(track.spotifyId);
    }
    state = state.copy(
      likedIds: ids,
      tracks: liked
          ? state.tracks
          : state.tracks.where((t) => t.spotifyId != track.spotifyId).toList(),
    );
  });
  Future<bool> create(String name) => _mutate(() async {
    final playlist = await repository.create(name);
    if (mounted) state = state.copy(playlists: [...state.playlists, playlist]);
  });
  Future<bool> add(String id, Track track) =>
      _mutate(() => repository.add(id, track.spotifyId));
}
