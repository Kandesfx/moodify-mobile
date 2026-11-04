import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_models.dart';
import '../data/library_repository.dart';
import 'library_controller.dart';

typedef CollectionKey = ({String id, bool album});
final collectionProvider = FutureProvider.autoDispose
    .family<MusicCollection, CollectionKey>((ref, key) {
      if (key.album) return ref.watch(catalogRepositoryProvider).album(key.id);
      ref.watch(sessionControllerProvider.select((s) => s.session?.user.id));
      return ref.watch(libraryRepositoryProvider).playlist(key.id);
    });

final collectionActionsProvider = StateNotifierProvider.autoDispose
    .family<CollectionActions, AsyncValue<void>, CollectionKey>((ref, key) {
      ref.watch(sessionControllerProvider.select((s) => s.session?.user.id));
      return CollectionActions(ref.watch(libraryRepositoryProvider), () {
        ref.invalidate(collectionProvider(key));
        ref.invalidate(favoriteAlbumsProvider);
        ref.invalidate(albumFavoriteProvider(key.id));
        ref.invalidate(libraryControllerProvider);
      });
    });

class CollectionActions extends StateNotifier<AsyncValue<void>> {
  CollectionActions(this.repository, this.changed)
    : super(const AsyncData(null));
  final LibraryRepository repository;
  final void Function() changed;

  Future<bool> run(Future<void> Function(LibraryRepository) action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await action(repository);
      if (!mounted) return false;
      state = const AsyncData(null);
      changed();
      return true;
    } catch (error, stack) {
      if (mounted) state = AsyncError(AppFailure.from(error), stack);
      return false;
    }
  }
}
