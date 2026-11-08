import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_motion.dart';
import '../../auth/presentation/session_controller.dart';
import '../../library/presentation/collection_actions.dart';
import '../../library/presentation/library_controller.dart';
import '../../player/presentation/player_controller.dart';
import '../../player/presentation/player_screen.dart';
import '../data/artist_repository.dart';
import '../domain/catalog_models.dart';
import 'artwork_backdrop.dart';
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
      bottomNavigationBar: const MiniPlayer(),
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
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
        error: (error, _) => LoadMessage(
          message: AppFailure.from(error).message,
          retry: () => ref.invalidate(collectionProvider(key)),
        ),
        data: (item) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              // Header artwork/tiêu đề vào nhẹ một lần khi mở detail.
              child: SectionEntrance(
                child: Column(
                  children: [
                    if (actions.isLoading) const LinearProgressIndicator(),
                    if (actions.hasError)
                      LoadMessage(
                        message: AppFailure.from(actions.error!).message,
                      ),
                    Stack(
                      children: [
                        Positioned.fill(
                          child: ArtworkBackdrop(image: item.image, hero: true),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x66000000),
                                        blurRadius: 28,
                                        offset: Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: MusicArtwork(
                                    image: item.image,
                                    size: 216,
                                    radius: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                item.title,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              if (item.author != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.author!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                              if (item.description != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    item.description!,
                                    style: const TextStyle(
                                      color: AppColors.secondary,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Text(
                                '${item.tracks.length} bài hát${album
                                    ? ''
                                    : item.isPublic
                                    ? ' · Công khai'
                                    : ' · Riêng tư'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (item.tracks.isNotEmpty)
                                    FilledButton.icon(
                                      onPressed: () => ref
                                          .read(
                                            playerControllerProvider.notifier,
                                          )
                                          .playCollection(
                                            item.tracks,
                                            source: album
                                                ? 'ALBUM'
                                                : 'PLAYLIST',
                                          ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: AppColors.background,
                                        shape: const StadiumBorder(),
                                      ),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                      ),
                                      label: const Text('Phát'),
                                    ),
                                  if (item.tracks.isNotEmpty)
                                    OutlinedButton.icon(
                                      onPressed: () => ref
                                          .read(
                                            playerControllerProvider.notifier,
                                          )
                                          .playCollection(
                                            item.tracks,
                                            shuffled: true,
                                            source: album
                                                ? 'ALBUM'
                                                : 'PLAYLIST',
                                          ),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: AppColors.surfaceGlass,
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        shape: const StadiumBorder(),
                                      ),
                                      icon: const Icon(Icons.shuffle),
                                      label: const Text('Trộn bài'),
                                    ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      final isAlbum = album;
                                      final url = isAlbum
                                          ? 'https://moodify.click/dashboard/player?album=${item.id}'
                                          : 'https://moodify.click/dashboard/player?playlist=${item.id}';
                                      final label = isAlbum
                                          ? 'album'
                                          : 'playlist';
                                      final text =
                                          'Nghe $label "${item.title}" trên Moodify:\n$url';
                                      SharePlus.instance.share(
                                        ShareParams(
                                          text: text,
                                          subject: '${item.title} — Moodify',
                                          title:
                                              'Chia sẻ $label "${item.title}"',
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: AppColors.surfaceRaised,
                                      side: const BorderSide(
                                        color: AppColors.borderSoft,
                                      ),
                                      shape: const StadiumBorder(),
                                    ),
                                    icon: const Icon(Icons.share_outlined),
                                    label: const Text('Chia sẻ'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (item.tracks.isEmpty)
                      LoadMessage(
                        message: 'Chưa có bài hát trong danh sách này.',
                        retry: owned ? () => context.go('/search') : null,
                        retryLabel: 'Tìm bài hát',
                      ),
                  ],
                ),
              ),
            ),
            SliverList.builder(
              itemCount: item.tracks.length,
              itemBuilder: (_, i) => TrackTile(
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
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
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
    final tracks = ref.watch(catalogControllerProvider(query));
    final profile = ref.watch(artistProfileProvider(id));
    final action = ref.watch(artistFollowActionProvider(id));
    final user = ref.watch(sessionControllerProvider).session?.user.id;
    return Scaffold(
      bottomNavigationBar: const MiniPlayer(),
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(profile.valueOrNull?.name ?? name),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            // Header nghệ sĩ vào nhẹ một lần khi mở trang.
            child: SectionEntrance(
              child: Stack(
                children: [
                  if (profile.valueOrNull?.image != null)
                    Positioned.fill(
                      child: ArtworkBackdrop(
                        image: profile.valueOrNull!.image,
                        hero: true,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (profile.isLoading) const LinearProgressIndicator(),
                        if (profile.hasError)
                          LoadMessage(
                            message: AppFailure.from(profile.error!).message,
                            retry: () =>
                                ref.invalidate(artistProfileProvider(id)),
                          ),
                        if (profile.valueOrNull case final person?) ...[
                          Center(
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x66000000),
                                    blurRadius: 24,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: MusicArtwork(
                                image: person.image,
                                size: 168,
                                round: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            person.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          if (person.followers != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${person.followers} người theo dõi',
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (person.bio != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceRaised,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.borderSoft,
                                  ),
                                ),
                                child: Text(
                                  person.bio!,
                                  style: const TextStyle(
                                    color: AppColors.secondary,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: action.isLoading
                                    ? null
                                    : () {
                                        if (user == null) {
                                          context.push(
                                            '/sign-in?from=${Uri.encodeComponent('/artist/${segment(id)}')}',
                                          );
                                          return;
                                        }
                                        ref
                                            .read(
                                              artistFollowActionProvider(
                                                id,
                                              ).notifier,
                                            )
                                            .run();
                                      },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: person.followed
                                      ? AppColors.surfaceGlass
                                      : AppColors.surfaceRaised,
                                  side: BorderSide(
                                    color: person.followed
                                        ? AppColors.border
                                        : AppColors.borderSoft,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                icon: Icon(
                                  person.followed
                                      ? Icons.check
                                      : Icons.person_add_outlined,
                                ),
                                label: Text(
                                  person.followed
                                      ? 'Đang theo dõi'
                                      : 'Theo dõi',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  final url =
                                      'https://moodify.click/dashboard/artists/${person.id}';
                                  final text =
                                      'Khám phá âm nhạc của nghệ sĩ ${person.name} trên Moodify:\n$url';
                                  SharePlus.instance.share(
                                    ShareParams(
                                      text: text,
                                      subject:
                                          'Nghệ sĩ ${person.name} — Moodify',
                                      title: 'Chia sẻ nghệ sĩ "${person.name}"',
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: AppColors.surfaceRaised,
                                  side: const BorderSide(
                                    color: AppColors.borderSoft,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                icon: const Icon(Icons.share_outlined),
                                label: const Text('Chia sẻ'),
                              ),
                            ],
                          ),
                          if (action.hasError)
                            LoadMessage(
                              message: AppFailure.from(action.error!).message,
                            ),
                          const SizedBox(height: 10),
                        ],
                        if (tracks.tracks.isNotEmpty)
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: () => ref
                                    .read(playerControllerProvider.notifier)
                                    .playCollection(
                                      tracks.tracks,
                                      source: 'ARTIST',
                                    ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.background,
                                  shape: const StadiumBorder(),
                                ),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Phát danh sách'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => ref
                                    .read(playerControllerProvider.notifier)
                                    .playCollection(
                                      tracks.tracks,
                                      shuffled: true,
                                      source: 'ARTIST',
                                    ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: AppColors.surfaceGlass,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                icon: const Icon(Icons.shuffle),
                                label: const Text('Trộn bài'),
                              ),
                            ],
                          ),
                        if (tracks.hasMore) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Phát các bài đã tải trong danh sách. Chọn Xem thêm để tải tiếp.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                        if (profile.valueOrNull?.albums.isNotEmpty == true) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Album',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          for (final album in profile.valueOrNull!.albums)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF12141A),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.borderSoft,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  leading: MusicArtwork(
                                    image: album.image,
                                    size: 52,
                                    radius: 12,
                                  ),
                                  title: Text(
                                    album.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.secondary,
                                  ),
                                  onTap: () => context.push(
                                    '/album/${segment(album.id)}',
                                  ),
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'Bài hát',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (tracks.loading) const LinearProgressIndicator(),
                        if (tracks.failure != null)
                          LoadMessage(
                            message: tracks.failure!.message,
                            retry: () => ref
                                .read(catalogControllerProvider(query).notifier)
                                .load(),
                          ),
                        if (!tracks.loading &&
                            tracks.failure == null &&
                            tracks.tracks.isEmpty)
                          const LoadMessage(
                            message: 'Chưa có bài hát của nghệ sĩ này.',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: tracks.tracks.length,
            itemBuilder: (_, i) => TrackTile(
              track: tracks.tracks[i],
              queue: tracks.tracks,
              index: i,
            ),
          ),
          if (tracks.hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: OutlinedButton(
                  onPressed: tracks.loading
                      ? null
                      : () => ref
                            .read(catalogControllerProvider(query).notifier)
                            .load(),
                  child: const Text('Xem thêm'),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}
