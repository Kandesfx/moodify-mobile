import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
                      : i > state.index
                      ? IconButton(
                          tooltip: 'Bỏ bài sắp phát',
                          onPressed: () => ref
                              .read(playerControllerProvider.notifier)
                              .removeUpcoming(i),
                          icon: const Icon(Icons.close),
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

class _LyricsSheet extends ConsumerStatefulWidget {
  const _LyricsSheet();
  @override
  ConsumerState<_LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends ConsumerState<_LyricsSheet> {
  final _scroll = ScrollController();
  bool _follow = true;
  int _lastActive = -2;
  String? _track;
  Object? _measureKey;
  List<double> _heights = [];
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _lines(
    List<LyricLine> lines,
    int active,
    bool loading,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final style = TextStyle(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        fontSize: 20,
        height: 1.5,
        fontWeight: FontWeight.w700,
      );
      final measureKey = (
        lines,
        constraints.maxWidth,
        MediaQuery.textScalerOf(context),
        Directionality.of(context),
        style.fontFamily,
      );
      if (_measureKey != measureKey) {
        _measureKey = measureKey;
        _heights = lines.map((line) {
          final painter =
              TextPainter(
                text: TextSpan(text: line.text, style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(
                maxWidth: (constraints.maxWidth - 48).clamp(1, double.infinity),
              );
          final height = painter.height + 32;
          painter.dispose();
          return height < 56 ? 56.0 : height;
        }).toList();
        _lastActive = -2;
      }
      final heights = _heights;
      if (_lastActive != active) {
        _lastActive = active;
        if (_follow && active >= 0) {
          final target =
              heights
                  .take(active)
                  .fold<double>(0, (sum, value) => sum + value) -
              constraints.maxHeight * .3;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                !_follow ||
                !_scroll.hasClients ||
                _lastActive != active) {
              return;
            }
            final offset = target.clamp(0.0, _scroll.position.maxScrollExtent);
            if (MediaQuery.disableAnimationsOf(context)) {
              _scroll.jumpTo(offset);
            } else {
              _scroll.animateTo(
                offset,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }
      }
      return NotificationListener<ScrollStartNotification>(
        onNotification: (event) {
          if (event.dragDetails != null && _follow) {
            setState(() => _follow = false);
          }
          return false;
        },
        child: ListView.builder(
          controller: _scroll,
          itemCount: lines.length,
          itemBuilder: (_, i) => SizedBox(
            height: heights[i],
            child: InkWell(
              onTap: loading
                  ? null
                  : () => ref
                        .read(playerControllerProvider.notifier)
                        .seek(lines[i].at),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Text(
                  lines[i].text,
                  style: style.copyWith(
                    color: i == active
                        ? AppColors.lavender
                        : AppColors.secondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerControllerProvider);
    final allowed = ref.watch(syncedLyricsAllowedProvider);
    final lines = ref.watch(playerLyricLinesProvider);
    if (_track != state.track?.id) {
      _track = state.track?.id;
      _follow = true;
      _lastActive = -2;
    }
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
                  if (allowed.hasError)
                    LoadMessage(
                      message: 'Chưa kiểm tra được quyền xem lời đồng bộ.',
                      retry: () => ref.invalidate(syncedLyricsAllowedProvider),
                    ),
                  if (!allowed.isLoading && !allowed.hasError && !synced)
                    Text(
                      lines.isEmpty
                          ? 'Bài này chưa có lời đồng bộ.'
                          : 'Gói hiện tại chưa có quyền xem lời đồng bộ.',
                    ),
                  if (!allowed.isLoading &&
                      !allowed.hasError &&
                      allowed.valueOrNull == false &&
                      lines.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/subscriptions');
                      },
                      child: const Text('Xem gói dịch vụ'),
                    ),
                  if (synced && !_follow)
                    TextButton(
                      onPressed: () => setState(() {
                        _follow = true;
                        _lastActive = -2;
                      }),
                      child: const Text('Về câu đang phát'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: synced
                  ? _lines(lines, active, state.loading)
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
