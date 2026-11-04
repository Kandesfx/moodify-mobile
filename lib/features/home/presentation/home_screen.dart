import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/catalog_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../player/presentation/player_controller.dart';

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
    final query = (genre: _genre, query: null, artistId: null);
    final state = ref.watch(catalogControllerProvider(query));
    final albums = ref.watch(albumsProvider);
    final artists = ref.watch(artistsProvider(''));
    final quick = state.tracks
        .where((t) => t.hasAudio && t.hasTitle)
        .take(6)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const BrandLockup(),
        actions: [
          IconButton(
            tooltip: 'Tài khoản',
            onPressed: () => context.go('/account'),
            icon: const Icon(Icons.person_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(albumsProvider);
          ref.invalidate(artistsProvider(''));
          await ref
              .read(catalogControllerProvider(query).notifier)
              .load(reset: true);
        },
        child: CustomScrollView(
          key: const PageStorageKey('home'),
          slivers: [
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final filter in _filters.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: TextButton(
                          onPressed: () => setState(() => _genre = filter.key),
                          style: TextButton.styleFrom(
                            foregroundColor: _genre == filter.key
                                ? Colors.white
                                : AppColors.secondary,
                            backgroundColor: _genre == filter.key
                                ? AppColors.surfaceRaised
                                : null,
                          ),
                          child: Text(filter.value),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (quick.isNotEmpty) ...[
              const SliverToBoxAdapter(child: _SectionTitle('Nghe ngay')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.list(
                  children: [
                    for (var i = 0; i < quick.length; i += 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _QuickTrack(
                                track: quick[i],
                                play: () => ref
                                    .read(playerControllerProvider.notifier)
                                    .select(quick, i),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: i + 1 < quick.length
                                  ? _QuickTrack(
                                      track: quick[i + 1],
                                      play: () => ref
                                          .read(
                                            playerControllerProvider.notifier,
                                          )
                                          .select(quick, i + 1),
                                    )
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SliverToBoxAdapter(child: _SectionTitle('Album')),
            SliverToBoxAdapter(
              child: albums.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => LoadMessage(
                  message: 'Chưa tải được album.',
                  retry: () => ref.invalidate(albumsProvider),
                ),
                data: (items) => items.isEmpty
                    ? const LoadMessage(
                        message: 'Chưa có album được phát hành.',
                      )
                    : SizedBox(
                        height: 208,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 16),
                          itemBuilder: (_, i) {
                            final album = items[i];
                            return InkWell(
                              onTap: () =>
                                  context.push('/album/${segment(album.id)}'),
                              child: SizedBox(
                                width: 144,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MusicArtwork(image: album.image, size: 144),
                                    const SizedBox(height: 10),
                                    Text(
                                      album.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
            const SliverToBoxAdapter(child: _SectionTitle('Khám phá bài hát')),
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
            if (!state.loading && state.failure == null && state.tracks.isEmpty)
              const SliverToBoxAdapter(
                child: LoadMessage(
                  message: 'Chưa có bài hát trong thể loại này.',
                ),
              ),
            if (state.hasMore && state.tracks.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: OutlinedButton(
                    onPressed: state.loading
                        ? null
                        : () => ref
                              .read(catalogControllerProvider(query).notifier)
                              .load(),
                    child: Text(
                      state.loading ? 'Đang tải…' : 'Xem thêm bài hát',
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: _SectionTitle('Nghệ sĩ')),
            SliverToBoxAdapter(
              child: artists.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => LoadMessage(
                  message: 'Chưa tải được nghệ sĩ.',
                  retry: () => ref.invalidate(artistsProvider('')),
                ),
                data: (items) => items.isEmpty
                    ? const LoadMessage(message: 'Chưa có nghệ sĩ.')
                    : SizedBox(
                        height: 160,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 20),
                          itemBuilder: (_, i) => InkWell(
                            onTap: () => context.push(
                              Uri(
                                path: '/artist/${segment(items[i].id)}',
                                queryParameters: {'name': items[i].name},
                              ).toString(),
                            ),
                            child: SizedBox(
                              width: 100,
                              child: Column(
                                children: [
                                  MusicArtwork(
                                    image: items[i].image,
                                    size: 96,
                                    round: true,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    items[i].name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _QuickTrack extends StatelessWidget {
  const _QuickTrack({required this.track, required this.play});
  final Track track;
  final VoidCallback play;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceRaised,
    borderRadius: BorderRadius.circular(8),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: play,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 66),
        child: Row(
          children: [
            MusicArtwork(image: track.image, size: 56),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Text(
                  track.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
