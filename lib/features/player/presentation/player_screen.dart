import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/feedback_panel.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import 'player_controller.dart';

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
                    onPressed: state.loading ? null : controller.next,
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
                            child: MusicArtwork(
                              image: track.image,
                              size: (bounds.maxWidth - 56).clamp(180, 360),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            track.displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            track.artist,
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
                                onPressed: state.loading
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
