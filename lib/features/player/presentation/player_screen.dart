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
import '../../subscriptions/application/premium_controller.dart';
import 'player_controller.dart';
import 'player_sheets.dart';

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

/// Badge vàng Hoàng Kim trên player khi gói VIP đang hiệu lực
/// (parity badge "VIP" cạnh volume trên web).
class _PlayerVipBadge extends StatelessWidget {
  const _PlayerVipBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.vipGradientTop, AppColors.vipGradientBottom],
      ),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.vipBorder),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.workspace_premium_rounded, size: 13, color: AppColors.vipGold),
        SizedBox(width: 4),
        Text(
          'VIP',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
            color: AppColors.vipGold,
          ),
        ),
      ],
    ),
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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF272238), Color(0xFF17151F)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF494058)),
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
    final state = ref.watch(playerControllerProvider);
    if (state.source == 'KARAOKE') return const SizedBox.shrink();
    final track = state.track;
    if (track == null) return const SizedBox.shrink();
    final controller = ref.read(playerControllerProvider.notifier);
    if (state.isAd) {
      return _AdMiniPlayer(state: state, controller: controller);
    }
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
                    IconButton(
                      tooltip: 'Bài tiếp theo',
                      onPressed: state.loading || state.isAd
                          ? null
                          : controller.next,
                      icon: const Icon(Icons.skip_next_rounded),
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
    final isPremium = ref.watch(premiumProvider.select((s) => s.isPremium));
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
                                state.isAd
                                    ? 'QUẢNG CÁO'
                                    : state.offline
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
                                state.isAd ? 'Moodify Ads' : 'Moodify',
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
                            final isIdentArt =
                                state.position <
                                const Duration(milliseconds: 9500);
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
                                              key: ValueKey(
                                                state.isAd
                                                    ? 'ad-$isIdentArt'
                                                    : track.id,
                                              ),
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
                                              child: state.isAd
                                                  ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                      child: Image.asset(
                                                        isIdentArt
                                                            ? 'assets/ads/moodify_brand_ident_art.jpg'
                                                            : 'assets/ads/moodify_vip_premium_art.jpg',
                                                        width: artSize
                                                            .toDouble(),
                                                        height: artSize
                                                            .toDouble(),
                                                        fit: BoxFit.cover,
                                                      ),
                                                    )
                                                  : MusicArtwork(
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
                                                  state.isAd
                                                      ? 'Quảng cáo'
                                                      : track.displayName,
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    height: 1.3,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        state.isAd
                                                            ? 'Tiếp theo: ${track.displayName}'
                                                            : track.artist,
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          color:
                                                              AppColors
                                                                  .secondary,
                                                        ),
                                                      ),
                                                    ),
                                                    if (!state.isAd &&
                                                        isPremium) ...[
                                                      const SizedBox(width: 8),
                                                      const _PlayerVipBadge(),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!state.isAd) ...[
                                            TrackDownloadButton(track: track),
                                            _LikeButton(track: track),
                                          ],
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
                                              state.isAd ||
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
                                      if (state.isAd) ...[
                                        const SizedBox(height: 14),
                                        if (state.adCanSkip)
                                          OutlinedButton(
                                            onPressed:
                                                state.position >=
                                                    const Duration(seconds: 5)
                                                ? controller.skipAd
                                                : null,
                                            child: Text(
                                              state.position >=
                                                      const Duration(seconds: 5)
                                                  ? 'Bỏ qua quảng cáo'
                                                  : 'Bỏ qua sau ${5 - state.position.inSeconds}s',
                                            ),
                                          )
                                        else
                                          const Text(
                                            'Quảng cáo sẽ phát hết trước bài hát tiếp theo.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: AppColors.secondary,
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        Center(
                                          child: _UpgradeButton(
                                            isBasic: state.adCanSkip,
                                          ),
                                        ),
                                      ],
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
                                            onPressed:
                                                state.loading || state.isAd
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
                                            onPressed:
                                                state.loading || state.isAd
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

class _LyricsPreview extends ConsumerWidget {
  const _LyricsPreview({required this.track});
  final Track track;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(
      playerControllerProvider.select((s) => s.position),
    );
    final lines = ref.watch(playerLyricLinesProvider);
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
