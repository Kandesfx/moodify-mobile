import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/bootstrap.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/feedback_panel.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../karaoke/presentation/karaoke_screen.dart';
import 'player_controller.dart';

String playbackTime(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 86400);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

final premiumUrlLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

class _UpgradeButton extends ConsumerStatefulWidget {
  const _UpgradeButton({required this.isBasic});
  final bool isBasic;

  @override
  ConsumerState<_UpgradeButton> createState() => _UpgradeButtonState();
}

class _UpgradeButtonState extends ConsumerState<_UpgradeButton> {
  bool _opening = false;

  Future<void> _open() async {
    final uri = ref.read(appConfigProvider).premiumWebUri;
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trang nâng cấp chưa được cấu hình.')),
      );
      return;
    }
    final controller = ref.read(playerControllerProvider.notifier);
    final generation = controller.playbackGeneration;
    setState(() => _opening = true);
    var opened = false;
    try {
      opened = await ref.read(premiumUrlLauncherProvider)(uri);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không mở được trang nâng cấp. Vui lòng thử lại.'),
        ),
      );
      return;
    }
    await controller.skipAdForUpgrade(generation);
  }

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: _opening ? null : _open,
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF8B72F6),
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    icon: const Icon(Icons.workspace_premium_rounded, size: 18),
    label: Text(widget.isBasic ? 'Lên FULL' : 'Nâng VIP'),
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
                      )
                    else
                      Text(
                        'Nghe hết quảng cáo',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondary,
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
    if (ref.watch(karaokePlaybackActiveProvider)) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(playerControllerProvider);
    final track = state.track;
    if (track == null) return const SizedBox.shrink();
    final controller = ref.read(playerControllerProvider.notifier);
    if (state.isAd) {
      return _AdMiniPlayer(state: state, controller: controller);
    }
    return Material(
      color: AppColors.surfaceRaised,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => context.push('/player'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  MusicArtwork(image: track.image, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          state.failure != null
                              ? 'Chưa phát được · Chạm để xem'
                              : track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: state.failure != null
                                ? AppColors.error
                                : AppColors.secondary,
                          ),
                        ),
                      ],
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
                        size: 32,
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
            backgroundColor: AppColors.border,
          ),
        ],
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
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final track = state.track;
    final duration = state.duration.inMilliseconds.toDouble();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đang phát'),
        leading: IconButton(
          tooltip: 'Thu nhỏ',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        actions: [
          if (track != null)
            IconButton(
              tooltip: 'Dừng phát và xóa hàng đợi',
              onPressed: controller.clear,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: track == null
          ? const LoadMessage(message: 'Chọn một bài hát để bắt đầu nghe.')
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, bounds) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: state.isAd
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.asset(
                                      state.position <
                                              const Duration(milliseconds: 9500)
                                          ? 'assets/ads/moodify_brand_ident_art.jpg'
                                          : 'assets/ads/moodify_vip_premium_art.jpg',
                                      width: (bounds.maxWidth - 56).clamp(
                                        180,
                                        360,
                                      ),
                                      height: (bounds.maxWidth - 56).clamp(
                                        180,
                                        360,
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : MusicArtwork(
                                    image: track.image,
                                    size: (bounds.maxWidth - 56).clamp(
                                      180,
                                      360,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            state.isAd ? 'Quảng cáo' : track.displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.isAd
                                ? 'Tiếp theo: ${track.displayName}'
                                : track.artist,
                            style: const TextStyle(color: AppColors.secondary),
                          ),
                          if (state.failure != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: FeedbackPanel(
                                message: state.failure!.message,
                              ),
                            ),
                          const SizedBox(height: 20),
                          Slider(
                            value:
                                (_drag ??
                                        state.position.inMilliseconds
                                            .toDouble())
                                    .clamp(0, duration > 0 ? duration : 1),
                            max: duration > 0 ? duration : 1,
                            semanticFormatterCallback: (value) => playbackTime(
                              Duration(milliseconds: value.round()),
                            ),
                            onChanged:
                                state.isAd ||
                                    state.loading ||
                                    duration <= 0 ||
                                    state.failure != null
                                ? null
                                : (value) => setState(() => _drag = value),
                            onChangeEnd: (value) {
                              controller.seek(
                                Duration(milliseconds: value.round()),
                              );
                              setState(() => _drag = null);
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                playbackTime(
                                  _drag == null
                                      ? state.position
                                      : Duration(milliseconds: _drag!.round()),
                                ),
                              ),
                              Text(playbackTime(state.duration)),
                            ],
                          ),
                          if (state.isAd) ...[
                            const SizedBox(height: 12),
                            if (state.adCanSkip)
                              OutlinedButton(
                                onPressed:
                                    state.position >= const Duration(seconds: 5)
                                    ? controller.skipAd
                                    : null,
                                child: Text(
                                  state.position >= const Duration(seconds: 5)
                                      ? 'Bỏ qua quảng cáo'
                                      : 'Bỏ qua sau ${5 - state.position.inSeconds}s',
                                ),
                              )
                            else
                              const Text(
                                'Quảng cáo sẽ phát hết trước bài hát tiếp theo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.secondary),
                              ),
                            const SizedBox(height: 8),
                            _UpgradeButton(isBasic: state.adCanSkip),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                tooltip: state.shuffle
                                    ? 'Tắt phát ngẫu nhiên'
                                    : 'Phát ngẫu nhiên',
                                color: state.shuffle
                                    ? AppColors.primary
                                    : AppColors.secondary,
                                onPressed: controller.toggleShuffle,
                                icon: const Icon(Icons.shuffle_rounded),
                              ),
                              IconButton(
                                tooltip: 'Bài trước',
                                onPressed: state.loading || state.isAd
                                    ? null
                                    : controller.previous,
                                icon: const Icon(
                                  Icons.skip_previous_rounded,
                                  size: 32,
                                ),
                              ),
                              IconButton.filled(
                                tooltip: state.playing ? 'Tạm dừng' : 'Phát',
                                iconSize: 42,
                                padding: const EdgeInsets.all(12),
                                onPressed: state.loading
                                    ? controller.pause
                                    : state.playing
                                    ? controller.pause
                                    : controller.play,
                                icon: state.loading
                                    ? const SizedBox.square(
                                        dimension: 36,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        state.playing
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                      ),
                              ),
                              IconButton(
                                tooltip: 'Bài tiếp theo',
                                onPressed: state.loading || state.isAd
                                    ? null
                                    : controller.next,
                                icon: const Icon(
                                  Icons.skip_next_rounded,
                                  size: 32,
                                ),
                              ),
                              IconButton(
                                tooltip: switch (state.repeat) {
                                  PlaybackRepeat.off => 'Lặp lại đang tắt',
                                  PlaybackRepeat.all => 'Lặp cả hàng đợi',
                                  PlaybackRepeat.one => 'Lặp một bài',
                                },
                                color: state.repeat == PlaybackRepeat.off
                                    ? AppColors.secondary
                                    : AppColors.primary,
                                onPressed: controller.cycleRepeat,
                                icon: Icon(
                                  state.repeat == PlaybackRepeat.one
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (!state.isAd)
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Lời bài hát'),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: SelectableText(
                                    track.lyrics ??
                                        'Chưa có lời cho bài hát này.',
                                  ),
                                ),
                              ],
                            ),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text('Hàng đợi · ${state.queue.length} bài'),
                            children: [
                              for (var i = 0; i < state.queue.length; i++)
                                TrackTile(
                                  track: state.queue[i],
                                  queue: state.queue,
                                  index: i,
                                ),
                            ],
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
