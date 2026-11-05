import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/artwork_backdrop.dart';
import '../../catalog/presentation/catalog_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../auth/presentation/session_controller.dart';
import '../../player/presentation/player_controller.dart';
import '../../subscriptions/application/premium_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _genre;
  static const _filters = <String?, String>{
    null: 'Tất cả',
    'v-pop,vietnamese pop': 'V-Pop',
    'hip hop,rap,vietnamese hip hop': 'Hip-Hop',
    'indie,vietnamese indie': 'Indie',
    'remix,edm,electronic': 'Remix/EDM',
  };

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(
      sessionControllerProvider.select((s) => s.session != null),
    );
    final isPremium = ref.watch(premiumProvider.select((s) => s.isPremium));
    final query = (genre: _genre, query: null, artistId: null);
    final state = ref.watch(catalogControllerProvider(query));
    final albums = ref.watch(albumsProvider);
    final artists = ref.watch(artistsProvider(''));
    final quick = state.tracks
        .where((t) => t.hasAudio && t.hasTitle)
        .take(6)
        .toList();
    final shelf = state.tracks.where((t) => t.hasTitle).take(12).toList();
    final spotlight = quick.isEmpty ? null : quick.first;
    void play(Track track) => ref
        .read(playerControllerProvider.notifier)
        .select(
          state.tracks,
          state.tracks.indexWhere((t) => t.id == track.id),
          source: 'HOME',
        );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const BrandLockup(),
        actions: [
          if (signedIn) _VipPill(premium: isPremium),
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_none_rounded, size: 23),
          ),
          IconButton(
            tooltip: 'Tài khoản',
            onPressed: () => context.go('/account'),
            icon: const Icon(Icons.person_outline_rounded, size: 23),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                for (final filter in _filters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Semantics(
                      selected: _genre == filter.key,
                      child: AnimatedContainer(
                        duration: AppMotion.duration(context, 180),
                        decoration: BoxDecoration(
                          color: _genre == filter.key
                              ? AppColors.primary
                              : AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: Pressable(
                            onTap: () => setState(() => _genre = filter.key),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
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
              onRefresh: () async {
                ref.invalidate(albumsProvider);
                ref.invalidate(artistsProvider(''));
                await ref
                    .read(catalogControllerProvider(query).notifier)
                    .load(reset: true);
              },
              child: CustomScrollView(
                key: const PageStorageKey('home'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (signedIn && !isPremium)
                    SliverToBoxAdapter(
                      child: SectionEntrance(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bắt đầu nghe',
                                style: Theme.of(context).textTheme.titleLarge,
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
                                          width: (bounds.maxWidth - 8) / 2,
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
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: _Spotlight(
                            track: spotlight,
                            onPlay: () => play(spotlight),
                          ),
                        ),
                      ),
                    ),
                  if (shelf.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: SectionHeading('Khám phá giai điệu'),
                    ),
                    SliverToBoxAdapter(
                      child: SectionEntrance(
                        order: 2,
                        child: SizedBox(
                          height:
                              160 +
                              MediaQuery.textScalerOf(context).scale(13) * 4.4,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    const SliverToBoxAdapter(child: SectionHeading('Nghệ sĩ')),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height:
                            116 +
                            MediaQuery.textScalerOf(context).scale(13) * 3,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: artists.valueOrNull!.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 18),
                          itemBuilder: (_, i) {
                            final artist = artists.valueOrNull![i];
                            return SizedBox(
                              width: 104,
                              child: Pressable(
                                onTap: () => context.push(
                                  Uri(
                                    path: '/artist/${segment(artist.id)}',
                                    queryParameters: {'name': artist.name},
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
                            MediaQuery.textScalerOf(context).scale(13) * 3,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: albums.valueOrNull!.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
                          itemBuilder: (_, i) {
                            final album = albums.valueOrNull![i];
                            return SizedBox(
                              width: 140,
                              child: Pressable(
                                onTap: () =>
                                    context.push('/album/${segment(album.id)}'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SliverToBoxAdapter(
                    child: SectionHeading('Tất cả bài hát'),
                  ),
                  if (state.loading && state.tracks.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  SliverList.builder(
                    itemCount: state.tracks.length,
                    itemBuilder: (_, i) => TrackTile(
                      track: state.tracks[i],
                      queue: state.tracks,
                      index: i,
                    ),
                  ),
                  if (state.failure != null)
                    SliverToBoxAdapter(
                      child: LoadMessage(
                        message: state.failure!.message,
                        retry: () => ref
                            .read(catalogControllerProvider(query).notifier)
                            .load(),
                      ),
                    ),
                  if (!state.loading &&
                      state.failure == null &&
                      state.tracks.isEmpty)
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
                                      catalogControllerProvider(query).notifier,
                                    )
                                    .load(),
                          child: Text(
                            state.loading ? 'Đang tải…' : 'Xem thêm bài hát',
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
      duration: AppMotion.duration(context),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF302344) : const Color(0xFF1A1925),
        border: Border.all(
          color: active ? AppColors.primary : const Color(0xFF302C3F),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Pressable(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: MusicArtwork(image: track.image, size: 48, radius: 9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  track.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.lavender : AppColors.text,
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
  const _Spotlight({required this.track, required this.onPlay});
  final Track track;
  final VoidCallback onPlay;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Stack(
      children: [
        Positioned.fill(child: ArtworkBackdrop(image: track.image, hero: true)),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              MusicArtwork(
                image: track.image,
                size: MediaQuery.sizeOf(context).width < 360 ? 88 : 108,
                radius: 12,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      track.artist,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: onPlay,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.background,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Nghe ngay'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                MusicArtwork(image: track.image, size: 144, radius: 12),
                if (active)
                  const Positioned(
                    right: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.volume_up_rounded, size: 18),
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
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
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
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
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
                  colors: [AppColors.vipGradientTop, AppColors.vipGradientBottom],
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
