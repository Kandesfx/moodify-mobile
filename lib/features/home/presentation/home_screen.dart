import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/studio_banners.dart';
import '../../auth/domain/session_state.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/artwork_backdrop.dart';
import '../../catalog/presentation/catalog_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../auth/presentation/session_controller.dart';
import '../../notifications/presentation/notification_screen.dart';
import '../../offline/presentation/offline_controller.dart';
import '../../offline/presentation/offline_screen.dart' show offlineSize;
import '../../player/presentation/player_controller.dart';
import '../../subscriptions/application/premium_controller.dart';
import 'recommendation_controller.dart';
import 'widgets/recommendation_section_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _genre;
  bool _isRefreshing = false;
  static const _filters = <String?, String>{
    null: 'Tất cả',
    'v-pop,vietnamese pop': 'V-Pop',
    'hip hop,rap,vietnamese hip hop': 'Hip-Hop',
    'indie,vietnamese indie': 'Indie',
    'remix,edm,electronic': 'Remix/EDM',
  };

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionControllerProvider);
    final signedIn = sessionState.session != null;
    final unreadNotifications = signedIn
        ? ref.watch(unreadNotificationCountProvider)
        : 0;
    final hasOfflineScope = signedIn || sessionState.offlineUserId != null;
    final isPremium = ref.watch(premiumProvider.select((s) => s.isPremium));
    final query = (genre: _genre, query: null, artistId: null);
    final state = ref.watch(catalogControllerProvider(query));
    final isOfflineMode =
        sessionState.phase == SessionPhase.restoreFailed ||
        (state.tracks.isEmpty && !state.loading && state.failure != null);
    final offlineState = (isOfflineMode && hasOfflineScope)
        ? ref.watch(offlineControllerProvider)
        : const OfflineState();
    final readyOfflineEntries = offlineState.entries
        .where((e) => !e.expired)
        .toList();
    final readyOfflineTracks = readyOfflineEntries
        .map((e) => e.track)
        .toList(growable: false);
    final showingOfflineCatalog =
        state.tracks.isEmpty && readyOfflineTracks.isNotEmpty;
    final displayTracks = showingOfflineCatalog
        ? readyOfflineTracks
        : state.tracks;
    final totalOfflineBytes = readyOfflineEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.fileSize,
    );
    final albums = ref.watch(albumsProvider);
    final artists = ref.watch(artistsProvider(''));
    final recAsync = ref.watch(
      recommendationHomeProvider(_genre?.split(',').first),
    );
    final isScreenLoading =
        state.loading ||
        albums.isLoading ||
        artists.isLoading ||
        recAsync.isLoading ||
        _isRefreshing;
    final quick = displayTracks
        .where((t) => (showingOfflineCatalog || t.hasAudio) && t.hasTitle)
        .take(6)
        .toList();
    final shelf = displayTracks.where((t) => t.hasTitle).take(12).toList();
    final spotlight = quick.isEmpty ? null : quick.first;
    final activeImage =
        ref.watch(playerControllerProvider.select((s) => s.track?.image)) ??
        spotlight?.image;
    void play(Track track) => ref
        .read(playerControllerProvider.notifier)
        .select(
          displayTracks,
          displayTracks.indexWhere((t) => t.id == track.id),
          offline: showingOfflineCatalog,
          source: showingOfflineCatalog ? 'OFFLINE' : 'HOME',
        );
    Future<void> reconnect() async {
      if (_isRefreshing) return;
      setState(() => _isRefreshing = true);
      try {
        if (sessionState.phase == SessionPhase.restoreFailed) {
          await ref.read(sessionControllerProvider.notifier).restore();
        }
        ref.invalidate(albumsProvider);
        ref.invalidate(artistsProvider(''));
        ref.invalidate(recommendationHomeProvider);
        await ref
            .read(catalogControllerProvider(query).notifier)
            .load(reset: true);
      } finally {
        if (mounted) {
          setState(() => _isRefreshing = false);
        }
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        titleSpacing: 16,
        title: _HomeBrandLockup(loading: isScreenLoading, triggerKey: _genre),
        actions: [
          if (isOfflineMode)
            _OfflineModePill(onReconnect: reconnect)
          else if (signedIn)
            _VipPill(premium: isPremium),
          _GlassHeaderIconButton(
            tooltip: 'Thông báo',
            icon: unreadNotifications > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            badgeCount: unreadNotifications,
            onPressed: () => context.push('/notifications'),
          ),
          const SizedBox(width: 6),
          _GlassHeaderIconButton(
            tooltip: 'Tài khoản',
            icon: Icons.person_outline_rounded,
            onPressed: () => context.go('/account'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: IgnorePointer(
              child: ArtworkPaletteBuilder(
                image: activeImage,
                builder: (context, palette, _) => AnimatedContainer(
                  duration: AppMotion.duration(context, 520),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        palette.dominant.withValues(alpha: 0.52),
                        palette.deep.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: Row(
                    children: [
                      for (final filter in _filters.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Semantics(
                            selected: _genre == filter.key,
                            child: AnimatedContainer(
                              duration: AppMotion.duration(context, 160),
                              decoration: BoxDecoration(
                                color: _genre == filter.key
                                    ? const Color(0xFF242833)
                                    : const Color(0xCC13151B),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _genre == filter.key
                                      ? const Color(0x45FFFFFF)
                                      : const Color(0x18FFFFFF),
                                ),
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                child: Pressable(
                                  onTap: () =>
                                      setState(() => _genre = filter.key),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 9,
                                    ),
                                    child: Text(
                                      filter.value,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _genre == filter.key
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: _genre == filter.key
                                            ? Colors.white
                                            : AppColors.secondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: Colors.transparent,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    notificationPredicate: (notification) =>
                        notification.depth == 0,
                    onRefresh: reconnect,
                    child: CustomScrollView(
                      key: const PageStorageKey('home'),
                      cacheExtent: 640,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      slivers: [
                        if (isOfflineMode)
                          SliverToBoxAdapter(
                            child: SectionEntrance(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  16,
                                ),
                                child: _OfflineStudioHeroCard(
                                  readyCount: readyOfflineTracks.length,
                                  totalBytes: totalOfflineBytes,
                                  onPlayAll: readyOfflineTracks.isEmpty
                                      ? null
                                      : () => ref
                                            .read(
                                              playerControllerProvider.notifier,
                                            )
                                            .playCollection(
                                              readyOfflineTracks,
                                              offline: true,
                                              source: 'OFFLINE',
                                            ),
                                  onShuffle: readyOfflineTracks.isEmpty
                                      ? null
                                      : () => ref
                                            .read(
                                              playerControllerProvider.notifier,
                                            )
                                            .playCollection(
                                              readyOfflineTracks,
                                              shuffled: true,
                                              offline: true,
                                              source: 'OFFLINE',
                                            ),
                                  onOpenVault: () => context.push('/offline'),
                                  onReconnect: reconnect,
                                ),
                              ),
                            ),
                          )
                        else if (signedIn && !isPremium)
                          SliverToBoxAdapter(
                            child: SectionEntrance(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  16,
                                ),
                                child: _UpsellBanner(
                                  onTap: () => context.push('/subscriptions'),
                                ),
                              ),
                            ),
                          ),
                        if (quick.isNotEmpty)
                          SliverToBoxAdapter(
                            child: SectionEntrance(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      showingOfflineCatalog
                                          ? 'Nghe nhanh Offline'
                                          : 'Bắt đầu nghe',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 12),
                                    LayoutBuilder(
                                      builder: (context, bounds) {
                                        final height =
                                            (MediaQuery.textScalerOf(
                                                          context,
                                                        ).scale(12) *
                                                        2.8 +
                                                    16)
                                                .clamp(64.0, 112.0);
                                        return Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            for (final track in quick)
                                              SizedBox(
                                                width:
                                                    (bounds.maxWidth - 8) / 2,
                                                height: height,
                                                child: _QuickTrack(
                                                  track: track,
                                                  onTap: () => play(track),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (spotlight != null)
                          SliverToBoxAdapter(
                            child: SectionEntrance(
                              order: 1,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: _Spotlight(
                                  track: spotlight,
                                  onPlay: () => play(spotlight),
                                  offline: showingOfflineCatalog,
                                ),
                              ),
                            ),
                          ),
                        if (!isOfflineMode)
                          RecommendationSectionWidget(
                            genre: _genre?.split(',').first,
                          ),
                        if (shelf.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: SectionHeading(
                              showingOfflineCatalog
                                  ? 'Bản thu đã tải kèm ảnh bìa'
                                  : 'Khám phá giai điệu',
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SectionEntrance(
                              order: 2,
                              child: SizedBox(
                                height:
                                    160 +
                                    MediaQuery.textScalerOf(context).scale(13) *
                                        4.4,
                                child: ListView.separated(
                                  key: PageStorageKey(
                                    'home_shelf_${_genre ?? "all"}',
                                  ),
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: shelf.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 14),
                                  itemBuilder: (_, i) => _TrackCard(
                                    track: shelf[i],
                                    onTap: () => play(shelf[i]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if ((artists.valueOrNull ?? []).isNotEmpty) ...[
                          const SliverToBoxAdapter(
                            child: SectionHeading('Nghệ sĩ'),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height:
                                  116 +
                                  MediaQuery.textScalerOf(context).scale(13) *
                                      3,
                              child: ListView.separated(
                                key: const PageStorageKey('home_artists'),
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: artists.valueOrNull!.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 18),
                                itemBuilder: (_, i) {
                                  final artist = artists.valueOrNull![i];
                                  return SizedBox(
                                    width: 104,
                                    child: Pressable(
                                      onTap: () => context.push(
                                        Uri(
                                          path: '/artist/${segment(artist.id)}',
                                          queryParameters: {
                                            'name': artist.name,
                                          },
                                        ).toString(),
                                      ),
                                      child: Column(
                                        children: [
                                          MusicArtwork(
                                            image: artist.image,
                                            size: 100,
                                            round: true,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            artist.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                        if ((albums.valueOrNull ?? []).isNotEmpty) ...[
                          const SliverToBoxAdapter(
                            child: SectionHeading('Album & tuyển tập'),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height:
                                  160 +
                                  MediaQuery.textScalerOf(context).scale(13) *
                                      3,
                              child: ListView.separated(
                                key: const PageStorageKey('home_albums'),
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: albums.valueOrNull!.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 14),
                                itemBuilder: (_, i) {
                                  final album = albums.valueOrNull![i];
                                  return SizedBox(
                                    width: 140,
                                    child: Pressable(
                                      onTap: () => context.push(
                                        '/album/${segment(album.id)}',
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          MusicArtwork(
                                            image: album.image,
                                            size: 140,
                                            radius: 12,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            album.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                        SliverToBoxAdapter(
                          child: SectionHeading(
                            showingOfflineCatalog
                                ? 'Nhạc đã tải trên máy (${displayTracks.length})'
                                : 'Tất cả bài hát',
                          ),
                        ),
                        if (state.loading && displayTracks.isEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text(
                                  'Đang tải bài hát…',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        SliverList.builder(
                          itemCount: displayTracks.length,
                          itemBuilder: (_, i) => TrackTile(
                            track: displayTracks[i],
                            queue: displayTracks,
                            index: i,
                            offline: showingOfflineCatalog,
                          ),
                        ),
                        if (state.failure != null && !showingOfflineCatalog)
                          SliverToBoxAdapter(
                            child: LoadMessage(
                              message: state.failure!.message,
                              retry: () => ref
                                  .read(
                                    catalogControllerProvider(query).notifier,
                                  )
                                  .load(),
                            ),
                          ),
                        if (!state.loading &&
                            state.failure == null &&
                            displayTracks.isEmpty)
                          const SliverToBoxAdapter(
                            child: LoadMessage(
                              message: 'Chưa có bài hát trong thể loại này.',
                            ),
                          ),
                        if (state.hasMore && state.tracks.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: OutlinedButton(
                                onPressed: state.loading
                                    ? null
                                    : () => ref
                                          .read(
                                            catalogControllerProvider(
                                              query,
                                            ).notifier,
                                          )
                                          .load(),
                                child: Text(
                                  state.loading
                                      ? 'Đang tải…'
                                      : 'Xem thêm bài hát',
                                ),
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTrack extends ConsumerWidget {
  const _QuickTrack({required this.track, required this.onTap});
  final Track track;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      playerControllerProvider.select((s) => s.track?.id == track.id),
    );
    return AnimatedContainer(
      duration: AppMotion.duration(context, 160),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF1E222C) : const Color(0xFF13151B),
        border: Border.all(
          color: active ? const Color(0x3DFFFFFF) : const Color(0x12FFFFFF),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Pressable(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: MusicArtwork(image: track.image, size: 48, radius: 11),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  track.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.32,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Spotlight extends StatelessWidget {
  const _Spotlight({
    required this.track,
    required this.onPlay,
    this.offline = false,
  });
  final Track track;
  final VoidCallback onPlay;
  final bool offline;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0x22FFFFFF)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Positioned.fill(
            child: ArtworkBackdrop(image: track.image, hero: true),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                MusicArtwork(
                  image: track.image,
                  size: MediaQuery.sizeOf(context).width < 360 ? 88 : 108,
                  radius: 16,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: offline
                              ? const Color(0x2822C55E)
                              : const Color(0x24FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: offline
                                ? const Color(0x6622C55E)
                                : const Color(0x20FFFFFF),
                          ),
                        ),
                        child: Text(
                          offline ? 'BẢN TẢI NỔI BẬT' : 'TÂM ĐIỂM',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: offline
                                ? const Color(0xFF4ADE80)
                                : Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        track.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.28,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: onPlay,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.background,
                          minimumSize: const Size(48, 42),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: Text(offline ? 'Phát Offline' : 'Nghe ngay'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TrackCard extends ConsumerWidget {
  const _TrackCard({required this.track, required this.onTap});
  final Track track;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      playerControllerProvider.select(
        (s) => s.track?.id == track.id && s.playing,
      ),
    );
    return SizedBox(
      width: 144,
      child: Pressable(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                MusicArtwork(image: track.image, size: 144, radius: 16),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary
                          : const Color(0xD90D0E13),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active ? Colors.white : const Color(0x2EFFFFFF),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(
                        active
                            ? Icons.volume_up_rounded
                            : Icons.play_arrow_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              track.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    child: Row(
      children: [
        Container(
          width: 3.5,
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    ),
  );
}

/// Pill trạng thái gói trên AppBar: VIP → badge vàng Hoàng Kim,
/// user miễn phí → kêu gọi nâng cấp. Cả hai dẫn đến màn Gói dịch vụ.
class _VipPill extends StatelessWidget {
  const _VipPill({required this.premium});
  final bool premium;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 2),
    child: Pressable(
      onTap: () => context.push('/subscriptions'),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: premium
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.vipGradientTop,
                    AppColors.vipGradientBottom,
                  ],
                )
              : null,
          color: premium ? null : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: premium ? AppColors.vipBorder : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 15,
              color: premium ? AppColors.vipGold : AppColors.secondary,
            ),
            const SizedBox(width: 5),
            Text(
              premium ? 'VIP' : 'Nâng VIP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: premium ? AppColors.vipGold : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Banner kêu gọi nâng cấp cho user miễn phí đã đăng nhập
/// (parity với upsell bên web: không QC, skip không giới hạn, offline).
class _UpsellBanner extends StatelessWidget {
  const _UpsellBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.vipBorder),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.workspace_premium_rounded,
          color: AppColors.vipGold,
          size: 30,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trải nghiệm Moodify VIP',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                'Nghe không quảng cáo, chuyển bài không giới hạn, tải nhạc offline.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Pressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.vipGold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Nâng cấp',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1710),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _OfflineModePill extends StatelessWidget {
  const _OfflineModePill({required this.onReconnect});
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 4),
    child: Pressable(
      onTap: onReconnect,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xCC1B1F2C),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x55FFB800)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 14, color: Color(0xFFFFB800)),
            SizedBox(width: 5),
            Text(
              'Offline',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFFB800),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OfflineStudioHeroCard extends StatelessWidget {
  const _OfflineStudioHeroCard({
    required this.readyCount,
    required this.totalBytes,
    required this.onOpenVault,
    required this.onReconnect,
    this.onPlayAll,
    this.onShuffle,
  });

  final int readyCount;
  final int totalBytes;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;
  final VoidCallback onOpenVault;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x30FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x45000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              MoodifyWebAssets.soundwaveDark,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xD8090B10),
                    Color(0xE8121622),
                    Color(0xF5151925),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x28FFB800),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x66FFB800)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            size: 13,
                            color: Color(0xFFFFB800),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'CHẾ ĐỘ OFFLINE STUDIO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                              color: Color(0xFFFFB800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (readyCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x2422C55E),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x5522C55E)),
                        ),
                        child: Text(
                          '$readyCount bài · ${offlineSize(totalBytes)}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4ADE80),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  readyCount > 0
                      ? 'Không gian nghe nhạc của bạn vẫn hoạt động ngoại tuyến'
                      : 'Đang ở chế độ không có kết nối mạng',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.28,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  readyCount > 0
                      ? 'Toàn bộ bài hát, ảnh bìa và lời nhạc đã tải về máy đều sẵn sàng phát và tương tác ngay trên Trang chủ.'
                      : 'Các bài hát tải về thiết bị kèm ảnh bìa sẽ hiển thị ngay tại đây khi mất kết nối mạng.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (onPlayAll != null)
                      FilledButton.icon(
                        onPressed: onPlayAll,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.background,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 19),
                        label: const Text('Phát nhạc đã tải'),
                      ),
                    if (onShuffle != null)
                      OutlinedButton.icon(
                        onPressed: onShuffle,
                        icon: const Icon(Icons.shuffle_rounded, size: 17),
                        label: const Text('Trộn bài'),
                      ),
                    OutlinedButton.icon(
                      onPressed: onOpenVault,
                      icon: const Icon(Icons.download_done_rounded, size: 17),
                      label: const Text('Kho nhạc Offline'),
                    ),
                    TextButton.icon(
                      onPressed: onReconnect,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Kết nối lại'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút icon kính mờ đồng bộ với viên nang thương hiệu trên AppBar Trang chủ.
/// Không dùng BackdropFilter để giữ tốc độ cuộn trang 60/90fps mượt tuyệt đối.
class _GlassHeaderIconButton extends StatelessWidget {
  const _GlassHeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Center(
        child: RepaintBoundary(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: const Color(0x9E131620),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                  side: const BorderSide(color: Color(0x1EFFFFFF), width: 0.85),
                ),
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(icon, size: 20, color: const Color(0xFFEAECEF)),
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.background,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cụm thương hiệu Moodify kiểu "Smoked Liquid Glass Capsule":
/// - Nền kính mờ bán trong suốt ("hơi mờ" - #151824 -> #0D0F17 alpha ~68%) không dùng
///   BackdropFilter hay ShaderMask saveLayer, đảm bảo cuộn trang mượt 60/90fps.
/// - Chữ "Moodify" phủ dải màu gradient pastel khói dịu mắt (không lòe loẹt).
/// - Chỉ kích hoạt vòng lặp animation khi đang tải (loading == true) hoặc chuyển thể loại;
///   khi ở trạng thái tĩnh (Idle), AnimationController dừng hoàn toàn (0% tải GPU/CPU).
class _HomeBrandLockup extends StatefulWidget {
  const _HomeBrandLockup({required this.loading, this.triggerKey});
  final bool loading;
  final Object? triggerKey;

  @override
  State<_HomeBrandLockup> createState() => _HomeBrandLockupState();
}

class _HomeBrandLockupState extends State<_HomeBrandLockup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _completingSweep = false;

  static const _capsuleRadius = BorderRadius.only(
    topLeft: Radius.circular(14),
    bottomLeft: Radius.circular(20),
    topRight: Radius.circular(20),
    bottomRight: Radius.circular(14),
  );

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2200),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && _completingSweep) {
            setState(() => _completingSweep = false);
          }
        });
    if (widget.loading) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_HomeBrandLockup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final disableAnimations =
        mounted && MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (disableAnimations) {
      _completingSweep = false;
      _controller.stop();
      return;
    }

    if (widget.loading != oldWidget.loading) {
      if (widget.loading) {
        _completingSweep = false;
        _controller.repeat();
      } else {
        _completingSweep = true;
        final resumeFrom = _controller.value > 0.65 ? 0.18 : _controller.value;
        _controller.forward(from: resumeFrom);
      }
    } else if (!widget.loading && widget.triggerKey != oldWidget.triggerKey) {
      _completingSweep = true;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.48;
    return Semantics(
      label: 'Moodify',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final phase = _controller.value;
              final double activeIntensity;
              if (widget.loading) {
                activeIntensity = 1.0;
              } else if (_completingSweep) {
                activeIntensity = phase < 0.68
                    ? 1.0
                    : ((1.0 - phase) / 0.32).clamp(0.0, 1.0);
              } else {
                activeIntensity = 0.0;
              }

              final shift = activeIntensity > 0.001 ? phase * 2.0 : 0.0;
              final textShader = LinearGradient(
                begin: Alignment(-1.0 - shift, -0.15),
                end: Alignment(1.0 - shift, 0.15),
                tileMode: TileMode.repeated,
                colors: const [
                  Color(0xFFF1F5F9),
                  Color(0xFFC7D2FE),
                  Color(0xFFB4A5F6),
                  Color(0xFFDDA6D6),
                  Color(0xFFBAE6FD),
                  Color(0xFFD5B8F8),
                  Color(0xFFF1F5F9),
                ],
                stops: const [0.0, 0.18, 0.36, 0.54, 0.72, 0.88, 1.0],
              ).createShader(const Rect.fromLTWH(0, 0, 88, 22));

              return ClipRRect(
                borderRadius: _capsuleRadius,
                child: CustomPaint(
                  painter: _BrandGlassPainter(
                    phase: phase,
                    intensity: activeIntensity,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(7, 6, 12, 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          padding: const EdgeInsets.all(4.2),
                          decoration: BoxDecoration(
                            color: const Color(0x80090B10),
                            borderRadius: BorderRadius.circular(8.5),
                            border: Border.all(
                              color: const Color(0x1EFFFFFF),
                              width: 0.75,
                            ),
                          ),
                          child: Image.asset(
                            'assets/brand/moodify-mark.png',
                            fit: BoxFit.contain,
                            cacheWidth: 64,
                            filterQuality: FilterQuality.low,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Moodify',
                              style: TextStyle(
                                foreground: Paint()..shader = textShader,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.35,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BrandGlassPainter extends CustomPainter {
  const _BrandGlassPainter({required this.phase, required this.intensity});

  final double phase;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndCorners(
      rect.deflate(0.6),
      topLeft: const Radius.circular(14),
      bottomLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomRight: const Radius.circular(14),
    );

    // 1. NỀN KÍNH MỜ BÁN TRONG SUỐT ("HƠI MỜ" - Smoked Translucent Glass)
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xBC151824), Color(0xAA11141E), Color(0x9C0D0F17)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, fillPaint);

    // Ánh phản xạ mặt kính rất nhẹ ở góc trên-trái
    final sheenPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomCenter,
        colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
      ).createShader(rect);
    canvas.drawRRect(rrect, sheenPaint);

    // 2. VIỀN KÍNH TĨNH MẢNH (0.85px) — Sang trọng, không màu mè khi Idle
    final baseBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x28FFFFFF), Color(0x10FFFFFF), Color(0x18A78BFA)],
        stops: [0.0, 0.6, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, baseBorderPaint);

    // Nếu không loading -> dừng tại đây, giữ nguyên mặt kính mờ tĩnh lặng
    if (intensity <= 0.001) return;

    // 3. HIỆU ỨNG KHI LOADING: Tia sáng sương mờ (Muted Shimmer) chạy êm quanh mép kính
    final rimPath = Path()..addRRect(rrect);
    final angle = phase * 2 * math.pi;
    final shimmerShader = SweepGradient(
      center: Alignment.center,
      transform: GradientRotation(angle),
      colors: [
        const Color(0x00FFFFFF),
        const Color(0xFF93C5FD).withValues(alpha: 0.36 * intensity),
        const Color(0xFFC4B5FD).withValues(alpha: 0.54 * intensity),
        const Color(0xFFF1F5F9).withValues(alpha: 0.68 * intensity),
        const Color(0xFFE879F9).withValues(alpha: 0.44 * intensity),
        const Color(0x00FFFFFF),
      ],
      stops: const [0.0, 0.22, 0.45, 0.56, 0.78, 1.0],
    ).createShader(rect);

    final shimmerRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..shader = shimmerShader;
    canvas.drawPath(rimPath, shimmerRimPaint);

    final metrics = rimPath.computeMetrics();
    for (final metric in metrics) {
      final total = metric.length;
      if (total <= 0) continue;
      final segmentLength = total * 0.28;
      final start = (phase * total) % total;
      final end = start + segmentLength;

      final cometPath = Path();
      if (end <= total) {
        cometPath.addPath(metric.extractPath(start, end), Offset.zero);
      } else {
        cometPath
          ..addPath(metric.extractPath(start, total), Offset.zero)
          ..addPath(metric.extractPath(0, end - total), Offset.zero);
      }

      final cometGlowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFC4B5FD).withValues(alpha: 0.24 * intensity);
      canvas.drawPath(cometPath, cometGlowPaint);

      final cometCorePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.05
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFF8FAFC).withValues(alpha: 0.52 * intensity);
      canvas.drawPath(cometPath, cometCorePaint);
      break;
    }
  }

  @override
  bool shouldRepaint(covariant _BrandGlassPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.intensity != intensity;
}
