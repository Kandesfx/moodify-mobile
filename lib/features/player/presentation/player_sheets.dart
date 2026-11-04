import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../subscriptions/data/subscription_repository.dart';
import '../domain/lyric_line.dart';
import 'player_controller.dart';

final syncedLyricsAllowedProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final user = ref.watch(
    sessionControllerProvider.select((s) => s.session?.user.id),
  );
  if (user == null) return false;
  final current = await ref.watch(subscriptionRepositoryProvider).current();
  return current.syncedLyrics;
});

final playerLyricLinesProvider = Provider.autoDispose<List<LyricLine>>(
  (ref) => parseLrc(
    ref.watch(
      playerControllerProvider.select((state) => state.track?.lyricsSynced),
    ),
  ),
);

void showPlayerQueue(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  sheetAnimationStyle: AnimationStyle(
    duration: AppMotion.duration(context, 280),
    reverseDuration: AppMotion.duration(context, 220),
  ),
  builder: (_) => const _QueueSheet(),
);

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerControllerProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'Hàng đợi · ${state.queue.length} bài',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: state.queue.length,
                itemBuilder: (_, i) => ListTile(
                  leading: MusicArtwork(image: state.queue[i].image),
                  title: Text(
                    state.queue[i].displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    state.queue[i].artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: i == state.index,
                  selectedColor: AppColors.primary,
                  trailing: i == state.index
                      ? const Icon(Icons.graphic_eq_rounded)
                      : null,
                  onTap: () => ref
                      .read(playerControllerProvider.notifier)
                      .select(
                        state.queue,
                        i,
                        offline: state.offline,
                        source: state.source,
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

void showPlayerLyrics(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  sheetAnimationStyle: AnimationStyle(
    duration: AppMotion.duration(context, 280),
    reverseDuration: AppMotion.duration(context, 220),
  ),
  builder: (_) => const _LyricsSheet(),
);

class _LyricsSheet extends ConsumerWidget {
  const _LyricsSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerControllerProvider);
    final allowed = ref.watch(syncedLyricsAllowedProvider);
    final lines = ref.watch(playerLyricLinesProvider);
    final synced = allowed.valueOrNull == true && lines.isNotEmpty;
    final active = lines.lastIndexWhere((line) => line.at <= state.position);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lời bài hát',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(state.track?.displayName ?? ''),
                  if (allowed.isLoading) const LinearProgressIndicator(),
                  if (synced)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        active < 0 ? 'Nhạc dạo' : lines[active].text,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFFC5B7FF),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: synced
                  ? ListView.builder(
                      itemCount: lines.length,
                      itemBuilder: (_, i) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        selected: i == active,
                        title: Text(
                          lines[i].text,
                          style: TextStyle(
                            color: i == active
                                ? const Color(0xFFC5B7FF)
                                : AppColors.secondary,
                            fontSize: 20,
                            fontWeight: i == active
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        onTap: state.loading
                            ? null
                            : () => ref
                                  .read(playerControllerProvider.notifier)
                                  .seek(lines[i].at),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      child: SelectableText(
                        state.track?.lyrics ?? 'Chưa có lời cho bài hát này.',
                        style: const TextStyle(fontSize: 18, height: 1.9),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

void showSleepTimer(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (_) => Consumer(
    builder: (context, ref, _) {
      final state = ref.watch(playerControllerProvider);
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  'Hẹn giờ dừng nhạc',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (state.sleepUntil != null)
                ListTile(
                  leading: const Icon(Icons.timer_off_outlined),
                  title: const Text('Tắt hẹn giờ'),
                  onTap: () {
                    ref.read(playerControllerProvider.notifier).sleep(null);
                    Navigator.pop(context);
                  },
                ),
              for (final minutes in [15, 30, 45, 60])
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text('$minutes phút'),
                  onTap: () {
                    ref
                        .read(playerControllerProvider.notifier)
                        .sleep(Duration(minutes: minutes));
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      );
    },
  ),
);
