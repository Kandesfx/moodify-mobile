import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_sheets.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../domain/lyric_line.dart';
import 'player_controller.dart';

final playerLyricLinesProvider = Provider.autoDispose<List<LyricLine>>((ref) {
  final lyrics = ref.watch(
    playerControllerProvider.select(
      (state) => (state.track?.lyricsSynced, state.track?.lyrics),
    ),
  );
  final synced = parseLrc(lyrics.$1);
  return synced.isNotEmpty ? synced : parseLrc(lyrics.$2);
});

final playerPlainLyricsProvider = Provider.autoDispose<List<String>>((ref) {
  final lines = ref.watch(playerLyricLinesProvider);
  if (lines.isNotEmpty) {
    return List.unmodifiable(lines.map((line) => line.text));
  }
  final plain = ref.watch(
    playerControllerProvider.select((s) => s.track?.lyrics),
  );
  return List.unmodifiable(
    (plain ?? '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty),
  );
});

void showPlayerQueue(BuildContext context) => showAppModalSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
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
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: state.queue.length,
                itemBuilder: (_, i) {
                  final active = i == state.index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF1C2029)
                            : const Color(0xFF12141A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: active
                              ? const Color(0x38FFFFFF)
                              : const Color(0x10FFFFFF),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
                        leading: MusicArtwork(
                          image: state.queue[i].image,
                          size: 48,
                          radius: 11,
                        ),
                        title: Text(
                          state.queue[i].displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: active ? Colors.white : AppColors.text,
                          ),
                        ),
                        subtitle: Text(
                          state.queue[i].artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.secondary,
                          ),
                        ),
                        selected: active,
                        selectedTileColor: Colors.transparent,
                        trailing: active
                            ? const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.graphic_eq_rounded,
                                  color: Colors.white,
                                ),
                              )
                            : i > state.index
                            ? IconButton(
                                tooltip: 'Bỏ bài sắp phát',
                                onPressed: () => ref
                                    .read(playerControllerProvider.notifier)
                                    .removeUpcoming(i),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.secondary,
                                ),
                              )
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showPlayerLyrics(BuildContext context) => context.push('/lyrics');

void showSleepTimer(BuildContext context) => showAppModalSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (_) => Consumer(
    builder: (context, ref, _) {
      final state = ref.watch(playerControllerProvider);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Hẹn giờ dừng nhạc',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111318),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Column(
                    children: [
                      if (state.sleepUntil != null) ...[
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceGlass,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borderSoft),
                            ),
                            child: const Icon(
                              Icons.timer_off_outlined,
                              size: 19,
                              color: Colors.white,
                            ),
                          ),
                          title: const Text(
                            'Tắt hẹn giờ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () {
                            ref
                                .read(playerControllerProvider.notifier)
                                .sleep(null);
                            Navigator.pop(context);
                          },
                        ),
                        const Divider(height: 1, indent: 60),
                      ],
                      for (final (idx, minutes) in [
                        15,
                        30,
                        45,
                        60,
                      ].indexed) ...[
                        if (idx > 0) const Divider(height: 1, indent: 60),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceGlass,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borderSoft),
                            ),
                            child: const Icon(
                              Icons.timer_outlined,
                              size: 19,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            '$minutes phút',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () {
                            ref
                                .read(playerControllerProvider.notifier)
                                .sleep(Duration(minutes: minutes));
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
);
