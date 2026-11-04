import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';

import '../../auth/presentation/session_controller.dart';
import '../../catalog/domain/catalog_models.dart';
import 'playlist_dialog.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import 'library_controller.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(
          sessionControllerProvider.select((s) => s.session?.user.id),
        ) ==
        null) {
      return const GuestPrompt(
        title: 'Thư viện',
        message: 'Đăng nhập để lưu bài hát yêu thích và tạo playlist của bạn.',
        returnTo: '/library',
      );
    }
    final state = ref.watch(libraryControllerProvider);
    final controller = ref.read(libraryControllerProvider.notifier);
    final albums = ref.watch(favoriteAlbumsProvider);
    return DefaultTabController(
      length: 3,
      animationDuration: AppMotion.duration(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thư viện'),
          actions: [
            IconButton(
              tooltip: 'Nhạc đã tải',
              onPressed: () => context.push('/offline'),
              icon: const Icon(Icons.download_for_offline_outlined),
            ),
            IconButton(
              tooltip: 'Tạo playlist',
              onPressed: state.busy || state.loading
                  ? null
                  : () => showCreatePlaylist(context),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.secondary,
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            tabs: [
              Tab(text: 'Playlist'),
              Tab(text: 'Yêu thích'),
              Tab(text: 'Album'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                children: [
                  if (state.loading) const LinearProgressIndicator(),
                  if (state.failure != null)
                    LoadMessage(
                      message: state.failure!.message,
                      retry: controller.load,
                    ),
                  if (!state.loading &&
                      state.playlists.isEmpty &&
                      state.failure == null)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          const Icon(Icons.queue_music_rounded, size: 64),
                          const SizedBox(height: 20),
                          Text(
                            'Nhạc của bạn, theo cách của bạn',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Gom những bài bạn muốn nghe vào một playlist.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => showCreatePlaylist(context),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Tạo playlist đầu tiên'),
                          ),
                        ],
                      ),
                    ),
                  for (final playlist in state.playlists)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: MusicArtwork(image: playlist.image, size: 64),
                      title: Text(playlist.title),
                      subtitle: Text(
                        '${playlist.trackCount} bài hát · ${playlist.isPublic ? 'Công khai' : 'Riêng tư'}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          context.push('/playlist/${segment(playlist.id)}'),
                    ),
                ],
              ),
            ),
            RefreshIndicator(
              onRefresh: controller.load,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                itemCount: state.tracks.length + 2,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Column(
                      children: [
                        if (state.loading) const LinearProgressIndicator(),
                        if (state.failure != null)
                          LoadMessage(
                            message: state.failure!.message,
                            retry: controller.load,
                          ),
                        if (state.tracks.isEmpty &&
                            !state.loading &&
                            state.failure == null)
                          Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.favorite_border_rounded,
                                  size: 64,
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Lưu những bài bạn muốn nghe lại.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                OutlinedButton(
                                  onPressed: () => context.go('/search'),
                                  child: const Text('Tìm bài hát'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  }
                  if (i > state.tracks.length) {
                    return state.hasMore
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: OutlinedButton(
                              onPressed: state.loading || state.busy
                                  ? null
                                  : () => controller.load(more: true),
                              child: const Text('Xem thêm'),
                            ),
                          )
                        : const SizedBox();
                  }
                  return TrackTile(
                    track: state.tracks[i - 1],
                    queue: state.tracks,
                    index: i - 1,
                  );
                },
              ),
            ),
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(favoriteAlbumsProvider);
                await ref.read(favoriteAlbumsProvider.future);
              },
              child: albums.when(
                loading: () =>
                    ListView(children: const [LinearProgressIndicator()]),
                error: (_, _) => ListView(
                  children: [
                    LoadMessage(
                      message: 'Chưa tải được album đã lưu.',
                      retry: () => ref.invalidate(favoriteAlbumsProvider),
                    ),
                  ],
                ),
                data: (items) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    if (items.isEmpty)
                      const LoadMessage(
                        message: 'Album bạn lưu sẽ xuất hiện ở đây.',
                      ),
                    for (final album in items)
                      ListTile(
                        leading: MusicArtwork(image: album.image, size: 64),
                        title: Text(album.title),
                        subtitle: Text(album.author ?? 'Album'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            context.push('/album/${segment(album.id)}'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
