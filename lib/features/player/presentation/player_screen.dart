import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/feedback_panel.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/artwork_backdrop.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../library/presentation/library_controller.dart';
import '../domain/lyric_line.dart';
import 'player_controller.dart';
import 'player_sheets.dart';

String playbackTime(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 86400);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerControllerProvider);
    final track = state.track;
    if (track == null) return const SizedBox.shrink();
    final controller = ref.read(playerControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Material(
        color: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF383854)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pressable(
              onTap: () => context.push('/player'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 6, 6),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: AppMotion.duration(context),
                      child: MusicArtwork(
                        key: ValueKey(track.id),
                        image: track.image,
                        size: 44,
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
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.failure != null
                                ? 'Chưa phát được · Chạm để xem'
                                : track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: state.failure != null
                                  ? AppColors.error
                                  : AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _LikeButton(track: track, compact: true),
                    SizedBox.square(
                      dimension: 48,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                        ),
                        tooltip: state.playing ? 'Tạm dừng' : 'Phát',
                        onPressed: state.loading || state.playing
                            ? controller.pause
                            : controller.play,
                        icon: state.loading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : _PlayIcon(playing: state.playing, size: 25),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            LinearProgressIndicator(
              value: state.duration.inMilliseconds > 0
                  ? (state.position.inMilliseconds /
                            state.duration.inMilliseconds)
                        .clamp(0, 1)
                  : 0,
              minHeight: 2,
              color: AppColors.lavender,
              backgroundColor: AppColors.border,
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});
  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  double? _drag;
  void _close() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final track = state.track;
    final duration = state.duration.inMilliseconds.toDouble();
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
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Thu nhỏ',
                          onPressed: _close,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 30,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                state.offline
                                    ? 'ĐANG PHÁT OFFLINE'
                                    : 'ĐANG PHÁT',
                                style: const TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.6,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Moodify',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hẹn giờ ngủ',
                          onPressed: track == null
                              ? null
                              : () => showSleepTimer(context),
                          icon: Icon(
                            state.sleepUntil == null
                                ? Icons.bedtime_outlined
                                : Icons.bedtime_rounded,
                            color: state.sleepUntil == null
                                ? AppColors.text
                                : AppColors.lavender,
                            size: 22,
                          ),
                        ),
                        if (track != null) TrackOptionsButton(track: track),
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
                            final artSize = (bounds.maxWidth - 72).clamp(
                              180.0,
                              340.0,
                            );
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                12,
                                24,
                                28,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 460,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: AnimatedSwitcher(
                                            duration: AppMotion.duration(
                                              context,
                                              300,
                                            ),
                                            switchInCurve: Curves.easeOutCubic,
                                            switchOutCurve: Curves.easeInCubic,
                                            transitionBuilder:
                                                (child, animation) =>
                                                    FadeTransition(
                                                      opacity: animation,
                                                      child: ScaleTransition(
                                                        scale: Tween<double>(
                                                          begin: .96,
                                                          end: 1,
                                                        ).animate(animation),
                                                        child: child,
                                                      ),
                                                    ),
                                            child: DecoratedBox(
                                              key: ValueKey(track.id),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Color(0x40000000),
                                                    blurRadius: 28,
                                                    offset: Offset(0, 12),
                                                  ),
                                                ],
                                              ),
                                              child: MusicArtwork(
                                                image: track.image,
                                                size: artSize,
                                                radius: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
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
                                                  track.displayName,
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    height: 1.3,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  track.artist,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: AppColors.secondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Tải để nghe offline',
                                            onPressed: () => performTrackAction(
                                              context,
                                              ref,
                                              track,
                                              'download',
                                            ),
                                            icon: const Icon(
                                              Icons.arrow_circle_down_outlined,
                                              color: AppColors.secondary,
                                              size: 27,
                                            ),
                                          ),
                                          _LikeButton(track: track),
                                        ],
                                      ),
                                      if (state.failure != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 16,
                                          ),
                                          child: FeedbackPanel(
                                            message: state.failure!.message,
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 3,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 5,
                                              ),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                overlayRadius: 16,
                                              ),
                                          activeTrackColor: AppColors.primary,
                                          thumbColor: Colors.white,
                                          inactiveTrackColor: const Color(
                                            0xFF3B3B4D,
                                          ),
                                        ),
                                        child: Slider(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          value:
                                              (_drag ??
                                                      state
                                                          .position
                                                          .inMilliseconds
                                                          .toDouble())
                                                  .clamp(
                                                    0,
                                                    duration > 0 ? duration : 1,
                                                  ),
                                          max: duration > 0 ? duration : 1,
                                          semanticFormatterCallback: (value) =>
                                              playbackTime(
                                                Duration(
                                                  milliseconds: value.round(),
                                                ),
                                              ),
                                          onChanged:
                                              state.loading ||
                                                  duration <= 0 ||
                                                  state.failure != null
                                              ? null
                                              : (value) => setState(
                                                  () => _drag = value,
                                                ),
                                          onChangeEnd: (value) {
                                            controller.seek(
                                              Duration(
                                                milliseconds: value.round(),
                                              ),
                                            );
                                            setState(() => _drag = null);
                                          },
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            playbackTime(
                                              _drag == null
                                                  ? state.position
                                                  : Duration(
                                                      milliseconds: _drag!
                                                          .round(),
                                                    ),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.secondary,
                                            ),
                                          ),
                                          Text(
                                            playbackTime(state.duration),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 18),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          IconButton(
                                            tooltip: state.shuffle
                                                ? 'Tắt phát ngẫu nhiên'
                                                : 'Phát ngẫu nhiên',
                                            color: state.shuffle
                                                ? AppColors.lavender
                                                : AppColors.secondary,
                                            onPressed: controller.toggleShuffle,
                                            icon: const Icon(
                                              Icons.shuffle_rounded,
                                              size: 23,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Bài trước',
                                            onPressed: state.loading
                                                ? null
                                                : controller.previous,
                                            icon: const Icon(
                                              Icons.skip_previous_rounded,
                                              size: 32,
                                            ),
                                          ),
                                          SizedBox.square(
                                            dimension: 64,
                                            child: IconButton.filled(
                                              tooltip: state.playing
                                                  ? 'Tạm dừng'
                                                  : 'Phát',
                                              style: IconButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                foregroundColor:
                                                    AppColors.background,
                                              ),
                                              onPressed:
                                                  state.loading || state.playing
                                                  ? controller.pause
                                                  : controller.play,
                                              icon: state.loading
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
                                                      playing: state.playing,
                                                      size: 36,
                                                    ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Bài tiếp theo',
                                            onPressed: state.loading
                                                ? null
                                                : controller.next,
                                            icon: const Icon(
                                              Icons.skip_next_rounded,
                                              size: 32,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: switch (state.repeat) {
                                              PlaybackRepeat.off =>
                                                'Lặp lại đang tắt',
                                              PlaybackRepeat.all =>
                                                'Lặp cả hàng đợi',
                                              PlaybackRepeat.one =>
                                                'Lặp một bài',
                                            },
                                            color:
                                                state.repeat ==
                                                    PlaybackRepeat.off
                                                ? AppColors.secondary
                                                : AppColors.lavender,
                                            onPressed: controller.cycleRepeat,
                                            icon: Icon(
                                              state.repeat == PlaybackRepeat.one
                                                  ? Icons.repeat_one_rounded
                                                  : Icons.repeat_rounded,
                                              size: 23,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          IconButton(
                                            tooltip: state.volume == 0
                                                ? 'Bật âm thanh'
                                                : 'Tắt âm thanh',
                                            onPressed: () => controller.volume(
                                              state.volume == 0 ? 1 : 0,
                                            ),
                                            icon: Icon(
                                              state.volume == 0
                                                  ? Icons.volume_off_rounded
                                                  : Icons.volume_down_rounded,
                                              size: 21,
                                              color: AppColors.secondary,
                                            ),
                                          ),
                                          Expanded(
                                            child: SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                    trackHeight: 3,
                                                    thumbShape:
                                                        const RoundSliderThumbShape(
                                                          enabledThumbRadius: 4,
                                                        ),
                                                    activeTrackColor:
                                                        AppColors.lavender,
                                                    thumbColor:
                                                        AppColors.lavender,
                                                    inactiveTrackColor:
                                                        AppColors.border,
                                                  ),
                                              child: Slider(
                                                value: state.volume,
                                                onChanged: controller.volume,
                                                semanticFormatterCallback:
                                                    (value) =>
                                                        '${(value * 100).round()} phần trăm',
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${(state.volume * 100).round()}%',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => performTrackAction(
                                              context,
                                              ref,
                                              track,
                                              'share',
                                            ),
                                            icon: const Icon(
                                              Icons.ios_share_rounded,
                                              size: 19,
                                            ),
                                            label: const Text(
                                              'Chia sẻ',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () =>
                                                showPlayerQueue(context),
                                            icon: const Icon(
                                              Icons.queue_music_rounded,
                                              size: 21,
                                            ),
                                            label: const Text(
                                              'Hàng đợi',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _LyricsPreview(track: track),
                                      const SizedBox(height: 16),
                                      Center(
                                        child: TextButton.icon(
                                          onPressed: controller.clear,
                                          icon: const Icon(
                                            Icons.stop_circle_outlined,
                                            size: 20,
                                          ),
                                          label: const Text(
                                            'Dừng phát',
                                            style: TextStyle(fontSize: 12),
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
      onPressed:
          library?.busy == true ||
              library?.loading == true ||
              library?.failure != null
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

class _LyricsPreview extends ConsumerWidget {
  const _LyricsPreview({required this.track});
  final Track track;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(
      playerControllerProvider.select((s) => s.position),
    );
    final allowed = ref.watch(syncedLyricsAllowedProvider).valueOrNull == true;
    final lines = allowed ? ref.watch(playerLyricLinesProvider) : <LyricLine>[];
    final active = lines.lastIndexWhere((line) => line.at <= position);
    final preview = lines.isNotEmpty
        ? active < 0
              ? 'Nhạc dạo'
              : lines[active].text
        : track.lyrics?.trim();
    return Material(
      color: const Color(0x88231B3B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x443F315B)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Pressable(
        onTap: () => showPlayerLyrics(context),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.lyrics_outlined,
                    color: AppColors.lavender,
                    size: 19,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lời bài hát',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.lavender,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.open_in_full_rounded,
                    size: 18,
                    color: AppColors.lavender,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: AppMotion.duration(context),
                child: Text(
                  preview == null || preview.isEmpty
                      ? 'Chưa có lời cho bài hát này.'
                      : preview,
                  key: ValueKey(preview),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: preview == null ? 14 : 19,
                    height: 1.6,
                    fontWeight: preview == null
                        ? FontWeight.w400
                        : FontWeight.w600,
                    color: preview == null
                        ? AppColors.secondary
                        : AppColors.text,
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
