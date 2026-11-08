import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/app_motion.dart';
import '../../../catalog/domain/catalog_models.dart';
import '../../../catalog/presentation/catalog_widgets.dart';
import '../../../player/presentation/player_controller.dart';
import '../../data/recommendation_repository.dart';
import '../../domain/recommendation_models.dart';

/// Hiển thị Modal Bottom Sheet chi tiết của Bản phối cá nhân hóa (Personalized Mix).
void showPersonalizedMixDetailSheet({
  required BuildContext context,
  required RecommendationItem item,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PersonalizedMixDetailSheet(item: item),
  );
}

class PersonalizedMixDetailSheet extends ConsumerStatefulWidget {
  const PersonalizedMixDetailSheet({super.key, required this.item});
  final RecommendationItem item;

  @override
  ConsumerState<PersonalizedMixDetailSheet> createState() =>
      _PersonalizedMixDetailSheetState();
}

class _PersonalizedMixDetailSheetState
    extends ConsumerState<PersonalizedMixDetailSheet> {
  PersonalizedMix? _mix;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isRefreshing = false;
  bool _isCopying = false;

  @override
  void initState() {
    super.initState();
    _loadMix();
  }

  Future<void> _loadMix() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(recommendationRepositoryProvider);
      final mix = await repo.fetchPersonalizedMix(widget.item.entityId);
      if (mounted) {
        setState(() {
          _mix = mix;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Chưa thể tải chi tiết bản phối. Vui lòng thử lại sau.';
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    if (_mix == null || _isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final repo = ref.read(recommendationRepositoryProvider);
      final updated = await repo.refreshPersonalizedMix(widget.item.entityId);
      if (mounted) {
        setState(() {
          _mix = updated;
          _isRefreshing = false;
        });
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Đã làm mới bản phối thành công! Danh sách nhạc đã được cập nhật.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa thể làm mới lúc này. Vui lòng thử lại sau.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleCopy() async {
    if (_mix == null || _isCopying) return;
    final versionId = _mix!.versionId ?? widget.item.versionId ?? '';
    if (versionId.isEmpty) return;

    setState(() => _isCopying = true);
    try {
      final repo = ref.read(recommendationRepositoryProvider);
      final requestId = 'copy_${DateTime.now().microsecondsSinceEpoch}';
      await repo.copyPersonalizedMix(
        widget.item.entityId,
        versionId: versionId,
        requestId: requestId,
      );
      if (mounted) {
        setState(() => _isCopying = false);
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Đã lưu bản sao vào thư viện của bạn! Bạn có thể chỉnh sửa tự do.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCopying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa thể lưu bản sao. Vui lòng thử lại sau.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _playTracks(List<Track> tracks, int startIndex) async {
    if (tracks.isEmpty) return;
    ref
        .read(recommendationRepositoryProvider)
        .recordEvent(
          eventType: 'PLAY_START',
          attributionToken: widget.item.attributionToken,
        );

    await ref
        .read(playerControllerProvider.notifier)
        .select(tracks, startIndex, source: 'RECOMMENDATION');

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatDuration(int? ms) {
    if (ms == null || ms <= 0) return '--:--';
    final seconds = (ms / 1000).round();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  List<Color> _getGradient(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('chill') || lower.contains('thư giãn')) {
      return const [Color(0xFF042F2E), Color(0xFF0B141C), Color(0xFF10121A)];
    }
    if (lower.contains('energy') || lower.contains('năng lượng')) {
      return const [Color(0xFF3F1D15), Color(0xFF191118), Color(0xFF10121A)];
    }
    if (lower.contains('discover') || lower.contains('khám phá')) {
      return const [Color(0xFF0C2440), Color(0xFF101726), Color(0xFF10121A)];
    }
    return const [Color(0xFF1E1B4B), Color(0xFF131522), Color(0xFF10121A)];
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.88;
    final gradient = _getGradient(_mix?.name ?? widget.item.title);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: const Color(0xFF12141C),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0x22FFFFFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Content body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.lavender,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Đang tải bản phối riêng...',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFFF6B6B),
                            size: 44,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadMix,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Thử lại'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF242833),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      // Header card with mix info
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: gradient,
                            ),
                            border: Border.all(color: const Color(0x28FFFFFF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Mix artwork
                                  MusicArtwork(
                                    image:
                                        _mix?.imageUrl ?? widget.item.imageUrl,
                                    size: 104,
                                    radius: 14,
                                  ),
                                  const SizedBox(width: 16),
                                  // Mix title & metadata
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0x33FFFFFF),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.auto_awesome_rounded,
                                                size: 11,
                                                color: AppColors.lavender,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'BẢN PHỐI RIÊNG',
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
                                        const SizedBox(height: 6),
                                        Text(
                                          _mix?.name ?? widget.item.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _mix?.description.isNotEmpty == true
                                              ? _mix!.description
                                              : (widget.item.subtitle ??
                                                    'Được cá nhân hóa theo gu nghe nhạc của bạn'),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${_mix?.tracks.length ?? widget.item.trackCount} bài hát'
                                          '${_mix?.generatedAt != null ? ' · Cập nhật hôm nay' : ''}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Action buttons row
                              Row(
                                children: [
                                  // Play button
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          (_mix?.tracks.isNotEmpty ?? false)
                                          ? () => _playTracks(_mix!.tracks, 0)
                                          : null,
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 20,
                                      ),
                                      label: const Text('Phát bản phối'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Refresh button
                                  IconButton.filledTonal(
                                    tooltip: 'Làm mới bản phối',
                                    onPressed: _isRefreshing
                                        ? null
                                        : _handleRefresh,
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0x28FFFFFF),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.all(12),
                                    ),
                                    icon: _isRefreshing
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.refresh_rounded,
                                            size: 20,
                                          ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Copy to library button
                                  IconButton.filledTonal(
                                    tooltip: 'Lưu bản sao vào thư viện',
                                    onPressed: _isCopying ? null : _handleCopy,
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0x28FFFFFF),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.all(12),
                                    ),
                                    icon: _isCopying
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.bookmark_add_outlined,
                                            size: 20,
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tracks header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: Row(
                            children: [
                              const Text(
                                'Danh sách bài hát',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_mix?.tracks.length ?? 0} bài',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tracks list
                      if (_mix?.tracks.isEmpty ?? true)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'Bản phối hiện chưa có bài hát khả dụng.',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final track = _mix!.tracks[index];
                            final currentPlayingId = () {
                              try {
                                return ref.watch(
                                  playerControllerProvider.select(
                                    (s) => s.track?.id,
                                  ),
                                );
                              } catch (_) {
                                return null;
                              }
                            }();
                            final isCurrentPlaying =
                                currentPlayingId == track.id;

                            return Pressable(
                              onTap: () => _playTracks(_mix!.tracks, index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                color: isCurrentPlaying
                                    ? const Color(0x1A9945FF)
                                    : Colors.transparent,
                                child: Row(
                                  children: [
                                    // Index or playing indicator
                                    SizedBox(
                                      width: 24,
                                      child: isCurrentPlaying
                                          ? const Icon(
                                              Icons.graphic_eq_rounded,
                                              size: 16,
                                              color: AppColors.lavender,
                                            )
                                          : Text(
                                              '${index + 1}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white38,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Track art
                                    MusicArtwork(
                                      image: track.image,
                                      size: 42,
                                      radius: 8,
                                    ),
                                    const SizedBox(width: 12),

                                    // Track info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isCurrentPlaying
                                                  ? AppColors.lavender
                                                  : Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            track.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Duration
                                    Text(
                                      _formatDuration(track.durationMs),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }, childCount: _mix!.tracks.length),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
