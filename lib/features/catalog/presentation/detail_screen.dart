import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../../library/data/library_repository.dart';
import '../../player/presentation/player_controller.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog_models.dart';
import 'catalog_controller.dart';
import 'catalog_widgets.dart';

typedef CollectionKey = ({String id, bool album});
final collectionProvider = FutureProvider.autoDispose
    .family<MusicCollection, CollectionKey>((ref, key) {
      if (key.album) return ref.watch(catalogRepositoryProvider).album(key.id);
      ref.watch(sessionControllerProvider.select((s) => s.session?.user.id));
      return ref.watch(libraryRepositoryProvider).playlist(key.id);
    });

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key, required this.id, required this.album});
  final String id;
  final bool album;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (id: id, album: album);
    final data = ref.watch(collectionProvider(key));
    return Scaffold(
      appBar: AppBar(title: Text(album ? 'Album' : 'Playlist')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => LoadMessage(
          message: 'Không tải được nội dung này.',
          retry: () => ref.invalidate(collectionProvider(key)),
        ),
        data: (item) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: MusicArtwork(image: item.image, size: 224)),
                  const SizedBox(height: 24),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (item.author != null) Text(item.author!),
                  if (item.description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(item.description!),
                    ),
                  const SizedBox(height: 16),
                  Text('${item.tracks.length} bài hát'),
                  if (item.tracks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: FilledButton.icon(
                        onPressed: () => ref
                            .read(playerControllerProvider.notifier)
                            .select(item.tracks, 0),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Phát'),
                      ),
                    ),
                ],
              ),
            ),
            if (item.tracks.isEmpty)
              const LoadMessage(
                message: 'Chưa có bài hát trong danh sách này.',
              ),
            for (var i = 0; i < item.tracks.length; i++)
              TrackTile(track: item.tracks[i], queue: item.tracks, index: i),
          ],
        ),
      ),
    );
  }
}

class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.id, required this.name});
  final String id, name;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (genre: null, query: null, artistId: id);
    final state = ref.watch(catalogControllerProvider(query));
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Bài hát',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (state.loading) const LinearProgressIndicator(),
          if (state.failure != null)
            LoadMessage(
              message: state.failure!.message,
              retry: () =>
                  ref.read(catalogControllerProvider(query).notifier).load(),
            ),
          if (!state.loading && state.failure == null && state.tracks.isEmpty)
            const LoadMessage(message: 'Chưa có bài hát của nghệ sĩ này.'),
          for (var i = 0; i < state.tracks.length; i++)
            TrackTile(track: state.tracks[i], queue: state.tracks, index: i),
          if (state.hasMore && state.tracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: OutlinedButton(
                onPressed: state.loading
                    ? null
                    : () => ref
                          .read(catalogControllerProvider(query).notifier)
                          .load(),
                child: const Text('Xem thêm'),
              ),
            ),
        ],
      ),
    );
  }
}
