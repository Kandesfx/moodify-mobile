import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/app_motion.dart';
import '../../../catalog/presentation/catalog_widgets.dart';
import '../../../player/presentation/player_controller.dart';
import '../../data/recommendation_repository.dart';
import '../../domain/recommendation_models.dart';
import '../recommendation_controller.dart';

class RecommendationSectionWidget extends ConsumerWidget {
  const RecommendationSectionWidget({super.key, this.genre});
  final String? genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(recommendationHomeProvider(genre));
    final hidden = ref.watch(hiddenItemsProvider);
    // Dùng valueOrNull để giữ nguyên các kệ gợi ý khi đang làm mới nền,
    // tránh thu chiều cao về 0 gây giật hoặc nhảy vị trí cuộn trên Trang chủ.
    final home = homeAsync.valueOrNull;
    if (home == null || home.sections.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final visibleSections = home.sections.where((section) {
      final items = section.items.where(
        (i) => !hidden.contains('${i.entityType}:${i.entityId}'),
      );
      return items.isNotEmpty;
    }).toList();

    if (visibleSections.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        for (final section in visibleSections) ...[
          SliverToBoxAdapter(
            child: _RecommendationSectionHeading(
              section.title,
              action: section.id == 'personal_mixes'
                  ? 'Dành riêng cho bạn'
                  : null,
            ),
          ),
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Builder(
                builder: (context) {
                  final items = section.items
                      .where(
                        (i) =>
                            !hidden.contains('${i.entityType}:${i.entityId}'),
                      )
                      .toList(growable: false);
                  return SizedBox(
                    height: section.id == 'personal_mixes' ? 240 : 230,
                    child: ListView.separated(
                      key: PageStorageKey(
                        'rec_${genre ?? "all"}_${section.id}',
                      ),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        if (section.id == 'personal_mixes') {
                          return _PersonalMixCard(item: item);
                        }
                        return _RecommendedTrackCard(item: item);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
      ],
    );
  }
}

class _RecommendationSectionHeading extends StatelessWidget {
  const _RecommendationSectionHeading(this.text, {this.action});
  final String text;
  final String? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    child: Row(
      children: [
        Container(
          width: 3.5,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: Colors.white,
            ),
          ),
        ),
        if (action != null)
          Text(
            action!,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.lavender,
            ),
          ),
      ],
    ),
  );
}

class _PersonalMixCard extends ConsumerWidget {
  const _PersonalMixCard({required this.item});
  final RecommendationItem item;

  List<Color> _getGradient(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('chill') || lower.contains('thư giãn')) {
      return const [Color(0xFF042F2E), Color(0xFF0B141C), Color(0xFF0C0C10)];
    }
    if (lower.contains('energy') || lower.contains('năng lượng')) {
      return const [Color(0xFF3F1D15), Color(0xFF191118), Color(0xFF0C0C10)];
    }
    if (lower.contains('discover') || lower.contains('khám phá')) {
      return const [Color(0xFF0C2440), Color(0xFF101726), Color(0xFF0C0C10)];
    }
    return const [Color(0xFF1E1B4B), Color(0xFF131522), Color(0xFF0C0C10)];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = _getGradient(item.title);

    Future<void> onPlay() async {
      ref
          .read(recommendationRepositoryProvider)
          .recordEvent(
            eventType: 'OPEN',
            attributionToken: item.attributionToken,
          );

      try {
        final tracks = await ref
            .read(recommendationRepositoryProvider)
            .fetchMixTracks(item.entityId);
        if (tracks.isNotEmpty && context.mounted) {
          await ref
              .read(playerControllerProvider.notifier)
              .select(tracks, 0, source: 'RECOMMENDATION');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chưa thể mở bản phối. Vui lòng thử lại sau.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    return SizedBox(
      width: 172,
      child: Pressable(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            border: Border.all(color: const Color(0x1EFFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x28FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.album_rounded,
                          size: 11,
                          color: AppColors.lavender,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'BẢN PHỐI',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _showItemOptions(context, ref, item),
                    borderRadius: BorderRadius.circular(999),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    MusicArtwork(image: item.imageUrl, size: 120, radius: 14),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        height: 34,
                        width: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle ?? '${item.trackCount} bài hát',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendedTrackCard extends ConsumerWidget {
  const _RecommendedTrackCard({required this.item});
  final RecommendationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> onPlay() async {
      ref
          .read(recommendationRepositoryProvider)
          .recordEvent(
            eventType: 'OPEN',
            attributionToken: item.attributionToken,
          );

      if (item.track != null) {
        await ref
            .read(playerControllerProvider.notifier)
            .select([item.track!], 0, source: 'RECOMMENDATION');
      }
    }

    return SizedBox(
      width: 144,
      child: Pressable(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                MusicArtwork(image: item.imageUrl, size: 144, radius: 14),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _showItemOptions(context, ref, item),
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              item.subtitle ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.secondary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 11,
                  color: AppColors.lavender,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.lavender,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showItemOptions(
  BuildContext context,
  WidgetRef ref,
  RecommendationItem item,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF141620),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.visibility_off_outlined,
                  color: Colors.white70,
                ),
                title: const Text(
                  'Không quan tâm nội dung này',
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final key = '${item.entityType}:${item.entityId}';
                  ref.read(hiddenItemsProvider.notifier).hide(key);

                  await ref
                      .read(recommendationRepositoryProvider)
                      .sendFeedback(
                        entityType: item.entityType,
                        entityId: item.entityId,
                        feedbackType: 'NOT_INTERESTED',
                        enabled: true,
                      );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã ẩn "${item.title}"'),
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'Hoàn tác',
                          textColor: AppColors.lavender,
                          onPressed: () async {
                            ref.read(hiddenItemsProvider.notifier).unhide(key);
                            await ref
                                .read(recommendationRepositoryProvider)
                                .sendFeedback(
                                  entityType: item.entityType,
                                  entityId: item.entityId,
                                  feedbackType: 'NOT_INTERESTED',
                                  enabled: false,
                                );
                          },
                        ),
                      ),
                    );
                  }
                },
              ),
              if (item.track?.artistId != null)
                ListTile(
                  leading: const Icon(
                    Icons.block_rounded,
                    color: Color(0xFFFF6B6B),
                  ),
                  title: Text(
                    'Ẩn nghệ sĩ ${item.track?.artist ?? ""}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFFF6B6B),
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final key = '${item.entityType}:${item.entityId}';
                    ref.read(hiddenItemsProvider.notifier).hide(key);

                    await ref
                        .read(recommendationRepositoryProvider)
                        .sendFeedback(
                          entityType: 'ARTIST',
                          entityId: item.track!.artistId!,
                          feedbackType: 'HIDE',
                          enabled: true,
                        );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Đã ẩn nghệ sĩ ${item.track?.artist ?? ""}',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}
