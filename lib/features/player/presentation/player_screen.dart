import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/feedback_panel.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/data/artist_repository.dart';
import '../../catalog/presentation/artwork_backdrop.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../library/presentation/library_controller.dart';
import 'player_controller.dart';
import 'player_sheets.dart';
import 'track_share_sheet.dart';

String playbackTime(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 86400);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// CTA nâng cấp trên các bề mặt quảng cáo — dẫn thẳng đến màn Gói dịch vụ
/// trong app (đã có checkout QR SePay) thay vì mở trang web như trước.
class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({required this.isBasic});
  final bool isBasic;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: () => context.push('/subscriptions'),
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF8B72F6),
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    icon: const Icon(Icons.workspace_premium_rounded, size: 18),
    label: Text(isBasic ? 'Lên FULL' : 'Nâng VIP'),
  );
}

class _AdMiniPlayer extends StatelessWidget {
  const _AdMiniPlayer({required this.state, required this.controller});

  final PlayerState state;
  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final isIdent = state.position < const Duration(milliseconds: 9500);
    final durationMs = state.duration.inMilliseconds;
    final progress = durationMs > 0
        ? (state.position.inMilliseconds / durationMs).clamp(0.0, 1.0)
        : 0.0;
    final remaining = state.duration > Duration.zero
        ? ((state.duration - state.position).inMilliseconds / 1000)
              .ceil()
              .clamp(0, 999)
        : null;
    return Material(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => context.push('/player'),
                      borderRadius: BorderRadius.circular(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          isIdent
                              ? 'assets/ads/moodify_brand_ident_art.jpg'
                              : 'assets/ads/moodify_vip_premium_art.jpg',
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.square(
                            dimension: 52,
                            child: Icon(Icons.campaign_outlined),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push('/player'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quảng cáo',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: const Color(0xFFE3DAFF),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              state.failure != null
                                  ? 'Chưa phát được · Chạm để xem'
                                  : 'Tiếp theo: ${state.track!.displayName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.secondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (state.loading)
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: state.playing ? 'Tạm dừng' : 'Phát',
                        onPressed: state.playing
                            ? controller.pause
                            : controller.play,
                        icon: Icon(
                          state.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        color: AppColors.text,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    color: const Color(0xFFB8A7FF),
                    backgroundColor: const Color(0xFF484255),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      remaining == null
                          ? 'Đang tải thời lượng'
                          : 'Còn ${remaining}s',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                    if (state.adCanSkip)
                      TextButton(
                        onPressed: state.position >= const Duration(seconds: 5)
                            ? controller.skipAd
                            : null,
                        child: Text(
                          state.position >= const Duration(seconds: 5)
                              ? 'Bỏ qua'
                              : 'Bỏ qua sau ${5 - state.position.inSeconds}s',
                        ),
                      ),
                    _UpgradeButton(isBasic: state.adCanSkip),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slice = ref.watch(
      playerControllerProvider.select(
        (s) => (
          source: s.source,
          track: s.track,
          isAd: s.isAd,
          playing: s.playing,
          loading: s.loading,
          failure: s.failure,
        ),
      ),
    );
    if (slice.source == 'KARAOKE') return const SizedBox.shrink();
    final track = slice.track;
    if (track == null) return const SizedBox.shrink();
    final controller = ref.read(playerControllerProvider.notifier);
    if (slice.isAd) {
      final fullState = ref.watch(playerControllerProvider);
      return _AdMiniPlayer(state: fullState, controller: controller);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: ArtworkPaletteBuilder(
        image: track.image,
        builder: (context, palette, _) => AnimatedContainer(
          duration: AppMotion.duration(context, 480),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [palette.miniPlayer, const Color(0xFF141720)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x30FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Pressable(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.push('/player'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                    child: Row(
                      children: [
                        AnimatedSwitcher(
                          duration: AppMotion.duration(context),
                          child: MusicArtwork(
                            key: ValueKey(track.id),
                            image: track.image,
                            size: 46,
                            radius: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                slice.failure != null
                                    ? 'Chưa phát được · Chạm để xem'
                                    : track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: slice.failure != null
                                      ? AppColors.error
                                      : const Color(0xB8FFFFFF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _LikeButton(track: track, compact: true),
                        SizedBox.square(
                          dimension: 42,
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF090A0D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            tooltip: slice.playing ? 'Tạm dừng' : 'Phát',
                            onPressed: slice.loading || slice.playing
                                ? controller.pause
                                : controller.play,
                            icon: slice.loading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF090A0D),
                                    ),
                                  )
                                : _PlayIcon(playing: slice.playing, size: 24),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Bài tiếp theo',
                          color: Colors.white,
                          onPressed: slice.loading || slice.isAd
                              ? null
                              : controller.next,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                _MiniPlayerProgress(accentColor: palette.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerProgress extends ConsumerWidget {
  const _MiniPlayerProgress({this.accentColor});
  final Color? accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(
      playerControllerProvider.select((s) {
        final dur = s.duration.inMilliseconds;
        if (dur <= 0) return 0.0;
        return (s.position.inMilliseconds / dur).clamp(0.0, 1.0);
      }),
    );
    return LinearProgressIndicator(
      value: progress,
      minHeight: 2.5,
      color: accentColor ?? Colors.white,
      backgroundColor: const Color(0x24FFFFFF),
    );
  }
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});
  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  void _close() => context.canPop() ? context.pop() : context.go('/home');

  static ButtonStyle _topBarButtonStyle({bool active = false}) =>
      IconButton.styleFrom(
        backgroundColor: active
            ? const Color(0x3DFFFFFF)
            : const Color(0x1FFFFFFF),
        foregroundColor: Colors.white,
        minimumSize: const Size(42, 42),
        side: BorderSide(
          color: active ? const Color(0x66FFFFFF) : const Color(0x28FFFFFF),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final slice = ref.watch(
      playerControllerProvider.select(
        (s) => (
          track: s.track,
          isAd: s.isAd,
          adCanSkip: s.adCanSkip,
          offline: s.offline,
          playing: s.playing,
          loading: s.loading,
          failure: s.failure,
          shuffle: s.shuffle,
          repeat: s.repeat,
          sleepUntil: s.sleepUntil,
          isIdentArt: s.isAd && s.position < const Duration(milliseconds: 9500),
        ),
      ),
    );
    final controller = ref.read(playerControllerProvider.notifier);
    final track = slice.track;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(child: ArtworkBackdrop(image: track?.image)),
          SafeArea(
            child: Column(
              children: [
                GestureDetector(
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) > 250) _close();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Thu nhỏ',
                          style: _topBarButtonStyle(),
                          onPressed: _close,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 26,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                slice.isAd
                                    ? 'QUẢNG CÁO'
                                    : slice.offline
                                    ? 'ĐANG PHÁT OFFLINE'
                                    : 'ĐANG PHÁT',
                                style: const TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.6,
                                  color: Color(0xB8FFFFFF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                slice.isAd ? 'Moodify Ads' : 'Moodify',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (track != null) ...[
                          IconButton(
                            tooltip: 'Mở lời bài hát',
                            style: _topBarButtonStyle(),
                            onPressed: () => showPlayerLyrics(context),
                            icon: const Icon(Icons.lyrics_outlined, size: 20),
                          ),
                          const SizedBox(width: 6),
                        ],
                        IconButton(
                          tooltip: 'Hẹn giờ ngủ',
                          style: _topBarButtonStyle(
                            active: slice.sleepUntil != null,
                          ),
                          onPressed: track == null
                              ? null
                              : () => showSleepTimer(context),
                          icon: Icon(
                            slice.sleepUntil == null
                                ? Icons.bedtime_outlined
                                : Icons.bedtime_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        if (track != null) ...[
                          const SizedBox(width: 6),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0x1FFFFFFF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0x28FFFFFF),
                              ),
                            ),
                            child: TrackOptionsButton(track: track),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: track == null
                      ? const LoadMessage(
                          message: 'Chọn một bài hát để bắt đầu nghe.',
                        )
                      : LayoutBuilder(
                          builder: (context, bounds) {
                            final artSize = (bounds.maxWidth - 64).clamp(
                              190.0,
                              340.0,
                            );
                            final isIdentArt = slice.isIdentArt;
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 460,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (slice.isAd)
                                        Center(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            child: DecoratedBox(
                                              key: ValueKey('ad-$isIdentArt'),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Color(0x50000000),
                                                    blurRadius: 32,
                                                    offset: Offset(0, 14),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                                child: Image.asset(
                                                  isIdentArt
                                                      ? 'assets/ads/moodify_brand_ident_art.jpg'
                                                      : 'assets/ads/moodify_vip_premium_art.jpg',
                                                  width: artSize.toDouble(),
                                                  height: artSize.toDouble(),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        _PlayerHeroPager(
                                          track: track,
                                          artSize: artSize,
                                        ),
                                      const SizedBox(height: 16),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  slice.isAd
                                                      ? 'Quảng cáo'
                                                      : track.displayName,
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    height: 1.3,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -0.4,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        slice.isAd
                                                            ? 'Tiếp theo: ${track.displayName}'
                                                            : track.artist,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Color(
                                                            0xC2FFFFFF,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!slice.isAd) ...[
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: const Color(0x1FFFFFFF),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: const Color(
                                                    0x28FFFFFF,
                                                  ),
                                                ),
                                              ),
                                              child: TrackDownloadButton(
                                                track: track,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: const Color(0x1FFFFFFF),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: const Color(
                                                    0x28FFFFFF,
                                                  ),
                                                ),
                                              ),
                                              child: _LikeButton(track: track),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (slice.failure != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 16,
                                          ),
                                          child: FeedbackPanel(
                                            message: slice.failure!.message,
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      const _PlayerSeekSection(),
                                      const SizedBox(height: 18),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          IconButton(
                                            tooltip: slice.shuffle
                                                ? 'Tắt phát ngẫu nhiên'
                                                : 'Phát ngẫu nhiên',
                                            style: IconButton.styleFrom(
                                              backgroundColor: slice.shuffle
                                                  ? const Color(0x3DFFFFFF)
                                                  : const Color(0x18FFFFFF),
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(44, 44),
                                              side: BorderSide(
                                                color: slice.shuffle
                                                    ? const Color(0x70FFFFFF)
                                                    : const Color(0x26FFFFFF),
                                              ),
                                            ),
                                            onPressed: controller.toggleShuffle,
                                            icon: const Icon(
                                              Icons.shuffle_rounded,
                                              size: 22,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Bài trước',
                                            style: IconButton.styleFrom(
                                              backgroundColor: const Color(
                                                0x24FFFFFF,
                                              ),
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  const Color(0x0FFFFFFF),
                                              disabledForegroundColor:
                                                  const Color(0x4DFFFFFF),
                                              minimumSize: const Size(52, 52),
                                              side: const BorderSide(
                                                color: Color(0x33FFFFFF),
                                              ),
                                            ),
                                            onPressed:
                                                slice.loading || slice.isAd
                                                ? null
                                                : controller.previous,
                                            icon: const Icon(
                                              Icons.skip_previous_rounded,
                                              size: 30,
                                            ),
                                          ),
                                          DecoratedBox(
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Color(0x40FFFFFF),
                                                  blurRadius: 22,
                                                  offset: Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: SizedBox.square(
                                              dimension: 68,
                                              child: IconButton.filled(
                                                tooltip: slice.playing
                                                    ? 'Tạm dừng'
                                                    : 'Phát',
                                                style: IconButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor:
                                                      AppColors.background,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          24,
                                                        ),
                                                  ),
                                                ),
                                                onPressed:
                                                    slice.loading ||
                                                        slice.playing
                                                    ? controller.pause
                                                    : controller.play,
                                                icon: slice.loading
                                                    ? const SizedBox.square(
                                                        dimension: 28,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: AppColors
                                                                  .background,
                                                            ),
                                                      )
                                                    : _PlayIcon(
                                                        playing: slice.playing,
                                                        size: 36,
                                                      ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Bài tiếp theo',
                                            style: IconButton.styleFrom(
                                              backgroundColor: const Color(
                                                0x24FFFFFF,
                                              ),
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  const Color(0x0FFFFFFF),
                                              disabledForegroundColor:
                                                  const Color(0x4DFFFFFF),
                                              minimumSize: const Size(52, 52),
                                              side: const BorderSide(
                                                color: Color(0x33FFFFFF),
                                              ),
                                            ),
                                            onPressed:
                                                slice.loading || slice.isAd
                                                ? null
                                                : controller.next,
                                            icon: const Icon(
                                              Icons.skip_next_rounded,
                                              size: 30,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: switch (slice.repeat) {
                                              PlaybackRepeat.off =>
                                                'Lặp lại đang tắt',
                                              PlaybackRepeat.all =>
                                                'Lặp cả hàng đợi',
                                              PlaybackRepeat.one =>
                                                'Lặp một bài',
                                            },
                                            style: IconButton.styleFrom(
                                              backgroundColor:
                                                  slice.repeat ==
                                                      PlaybackRepeat.off
                                                  ? const Color(0x18FFFFFF)
                                                  : const Color(0x3DFFFFFF),
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(44, 44),
                                              side: BorderSide(
                                                color:
                                                    slice.repeat ==
                                                        PlaybackRepeat.off
                                                    ? const Color(0x26FFFFFF)
                                                    : const Color(0x70FFFFFF),
                                              ),
                                            ),
                                            onPressed: controller.cycleRepeat,
                                            icon: Icon(
                                              slice.repeat == PlaybackRepeat.one
                                                  ? Icons.repeat_one_rounded
                                                  : Icons.repeat_rounded,
                                              size: 22,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 18),
                                      Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        spacing: 10,
                                        runSpacing: 8,
                                        children: [
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              backgroundColor: const Color(
                                                0x1FFFFFFF,
                                              ),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                              shape: const StadiumBorder(
                                                side: BorderSide(
                                                  color: Color(0x2EFFFFFF),
                                                ),
                                              ),
                                            ),
                                            onPressed: () =>
                                                showShareTrackSheet(
                                                  context,
                                                  track,
                                                ),
                                            icon: const Icon(
                                              Icons.ios_share_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'Chia sẻ',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              backgroundColor: const Color(
                                                0x1FFFFFFF,
                                              ),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                              shape: const StadiumBorder(
                                                side: BorderSide(
                                                  color: Color(0x2EFFFFFF),
                                                ),
                                              ),
                                            ),
                                            onPressed: () =>
                                                showPlayerQueue(context),
                                            icon: const Icon(
                                              Icons.queue_music_rounded,
                                              size: 20,
                                            ),
                                            label: const Text(
                                              'Hàng đợi',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _PlayerCompanionCard(track: track),
                                      const SizedBox(height: 16),
                                      Center(
                                        child: TextButton.icon(
                                          style: TextButton.styleFrom(
                                            backgroundColor: const Color(
                                              0x16FFFFFF,
                                            ),
                                            foregroundColor: const Color(
                                              0xE6FFFFFF,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 10,
                                            ),
                                            shape: const StadiumBorder(
                                              side: BorderSide(
                                                color: Color(0x24FFFFFF),
                                              ),
                                            ),
                                          ),
                                          onPressed: controller.clear,
                                          icon: const Icon(
                                            Icons.stop_circle_outlined,
                                            size: 19,
                                          ),
                                          label: const Text(
                                            'Dừng phát',
                                            style: TextStyle(
                                              fontSize: 12.5,
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
                          },
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

class _PlayerHeroPager extends ConsumerStatefulWidget {
  const _PlayerHeroPager({required this.track, required this.artSize});
  final Track track;
  final double artSize;

  @override
  ConsumerState<_PlayerHeroPager> createState() => _PlayerHeroPagerState();
}

class _PlayerHeroPagerState extends ConsumerState<_PlayerHeroPager> {
  late final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (!_pageController.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(playerLyricLinesProvider);
    final plain = ref.watch(playerPlainLyricsProvider);
    final hasLyrics = lines.isNotEmpty || plain.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.artSize + 16,
          child: PageView(
            controller: _pageController,
            physics: hasLyrics
                ? const BouncingScrollPhysics(parent: PageScrollPhysics())
                : const NeverScrollableScrollPhysics(),
            onPageChanged: (value) => setState(() => _page = value),
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    AnimatedSwitcher(
                      duration: AppMotion.duration(context, 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: DecoratedBox(
                        key: ValueKey(widget.track.id),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 34,
                              offset: Offset(0, 14),
                            ),
                          ],
                        ),
                        child: MusicArtwork(
                          image: widget.track.image,
                          size: widget.artSize,
                          radius: 24,
                        ),
                      ),
                    ),
                    if (hasLyrics)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _BouncingLyricsHint(
                              onTap: () => _goToPage(1),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (hasLyrics)
                Center(
                  child: SizedBox(
                    width: widget.artSize,
                    height: widget.artSize,
                    child: _CompactSwipeLyricsCard(
                      track: widget.track,
                      isActivePage: _page == 1,
                      onShowCover: () => _goToPage(0),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: hasLyrics
              ? Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x24FFFFFF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeroModePill(
                        label: 'Đĩa nhạc',
                        icon: Icons.album_rounded,
                        selected: _page == 0,
                        onTap: () => _goToPage(0),
                      ),
                      const SizedBox(width: 4),
                      _HeroModePill(
                        label: 'Lời tự động',
                        icon: Icons.lyrics_rounded,
                        selected: _page == 1,
                        onTap: () => _goToPage(1),
                      ),
                    ],
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x18FFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.music_note_rounded,
                        size: 13,
                        color: Color(0xCCFFFFFF),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Bản hòa tấu · Không có lời',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xCCFFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _HeroModePill extends StatelessWidget {
  const _HeroModePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: AppMotion.duration(context, 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: selected ? const Color(0xFF090A0D) : const Color(0xCCFFFFFF),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF090A0D)
                  : const Color(0xCCFFFFFF),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BouncingLyricsHint extends ConsumerWidget {
  const _BouncingLyricsHint({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(playerLyricLinesProvider);
    final plain = ref.watch(playerPlainLyricsProvider);
    final hasLyrics = lines.isNotEmpty || plain.isNotEmpty;
    if (!hasLyrics) return const SizedBox.shrink();

    final seconds = ref.watch(
      playerControllerProvider.select((s) => s.position.inSeconds),
    );
    // Hiển thị định kỳ (5 giây đầu và mỗi chu kỳ 14 giây phát nhạc) với hiệu ứng nảy.
    final cycle = seconds ~/ 14;
    final visible = seconds < 5 || (seconds % 14) < 5;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: AppMotion.duration(context, 280),
        child: TweenAnimationBuilder<double>(
          key: ValueKey((visible, cycle)),
          tween: Tween<double>(begin: visible ? 0.0 : 1.0, end: 1.0),
          duration: AppMotion.duration(context, 620),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            final dy = (1.0 - value) * 14.0;
            final scale = 0.86 + 0.14 * value.clamp(0.0, 1.15);
            return Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: Material(
            color: const Color(0xD910131C),
            shape: const StadiumBorder(
              side: BorderSide(color: Color(0x52FFFFFF)),
            ),
            elevation: 8,
            shadowColor: Colors.black54,
            child: InkWell(
              onTap: onTap,
              customBorder: const StadiumBorder(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lyrics_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Vuốt sang để xem lời',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.swipe_left_rounded,
                      size: 14,
                      color: Color(0xCCFFFFFF),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactSwipeLyricsCard extends ConsumerStatefulWidget {
  const _CompactSwipeLyricsCard({
    required this.track,
    required this.isActivePage,
    required this.onShowCover,
  });
  final Track track;
  final bool isActivePage;
  final VoidCallback onShowCover;

  @override
  ConsumerState<_CompactSwipeLyricsCard> createState() =>
      _CompactSwipeLyricsCardState();
}

class _CompactSwipeLyricsCardState
    extends ConsumerState<_CompactSwipeLyricsCard>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  bool _follow = true;
  int _lastActive = -2;
  Object? _measureKey;
  List<double> _heights = const [];
  List<double> _offsets = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant _CompactSwipeLyricsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.track.id != oldWidget.track.id ||
        (widget.isActivePage && !oldWidget.isActivePage)) {
      _follow = true;
      _lastActive = -2;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _recenter() => setState(() {
    _follow = true;
    _lastActive = -2;
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final position = ref.watch(
      playerControllerProvider.select((s) => s.position),
    );
    final lines = ref.watch(playerLyricLinesProvider);
    final plain = ref.watch(playerPlainLyricsProvider);
    final active = lines.lastIndexWhere((line) => line.at <= position);

    return ArtworkPaletteBuilder(
      image: widget.track.image,
      builder: (context, palette, _) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.dominant.withValues(alpha: 0.90),
              palette.deep.withValues(alpha: 0.95),
              const Color(0xF20C0E14),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x38FFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              decoration: const BoxDecoration(
                color: Color(0x28000000),
                border: Border(bottom: BorderSide(color: Color(0x1FFFFFFF))),
              ),
              child: Row(
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x28FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.graphic_eq_rounded,
                              size: 13,
                              color: palette.accent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              lines.isNotEmpty ? 'LỜI ĐỒNG BỘ' : 'LỜI BÀI HÁT',
                              style: const TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: InkWell(
                      onTap: () => showPlayerLyrics(context),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x24FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x2EFFFFFF)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.open_in_full_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Phóng to',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: lines.isNotEmpty
                  ? LayoutBuilder(
                      builder: (context, box) {
                        final style = TextStyle(
                          fontFamily: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.fontFamily,
                          fontSize: 16,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        );
                        final textMaxWidth = (box.maxWidth - 56).clamp(
                          1.0,
                          double.infinity,
                        );
                        final measureKey = (
                          widget.track.id,
                          lines,
                          textMaxWidth,
                          box.maxHeight,
                          MediaQuery.textScalerOf(context),
                          Directionality.of(context),
                          style.fontFamily,
                        );
                        if (_measureKey != measureKey) {
                          _measureKey = measureKey;
                          final heights = <double>[];
                          final offsets = <double>[];
                          var offset = 0.0;
                          for (final line in lines) {
                            final painter = TextPainter(
                              text: TextSpan(text: line.text, style: style),
                              textDirection: Directionality.of(context),
                              textScaler: MediaQuery.textScalerOf(context),
                            )..layout(maxWidth: textMaxWidth);
                            final h = (painter.height + 26)
                                .ceilToDouble()
                                .clamp(44.0, double.infinity);
                            offsets.add(offset);
                            heights.add(h);
                            offset += h;
                            painter.dispose();
                          }
                          _heights = heights;
                          _offsets = offsets;
                          _lastActive = -2;
                        }
                        final verticalPad = (box.maxHeight * 0.40).clamp(
                          24.0,
                          140.0,
                        );
                        if (_follow && _lastActive != active) {
                          final targetActive = active;
                          final wasUnset = _lastActive == -2;
                          _lastActive = targetActive;
                          final rawTarget =
                              targetActive < 0 ||
                                  targetActive >= _offsets.length
                              ? 0.0
                              : verticalPad +
                                    _offsets[targetActive] +
                                    (_heights[targetActive] / 2) -
                                    (box.maxHeight / 2);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted ||
                                !_follow ||
                                !_scrollController.hasClients ||
                                _lastActive != targetActive) {
                              return;
                            }
                            final clamped = rawTarget.clamp(
                              0.0,
                              _scrollController.position.maxScrollExtent,
                            );
                            if (MediaQuery.disableAnimationsOf(context) ||
                                (wasUnset &&
                                    _scrollController.offset == 0 &&
                                    targetActive > 3)) {
                              _scrollController.jumpTo(clamped);
                            } else {
                              _scrollController.animateTo(
                                clamped,
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          });
                        }
                        return Stack(
                          children: [
                            Positioned.fill(
                              child:
                                  NotificationListener<ScrollStartNotification>(
                                    onNotification: (event) {
                                      if (event.dragDetails != null &&
                                          _follow) {
                                        setState(() => _follow = false);
                                      }
                                      return false;
                                    },
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      padding: EdgeInsets.symmetric(
                                        vertical: verticalPad,
                                      ),
                                      itemCount: lines.length,
                                      itemExtentBuilder: (i, _) => _heights[i],
                                      itemBuilder: (context, index) {
                                        final isCurrent = index == active;
                                        final isPassed = index < active;
                                        final textColor = isCurrent
                                            ? Colors.white
                                            : isPassed
                                            ? const Color(0x58FFFFFF)
                                            : const Color(0xB3FFFFFF);
                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              _follow = true;
                                              _lastActive = -2;
                                            });
                                            ref
                                                .read(
                                                  playerControllerProvider
                                                      .notifier,
                                                )
                                                .seek(lines[index].at);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 3,
                                            ),
                                            child: AnimatedContainer(
                                              duration: AppMotion.duration(
                                                context,
                                                240,
                                              ),
                                              alignment: Alignment.centerLeft,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isCurrent
                                                    ? const Color(0x28FFFFFF)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: isCurrent
                                                    ? Border.all(
                                                        color: const Color(
                                                          0x42FFFFFF,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                              child: AnimatedScale(
                                                scale: isCurrent ? 1.0 : 0.95,
                                                alignment: Alignment.centerLeft,
                                                duration: AppMotion.duration(
                                                  context,
                                                  240,
                                                ),
                                                curve: Curves.easeOutCubic,
                                                child: AnimatedDefaultTextStyle(
                                                  duration: AppMotion.duration(
                                                    context,
                                                    240,
                                                  ),
                                                  style: style.copyWith(
                                                    color: textColor,
                                                    fontWeight: isCurrent
                                                        ? FontWeight.w800
                                                        : FontWeight.w600,
                                                    shadows: isCurrent
                                                        ? const [
                                                            Shadow(
                                                              color: Color(
                                                                0x55FFFFFF,
                                                              ),
                                                              blurRadius: 12,
                                                            ),
                                                          ]
                                                        : null,
                                                  ),
                                                  child: Text(
                                                    lines[index].text,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                            ),
                            if (!_follow)
                              Positioned(
                                bottom: 10,
                                left: 12,
                                right: 12,
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Material(
                                      color: const Color(0xE610131C),
                                      shape: const StadiumBorder(
                                        side: BorderSide(
                                          color: Color(0x48FFFFFF),
                                        ),
                                      ),
                                      elevation: 6,
                                      child: InkWell(
                                        onTap: _recenter,
                                        customBorder: const StadiumBorder(),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.my_location_rounded,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Về câu đang phát',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    )
                  : plain.isNotEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: plain.length,
                      itemBuilder: (_, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          plain[index],
                          style: const TextStyle(
                            fontSize: 15.5,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xE6FFFFFF),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lyrics_outlined,
                              size: 32,
                              color: Color(0x99FFFFFF),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Chưa có lời cho bài hát này.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xCCFFFFFF),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: widget.onShowCover,
                              icon: const Icon(
                                Icons.album_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Quay lại đĩa nhạc',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerSeekSection extends ConsumerStatefulWidget {
  const _PlayerSeekSection();

  @override
  ConsumerState<_PlayerSeekSection> createState() => _PlayerSeekSectionState();
}

class _PlayerSeekSectionState extends ConsumerState<_PlayerSeekSection> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final slice = ref.watch(
      playerControllerProvider.select(
        (s) => (
          position: s.position,
          duration: s.duration,
          isAd: s.isAd,
          adCanSkip: s.adCanSkip,
          loading: s.loading,
          hasFailure: s.failure != null,
        ),
      ),
    );
    final controller = ref.read(playerControllerProvider.notifier);
    final duration = slice.duration.inMilliseconds.toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: Colors.white,
            thumbColor: Colors.white,
            inactiveTrackColor: const Color(0x33FFFFFF),
          ),
          child: Slider(
            padding: const EdgeInsets.symmetric(vertical: 16),
            value: (_drag ?? slice.position.inMilliseconds.toDouble()).clamp(
              0,
              duration > 0 ? duration : 1,
            ),
            max: duration > 0 ? duration : 1,
            semanticFormatterCallback: (value) =>
                playbackTime(Duration(milliseconds: value.round())),
            onChanged:
                slice.isAd || slice.loading || duration <= 0 || slice.hasFailure
                ? null
                : (value) => setState(() => _drag = value),
            onChangeEnd: (value) {
              controller.seek(Duration(milliseconds: value.round()));
              setState(() => _drag = null);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              playbackTime(
                _drag == null
                    ? slice.position
                    : Duration(milliseconds: _drag!.round()),
              ),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xCCFFFFFF),
              ),
            ),
            Text(
              playbackTime(slice.duration),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xCCFFFFFF),
              ),
            ),
          ],
        ),
        if (slice.isAd) ...[
          const SizedBox(height: 14),
          if (slice.adCanSkip)
            OutlinedButton(
              onPressed: slice.position >= const Duration(seconds: 5)
                  ? controller.skipAd
                  : null,
              child: Text(
                slice.position >= const Duration(seconds: 5)
                    ? 'Bỏ qua quảng cáo'
                    : 'Bỏ qua sau ${5 - slice.position.inSeconds}s',
              ),
            )
          else
            const Text(
              'Quảng cáo sẽ phát hết trước bài hát tiếp theo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondary),
            ),
          const SizedBox(height: 8),
          Center(child: _UpgradeButton(isBasic: slice.adCanSkip)),
        ],
      ],
    );
  }
}

class _LikeButton extends ConsumerWidget {
  const _LikeButton({required this.track, this.compact = false});
  final Track track;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(
      sessionControllerProvider.select((s) => s.session?.user.id),
    );
    final library = user == null ? null : ref.watch(libraryControllerProvider);
    final liked = library?.likedIds.contains(track.spotifyId) == true;
    return IconButton(
      tooltip: liked ? 'Bỏ lưu yêu thích' : 'Lưu vào yêu thích',
      // Chỉ khoá khi một thao tác like/unlike đang chạy; failure của lần
      // tải thư viện nền không được khoá nút vĩnh viễn.
      onPressed: library?.busy == true
          ? null
          : () => performTrackAction(context, ref, track, 'like'),
      icon: AnimatedSwitcher(
        duration: AppMotion.duration(context, 180),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(liked),
          color: liked
              ? AppColors.liked
              : compact
              ? AppColors.secondary
              : AppColors.text,
          size: compact ? 22 : 27,
        ),
      ),
    );
  }
}

class _PlayIcon extends StatelessWidget {
  const _PlayIcon({required this.playing, required this.size});
  final bool playing;
  final double size;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.duration(context, 160),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: .8, end: 1).animate(animation),
        child: child,
      ),
    ),
    child: Icon(
      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
      key: ValueKey(playing),
      size: size,
    ),
  );
}

class _PlayerCompanionCard extends ConsumerWidget {
  const _PlayerCompanionCard({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slice = ref.watch(
      playerControllerProvider.select(
        (s) => (
          queue: s.queue,
          index: s.index,
          repeat: s.repeat,
          loading: s.loading,
          isAd: s.isAd,
          offline: s.offline,
          source: s.source,
        ),
      ),
    );
    final controller = ref.read(playerControllerProvider.notifier);

    final upcoming = <({int index, Track track})>[];
    if (slice.index >= 0 && slice.index + 1 < slice.queue.length) {
      final end = (slice.index + 3).clamp(0, slice.queue.length);
      for (var i = slice.index + 1; i < end; i++) {
        upcoming.add((index: i, track: slice.queue[i]));
      }
    } else if (slice.repeat == PlaybackRepeat.all && slice.queue.length > 1) {
      final end = slice.index.clamp(0, 2);
      for (var i = 0; i < end; i++) {
        upcoming.add((index: i, track: slice.queue[i]));
      }
    }

    final hasArtistLink =
        track.artistId != null && track.artistId!.trim().isNotEmpty;

    return ArtworkPaletteBuilder(
      image: track.image,
      builder: (context, palette, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.dominant.withValues(alpha: 0.68),
              palette.deep.withValues(alpha: 0.90),
              const Color(0xF011141C),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x2EFFFFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    color: palette.accent,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tiếp theo trong danh sách',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (slice.queue.isNotEmpty && slice.index >= 0) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 0,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x24FFFFFF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x26FFFFFF)),
                          ),
                          child: Text(
                            'Bài ${slice.index + 1}/${slice.queue.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (upcoming.isNotEmpty)
                ...upcoming.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: const Color(0x1CFFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: slice.loading || slice.isAd
                            ? null
                            : () => controller.select(
                                slice.queue,
                                entry.index,
                                offline: slice.offline,
                                source: slice.source,
                              ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x22FFFFFF)),
                          ),
                          child: Row(
                            children: [
                              MusicArtwork(
                                image: entry.track.image,
                                size: 42,
                                radius: 10,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.track.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      entry.track.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xB8FFFFFF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x16FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x1FFFFFFF)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        slice.repeat == PlaybackRepeat.one
                            ? Icons.repeat_one_rounded
                            : Icons.playlist_play_rounded,
                        color: const Color(0xCCFFFFFF),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          slice.repeat == PlaybackRepeat.one
                              ? 'Đang bật lặp lại cho bài hát hiện tại.'
                              : 'Đã đến cuối danh sách phát hiện tại.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xCCFFFFFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 22, color: Color(0x22FFFFFF)),
              _PlayerArtistSection(track: track),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CompanionActionChip(
                    icon: Icons.playlist_add_rounded,
                    label: 'Thêm vào playlist',
                    onTap: () =>
                        performTrackAction(context, ref, track, 'playlist'),
                  ),
                  if (hasArtistLink)
                    _CompanionActionChip(
                      icon: Icons.person_search_rounded,
                      label: 'Xem nghệ sĩ',
                      onTap: () =>
                          performTrackAction(context, ref, track, 'artist'),
                    ),
                  _CompanionActionChip(
                    icon: Icons.format_list_bulleted_rounded,
                    label: 'Mở hàng đợi',
                    onTap: () => showPlayerQueue(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerArtistSection extends ConsumerWidget {
  const _PlayerArtistSection({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistId = track.artistId;
    final hasArtistId = artistId != null && artistId.trim().isNotEmpty;
    final user = ref.watch(sessionControllerProvider).session?.user.id;
    final profileAsync = hasArtistId
        ? ref.watch(artistProfileProvider(artistId))
        : null;
    final followAction = hasArtistId
        ? ref.watch(artistFollowActionProvider(artistId))
        : null;

    final profile = profileAsync?.valueOrNull;
    final isFollowed = profile?.followed ?? false;
    final followers = profile?.followers;
    final artistAvatar = profile?.image;

    void openArtist() {
      if (hasArtistId) {
        context.push(
          Uri(
            path: '/artist/${segment(artistId)}',
            queryParameters: {'name': track.artist},
          ).toString(),
        );
      }
    }

    void toggleFollow() {
      if (user == null) {
        context.push(
          '/sign-in?from=${Uri.encodeComponent(GoRouterState.of(context).uri.toString())}',
        );
        return;
      }
      if (hasArtistId) {
        ref.read(artistFollowActionProvider(artistId).notifier).run();
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x18FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: hasArtistId ? openArtist : null,
            borderRadius: BorderRadius.circular(999),
            child: artistAvatar != null && artistAvatar.isNotEmpty
                ? ClipOval(
                    child: MusicArtwork(
                      image: artistAvatar,
                      size: 46,
                      round: true,
                    ),
                  )
                : Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x2AFFFFFF),
                      border: Border.all(color: const Color(0x38FFFFFF)),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: hasArtistId ? openArtist : null,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    followers != null
                        ? '$followers người theo dõi'
                        : hasArtistId
                        ? 'Nghệ sĩ'
                        : 'Chưa rõ nghệ sĩ',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xB8FFFFFF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (hasArtistId)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: followAction?.isLoading == true
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Material(
                      color: isFollowed
                          ? const Color(0x28FFFFFF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        onTap: toggleFollow,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isFollowed
                                  ? const Color(0x40FFFFFF)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFollowed
                                    ? Icons.check_rounded
                                    : Icons.person_add_alt_1_rounded,
                                size: 14,
                                color: isFollowed
                                    ? Colors.white
                                    : const Color(0xFF090A0D),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isFollowed ? 'Đang theo dõi' : 'Theo dõi',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isFollowed
                                      ? Colors.white
                                      : const Color(0xFF090A0D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _CompanionActionChip extends StatelessWidget {
  const _CompanionActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Material(
      color: const Color(0x22FFFFFF),
      shape: const StadiumBorder(side: BorderSide(color: Color(0x2EFFFFFF))),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
