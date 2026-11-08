import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/studio_banners.dart';

import '../../auth/presentation/session_controller.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../offline/presentation/offline_screen.dart';
import 'playlist_dialog.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import 'library_controller.dart';
import '../../catalog/data/artist_repository.dart';
import '../../player/presentation/player_controller.dart';
import '../../subscriptions/application/premium_controller.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionControllerProvider);
    if (sessionState.session?.user.id == null) {
      if (sessionState.offlineUserId != null) {
        return const OfflineScreen();
      }
      return const GuestPrompt(
        title: 'Thư viện',
        message: 'Đăng nhập để lưu bài hát yêu thích và tạo playlist của bạn.',
        returnTo: '/library',
      );
    }
    final state = ref.watch(libraryControllerProvider);
    final controller = ref.read(libraryControllerProvider.notifier);
    final albums = ref.watch(favoriteAlbumsProvider);
    final isPremium = ref.watch(premiumProvider.select((s) => s.isPremium));
    return DefaultTabController(
      length: 4,
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
            // Nút tạo playlist chỉ nằm ở tab Playlist; ở tab khác nó thu
            // gọn và mờ dần để nút tải nhạc vào sát góc phải.
            Builder(
              builder: (context) {
                final tabController = DefaultTabController.of(context);
                return AnimatedBuilder(
                  animation: tabController,
                  builder: (context, _) {
                    final onPlaylistTab = tabController.index == 0;
                    return AnimatedSize(
                      duration: AppMotion.duration(context),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerRight,
                      child: AnimatedOpacity(
                        duration: AppMotion.duration(context),
                        opacity: onPlaylistTab ? 1 : 0,
                        child: SizedBox(
                          width: onPlaylistTab ? null : 0,
                          child: IconButton(
                            tooltip: 'Tạo playlist',
                            onPressed: state.busy || state.loading
                                ? null
                                : () => showCreatePlaylist(context),
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
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
            indicatorPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 4),
            indicator: BoxDecoration(
              color: Color(0xFF222631),
              borderRadius: BorderRadius.all(Radius.circular(999)),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0x33FFFFFF)),
              ),
            ),
            tabs: [
              Tab(text: 'Playlist'),
              Tab(text: 'Yêu thích'),
              Tab(text: 'Album'),
              Tab(text: 'Nghệ sĩ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Nội dung mỗi tab vào nhẹ một lần khi tab được mở.
            SectionEntrance(
              child: RefreshIndicator(
                onRefresh: controller.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: StudioHeroBanner(
                        imageAsset: MoodifyWebAssets.tunedMomentBanner,
                        eyebrow: 'THƯ VIỆN CÁ NHÂN',
                        eyebrowIcon: Icons.library_music_rounded,
                        title: 'Bộ sưu tập giai điệu của bạn',
                        subtitle:
                            'Sắp xếp các playlist cá nhân, lưu bài hát yêu thích và quản lý nhạc tải về trên thiết bị.',
                        footer: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: state.busy || state.loading
                                  ? null
                                  : () => showCreatePlaylist(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.background,
                                minimumSize: const Size(44, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Playlist mới'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.push('/offline'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0x33141720),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(44, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                side: const BorderSide(
                                  color: Color(0x38FFFFFF),
                                ),
                                shape: const StadiumBorder(),
                              ),
                              icon: const Icon(
                                Icons.download_for_offline_outlined,
                                size: 18,
                              ),
                              label: const Text('Nhạc đã tải'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.push('/history'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0x33141720),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(44, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                side: const BorderSide(
                                  color: Color(0x38FFFFFF),
                                ),
                                shape: const StadiumBorder(),
                              ),
                              icon: const Icon(Icons.history_rounded, size: 18),
                              label: const Text('Lịch sử nghe'),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 28,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.borderSoft),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceGlass,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(
                                  Icons.queue_music_rounded,
                                  size: 30,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Nhạc của bạn, theo cách của bạn',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Gom những bài bạn muốn nghe vào một playlist.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.secondary),
                              ),
                              const SizedBox(height: 22),
                              FilledButton.icon(
                                onPressed: () => showCreatePlaylist(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.background,
                                  shape: const StadiumBorder(),
                                ),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Tạo playlist đầu tiên'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final playlist in state.playlists)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF12141A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x10FFFFFF)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            leading: MusicArtwork(
                              image: playlist.image,
                              size: 56,
                              radius: 12,
                            ),
                            title: Text(
                              playlist.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${playlist.trackCount} bài hát · ${playlist.isPublic ? 'Công khai' : 'Riêng tư'}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.secondary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.secondary,
                            ),
                            onTap: () => context.push(
                              '/playlist/${segment(playlist.id)}',
                            ),
                          ),
                        ),
                      ),
                    if (!isPremium)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(14, 14, 14, 8),
                        child: StudioVipAdBanner(
                          title: 'Tải playlist & bài hát nghe ngoại tuyến',
                          subtitle:
                              'Nâng cấp Moodify VIP để tải nhạc chất lượng cao về máy và nghe không cần kết nối mạng.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SectionEntrance(
              order: 1,
              child: RefreshIndicator(
                onRefresh: controller.load,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  itemCount: state.tracks.length + 2,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: StudioHeroBanner(
                              imageAsset: MoodifyWebAssets.soundwaveDark,
                              eyebrow: 'BÀI HÁT ĐÃ THÍCH',
                              eyebrowIcon: Icons.favorite_rounded,
                              title: 'Giai điệu bạn yêu thích',
                              subtitle: state.tracks.isEmpty
                                  ? 'Những bài hát bạn thả tim sẽ được lưu tại đây để nghe lại nhanh chóng.'
                                  : 'Đang lưu ${state.tracks.length} bài hát trong danh sách yêu thích của bạn.',
                              footer: state.tracks.isEmpty
                                  ? null
                                  : Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: () => ref
                                              .read(
                                                playerControllerProvider
                                                    .notifier,
                                              )
                                              .playCollection(
                                                state.tracks,
                                                source: 'LIBRARY',
                                              ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor:
                                                AppColors.background,
                                            minimumSize: const Size(48, 44),
                                            shape: const StadiumBorder(),
                                          ),
                                          icon: const Icon(
                                            Icons.play_arrow_rounded,
                                          ),
                                          label: const Text('Phát danh sách'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => ref
                                              .read(
                                                playerControllerProvider
                                                    .notifier,
                                              )
                                              .playCollection(
                                                state.tracks,
                                                shuffled: true,
                                                source: 'LIBRARY',
                                              ),
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.surfaceGlass,
                                            minimumSize: const Size(48, 44),
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
                            ),
                          ),
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
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 28,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceRaised,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: AppColors.borderSoft,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceGlass,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.favorite_border_rounded,
                                        size: 30,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    const Text(
                                      'Lưu những bài bạn muốn nghe lại.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    OutlinedButton(
                                      onPressed: () => context.go('/search'),
                                      style: OutlinedButton.styleFrom(
                                        shape: const StadiumBorder(),
                                      ),
                                      child: const Text('Tìm bài hát'),
                                    ),
                                  ],
                                ),
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
            ),
            SectionEntrance(
              order: 2,
              child: RefreshIndicator(
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
                      const Padding(
                        padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: StudioHeroBanner(
                          imageAsset: MoodifyWebAssets.adBrandIdent,
                          eyebrow: 'ĐĨA NHẠC & TUYỂN TẬP',
                          eyebrowIcon: Icons.album_rounded,
                          title: 'Album đã lưu của bạn',
                          subtitle:
                              'Thưởng thức trọn vẹn mạch cảm xúc từ những album được bạn đánh dấu lưu trữ.',
                        ),
                      ),
                      if (items.isEmpty)
                        const LoadMessage(
                          message: 'Album bạn lưu sẽ xuất hiện ở đây.',
                        ),
                      for (final album in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF12141A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0x10FFFFFF),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              leading: MusicArtwork(
                                image: album.image,
                                size: 56,
                                radius: 12,
                              ),
                              title: Text(
                                album.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                album.author ?? 'Album',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.secondary,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.secondary,
                              ),
                              onTap: () =>
                                  context.push('/album/${segment(album.id)}'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SectionEntrance(order: 3, child: const FollowedArtistsView()),
          ],
        ),
      ),
    );
  }
}

class FollowedArtistsView extends ConsumerWidget {
  const FollowedArtistsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(followedArtistsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LoadMessage(
          message: 'Chưa tải được nghệ sĩ đã theo dõi.',
          retry: () => ref.invalidate(followedArtistsProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(followedArtistsProvider);
            await ref.read(followedArtistsProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: StudioHeroBanner(
                  imageAsset: MoodifyWebAssets.audioExperienceBanner,
                  eyebrow: 'NGHỆ SĨ ĐỒNG HÀNH',
                  eyebrowIcon: Icons.people_alt_rounded,
                  title: 'Nghệ sĩ bạn đang theo dõi',
                  subtitle:
                      'Truy cập nhanh trang cá nhân, tiểu sử và danh mục ca khúc của các nghệ sĩ yêu thích.',
                ),
              ),
              if (items.isEmpty)
                LoadMessage(
                  message: 'Nghệ sĩ bạn theo dõi sẽ xuất hiện ở đây.',
                  retry: () => context.go('/search'),
                  retryLabel: 'Tìm nghệ sĩ',
                ),
              for (final artist in items)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF12141A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x10FFFFFF)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      leading: MusicArtwork(
                        image: artist.image,
                        size: 52,
                        round: true,
                      ),
                      title: Text(
                        artist.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.secondary,
                      ),
                      onTap: () => context.push(
                        Uri(
                          path: '/artist/${segment(artist.id)}',
                          queryParameters: {'name': artist.name},
                        ).toString(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
