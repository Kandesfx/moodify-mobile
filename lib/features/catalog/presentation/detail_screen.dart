import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../../library/presentation/collection_actions.dart';
import '../../library/presentation/library_controller.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_failure.dart';
import '../../player/presentation/player_controller.dart';
import '../domain/catalog_models.dart';
import 'catalog_controller.dart';
import 'catalog_widgets.dart';

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key, required this.id, required this.album});
  final String id;
  final bool album;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (id: id, album: album);
    final data = ref.watch(collectionProvider(key));
    final actions = ref.watch(collectionActionsProvider(key));
    final user = ref.watch(sessionControllerProvider).session?.user;
    final owned =
        !album && user != null && data.valueOrNull?.author == user.username;
    final favorite = album
        ? ref.watch(albumFavoriteProvider(id)).valueOrNull
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(album ? 'Album' : 'Playlist'),
        actions: [
          if (album)
            IconButton(
              tooltip: favorite == true ? 'Bỏ lưu album' : 'Lưu album',
              onPressed: actions.isLoading
                  ? null
                  : () async {
                      if (user == null) {
                        context.push(
                          '/sign-in?from=${Uri.encodeComponent('/album/${segment(id)}')}',
                        );
                        return;
                      }
                      await ref
                          .read(collectionActionsProvider(key).notifier)
                          .run((r) async {
                            await r.toggleAlbum(id);
                          });
                    },
              icon: Icon(
                favorite == true
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
            ),
          if (owned)
            PopupMenuButton<String>(
              enabled: !actions.isLoading,
              onSelected: (action) async {
                if (action == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Xóa playlist?'),
                      content: const Text(
                        'Playlist sẽ bị xóa khỏi tài khoản. Các bài hát gốc vẫn được giữ lại.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Giữ lại'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Xóa playlist'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;
                  final success = await ref
                      .read(collectionActionsProvider(key).notifier)
                      .run((r) => r.deletePlaylist(id));
                  if (success && context.mounted) {
                    context.canPop() ? context.pop() : context.go('/library');
                  }
                } else {
                  final value = !(data.valueOrNull?.isPublic ?? false);
                  if (value) {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Công khai playlist?'),
                        content: const Text(
                          'Người khác có thể tìm và xem playlist này.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Hủy'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Công khai'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                  }
                  await ref
                      .read(collectionActionsProvider(key).notifier)
                      .run((r) => r.visibility(id, value));
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'visibility',
                  child: Text(
                    data.valueOrNull?.isPublic == true
                        ? 'Chuyển sang riêng tư'
                        : 'Công khai playlist',
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Xóa playlist'),
                ),
              ],
            ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => LoadMessage(
          message: 'Không tải được nội dung này.',
          retry: () => ref.invalidate(collectionProvider(key)),
        ),
        data: (item) => ListView(
          children: [
            if (actions.isLoading) const LinearProgressIndicator(),
            if (actions.hasError)
              LoadMessage(message: AppFailure.from(actions.error!).message),
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
                  Text(
                    '${item.tracks.length} bài hát${album
                        ? ''
                        : item.isPublic
                        ? ' · Công khai'
                        : ' · Riêng tư'}',
                  ),
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
              LoadMessage(
                message: 'Chưa có bài hát trong danh sách này.',
                retry: owned ? () => context.go('/search') : null,
                retryLabel: 'Tìm bài hát',
              ),
            for (var i = 0; i < item.tracks.length; i++)
              TrackTile(
                track: item.tracks[i],
                queue: item.tracks,
                index: i,
                remove: owned && !actions.isLoading
                    ? () async {
                        await ref
                            .read(collectionActionsProvider(key).notifier)
                            .run(
                              (r) =>
                                  r.removeTrack(id, item.tracks[i].spotifyId),
                            );
                      }
                    : null,
              ),
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
