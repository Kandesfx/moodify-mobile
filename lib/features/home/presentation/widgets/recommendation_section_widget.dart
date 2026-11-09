import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/app_motion.dart';
import '../../../../core/widgets/studio_banners.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../catalog/presentation/catalog_widgets.dart';
import '../../../library/data/library_repository.dart';
import '../../../player/presentation/player_controller.dart';
import '../../data/recommendation_repository.dart';
import '../../domain/recommendation_models.dart';
import '../recommendation_controller.dart';
import 'personalized_mix_detail_sheet.dart';

/// Hiển thị toàn bộ các mục đề xuất nhạc dựa trên hành vi (Behavioral Recommendation System),
/// với đầy đủ các kịch bản ràng buộc: Khách chưa đăng nhập, Người dùng mới (Cold Start),
/// Lọc thể loại không có dữ liệu, Bản phối cá nhân hóa và Feedback tiêu cực có Hoàn tác.
class RecommendationSectionWidget extends ConsumerWidget {
  const RecommendationSectionWidget({super.key, this.genre, this.onClearGenre});
  final String? genre;
  final VoidCallback? onClearGenre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      sessionControllerProvider.select((s) => s.session != null),
    );

    // Kịch bản 1: Người dùng chưa đăng nhập (Khách / Guest)
    if (!signedIn) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: _GuestRecommendationPromptCard(),
        ),
      );
    }

    final homeAsync = ref.watch(recommendationHomeProvider(genre));
    final hidden = ref.watch(hiddenItemsProvider);
    final home = homeAsync.valueOrNull;

    // Kịch bản 2: Đang tải lần đầu chưa có dữ liệu cache
    if (homeAsync.isLoading && home == null) {
      return const SliverToBoxAdapter(child: _RecommendationLoadingSkeleton());
    }

    // Kịch bản 3: Gặp lỗi mạng và chưa có dữ liệu cache
    if (homeAsync.hasError && home == null) {
      return SliverToBoxAdapter(
        child: _RecommendationErrorCard(
          onRetry: () => ref.refresh(recommendationHomeProvider(genre)),
        ),
      );
    }

    if (home == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final visibleSections = home.sections.where((section) {
      final items = section.items.where(
        (i) => !hidden.contains('${i.entityType}:${i.entityId}'),
      );
      return items.isNotEmpty;
    }).toList();

    // Đồng bộ thứ tự hiển thị các kệ đề xuất khớp với bản web:
    // Bản phối riêng -> Dành cho bạn -> Playlist hợp gu -> Đang được nghe nhiều hơn -> Tuyển chọn
    const sectionOrder = [
      'personal_mixes',
      'for_you',
      'playlists_for_you',
      'trending',
      'campaigns',
    ];
    visibleSections.sort((a, b) {
      final ia = sectionOrder.indexOf(a.id);
      final ib = sectionOrder.indexOf(b.id);
      return (ia == -1 ? 99 : ia).compareTo(ib == -1 ? 99 : ib);
    });

    final isFiltered = genre != null && genre!.isNotEmpty && genre != 'ALL';
    final hasNoEligible =
        home.availabilityStatus == 'NO_ELIGIBLE_CATALOG' ||
        visibleSections.isEmpty;

    // Kịch bản 4: Lọc thể loại nhưng chưa có đề xuất phù hợp
    if (isFiltered && hasNoEligible) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: _EmptyGenreRecommendationCard(
            genre: genre!,
            onClearGenre: onClearGenre,
          ),
        ),
      );
    }

    // Nếu không còn section nào hiển thị
    if (visibleSections.isEmpty) {
      if (home.coldStart) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: _ColdStartRecommendationBanner(),
          ),
        );
      }
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        // Kịch bản 5: Người dùng mới (Cold Start) - Hiển thị banner giải thích phía trên
        if (home.coldStart)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _ColdStartRecommendationBanner(),
            ),
          ),

        // Kịch bản 6: Hiển thị các kệ đề xuất theo hành vi
        for (final section in visibleSections) ...[
          SliverToBoxAdapter(
            child: _RecommendationSectionHeading(
              section.title,
              action: section.id == 'personal_mixes'
                  ? 'Bản phối riêng'
                  : section.id == 'playlists_for_you'
                  ? 'Tuyển tập'
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
                    height: section.id == 'personal_mixes' ? 244 : 234,
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
                        if (section.id == 'personal_mixes' ||
                            item.isPersonalizedMix) {
                          return _PersonalMixCard(item: item);
                        }
                        if (section.id == 'playlists_for_you' ||
                            item.isPlaylist) {
                          return _RecommendedPlaylistCard(item: item);
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

/// Thẻ giới thiệu tính năng Tuyển chọn Dành riêng cho bạn cho khách chưa đăng nhập.
class _GuestRecommendationPromptCard extends StatelessWidget {
  const _GuestRecommendationPromptCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF13151F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x339945FF)),
        image: const DecorationImage(
          image: AssetImage(MoodifyWebAssets.soundwaveDark),
          fit: BoxFit.cover,
          opacity: 0.12,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9945FF).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9945FF), Color(0xFF14F195)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GỢI Ý ÂM NHẠC DÀNH CHO BẠN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.lavender,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Đồng hành cùng gu thưởng thức của bạn',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Dựa trên nhu cầu và sở thích của bạn, Moodify luôn sẵn sàng đề xuất âm nhạc phù hợp theo xu hướng nghe nhạc của bạn, mang đến những bản phối Daily Mix và Discovery trọn vẹn mỗi ngày.',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.push('/login'),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Đăng nhập để trải nghiệm danh sách riêng'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner chào mừng và giải thích dịch vụ tuyển chọn cho người dùng mới (Cold Start).
class _ColdStartRecommendationBanner extends StatelessWidget {
  const _ColdStartRecommendationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF151824),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x289945FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0x289945FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.insights_rounded,
              size: 20,
              color: AppColors.lavender,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang tuyển chọn giai điệu theo sở thích của bạn',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Dựa trên từng bài hát bạn lắng nghe và yêu thích, chúng tôi luôn theo sát để đề xuất âm nhạc phù hợp nhất theo xu hướng nghe nhạc của riêng bạn.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white70,
                    height: 1.35,
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

/// Trạng thái rỗng khi lọc thể loại nhưng chưa có đề xuất phù hợp.
class _EmptyGenreRecommendationCard extends StatelessWidget {
  const _EmptyGenreRecommendationCard({required this.genre, this.onClearGenre});
  final String genre;
  final VoidCallback? onClearGenre;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF13151F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1EFFFFFF)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0x15FFFFFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.filter_list_off_rounded,
              size: 28,
              color: AppColors.lavender,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có đề xuất riêng cho thể loại "$genre"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hệ thống cần bạn nghe thêm các bài hát thuộc thể loại này để hoàn thiện bản phối gợi ý chuẩn xác hơn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondary,
              height: 1.35,
            ),
          ),
          if (onClearGenre != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClearGenre,
              icon: const Icon(Icons.apps_rounded, size: 16),
              label: const Text('Xem đề xuất của tất cả thể loại'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0x33FFFFFF)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton Shimmer khi đang tải dữ liệu đề xuất.
class _RecommendationLoadingSkeleton extends StatelessWidget {
  const _RecommendationLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Container(
            width: 160,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0x18FFFFFF),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        SizedBox(
          height: 230,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, _) => Container(
              width: 160,
              decoration: BoxDecoration(
                color: const Color(0x12FFFFFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x10FFFFFF)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Thẻ báo lỗi nhẹ nhàng khi tải đề xuất thất bại.
class _RecommendationErrorCard extends StatelessWidget {
  const _RecommendationErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161822),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1EFFFFFF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 22,
            color: Color(0xFFFF6B6B),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Chưa thể cập nhật gợi ý âm nhạc lúc này.',
              style: TextStyle(fontSize: 12.5, color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.lavender,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Thử lại'),
          ),
        ],
      ),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0x229945FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              action!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.lavender,
              ),
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

    Future<void> onPlayDirect() async {
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

    void onOpenDetail() {
      showPersonalizedMixDetailSheet(context: context, item: item);
    }

    return SizedBox(
      width: 172,
      child: Pressable(
        onTap: onOpenDetail,
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
                      child: InkWell(
                        onTap: onPlayDirect,
                        borderRadius: BorderRadius.circular(999),
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

/// Thẻ hiển thị Playlist được đề xuất (Ví dụ: mục "Playlist hợp gu").
/// Cho phép phát toàn bộ danh sách hoặc nhấn vào để xem chi tiết CollectionScreen (/playlist/:id).
class _RecommendedPlaylistCard extends ConsumerWidget {
  const _RecommendedPlaylistCard({required this.item});
  final RecommendationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> onPlayDirect() async {
      ref
          .read(recommendationRepositoryProvider)
          .recordEvent(
            eventType: 'OPEN',
            attributionToken: item.attributionToken,
          );

      try {
        final collection = await ref
            .read(libraryRepositoryProvider)
            .playlist(item.entityId);
        if (collection.tracks.isNotEmpty && context.mounted) {
          await ref
              .read(playerControllerProvider.notifier)
              .playCollection(collection.tracks, source: 'PLAYLIST');
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Playlist này hiện chưa có bài hát nào khả dụng.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chưa thể mở playlist. Vui lòng thử lại sau.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    void onOpenDetail() {
      ref
          .read(recommendationRepositoryProvider)
          .recordEvent(
            eventType: 'OPEN',
            attributionToken: item.attributionToken,
          );
      context.push('/playlist/${item.entityId}');
    }

    final subtitleText = item.trackCount > 0
        ? '${item.trackCount} bài hát'
        : (item.subtitle ?? 'Tuyển tập');

    return SizedBox(
      width: 152,
      child: Pressable(
        onTap: onOpenDetail,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                MusicArtwork(image: item.imageUrl, size: 152, radius: 14),
                // Huy hiệu nhận diện loại nội dung "PLAYLIST"
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.queue_music_rounded,
                          size: 10,
                          color: AppColors.lavender,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'PLAYLIST',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Nút phát trực tiếp nhanh trên thẻ
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: InkWell(
                    onTap: onPlayDirect,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 34,
                      width: 34,
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
                        size: 22,
                      ),
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
              subtitleText,
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
  final container = ProviderScope.containerOf(context);
  final isPlaylist = item.isPlaylist || item.entityType == 'PLAYLIST';
  final feedbackType = isPlaylist ? 'HIDE' : 'NOT_INTERESTED';

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
              if (isPlaylist)
                ListTile(
                  leading: const Icon(
                    Icons.playlist_play_rounded,
                    color: Colors.white70,
                  ),
                  title: const Text(
                    'Xem chi tiết playlist',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/playlist/${item.entityId}');
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.visibility_off_outlined,
                  color: Colors.white70,
                ),
                title: Text(
                  isPlaylist
                      ? 'Ẩn playlist này khỏi gợi ý'
                      : 'Không quan tâm nội dung này',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final key = '${item.entityType}:${item.entityId}';
                  container.read(hiddenItemsProvider.notifier).hide(key);

                  await container
                      .read(recommendationRepositoryProvider)
                      .sendFeedback(
                        entityType: item.entityType,
                        entityId: item.entityId,
                        feedbackType: feedbackType,
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
                            container
                                .read(hiddenItemsProvider.notifier)
                                .unhide(key);
                            await container
                                .read(recommendationRepositoryProvider)
                                .sendFeedback(
                                  entityType: item.entityType,
                                  entityId: item.entityId,
                                  feedbackType: feedbackType,
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
                    container.read(hiddenItemsProvider.notifier).hide(key);

                    await container
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
                          action: SnackBarAction(
                            label: 'Hoàn tác',
                            textColor: AppColors.lavender,
                            onPressed: () async {
                              container
                                  .read(hiddenItemsProvider.notifier)
                                  .unhide(key);
                              await container
                                  .read(recommendationRepositoryProvider)
                                  .sendFeedback(
                                    entityType: 'ARTIST',
                                    entityId: item.track!.artistId!,
                                    feedbackType: 'HIDE',
                                    enabled: false,
                                  );
                            },
                          ),
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
