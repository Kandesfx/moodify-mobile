import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';
import '../../catalog/presentation/artwork_backdrop.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../domain/lyric_line.dart';
import 'player_controller.dart';
import 'player_screen.dart' show playbackTime;
import 'player_sheets.dart';

/// A view over the existing player; opening/closing lyrics never loads audio.
class LyricsScreen extends ConsumerWidget {
  const LyricsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerControllerProvider);
    final track = state.track;
    final lines = ref.watch(playerLyricLinesProvider);
    final plain = ref.watch(playerPlainLyricsProvider);
    final synchronized = lines.isNotEmpty && !state.isAd;
    final active = lines.lastIndexWhere((line) => line.at <= state.position);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ArtworkBackdrop(image: track?.image),
          const ColoredBox(color: Color(0x45090A0D)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Đóng lời bài hát',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0x22FFFFFF),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(42, 42),
                            side: const BorderSide(color: Color(0x28FFFFFF)),
                          ),
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/player'),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Lời bài hát',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (track != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: bounds.maxHeight * .38,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0x22FFFFFF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0x24FFFFFF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MusicArtwork(
                                    image: track.image,
                                    size: 48,
                                    radius: 12,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          track.displayName,
                                          maxLines:
                                              MediaQuery.textScalerOf(
                                                    context,
                                                  ).scale(17) >
                                                  24
                                              ? 1
                                              : 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          track.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xB8FFFFFF),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (state.isAd)
                                const Text(
                                  'Quảng cáo',
                                  style: TextStyle(
                                    color: Color(0xB8FFFFFF),
                                    fontSize: 12,
                                  ),
                                )
                              else if (lines.isEmpty)
                                Text(
                                  plain.isEmpty
                                      ? 'Chưa có lời cho bản thu này.'
                                      : 'Lời tĩnh · Bài này chưa có mốc thời gian đồng bộ.',
                                  style: const TextStyle(
                                    color: Color(0xB8FFFFFF),
                                    fontSize: 12,
                                  ),
                                )
                              else
                                Text(
                                  active < 0
                                      ? 'Nhạc dạo · Lời bắt đầu ${playbackTime(lines.first.at)}'
                                      : 'Lời đồng bộ · Chạm câu để tua',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: state.isAd
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Text(
                                'Quảng cáo đang phát. Lời bài hát sẽ tiếp tục khi nhạc trở lại.',
                              ),
                            ),
                          )
                        : track == null
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Text('Chọn một bài hát để xem lời.'),
                            ),
                          )
                        : synchronized
                        ? _SyncedLyrics(
                            key: ValueKey((track.id, lines)),
                            lines: lines,
                            active: active,
                            loading:
                                state.loading ||
                                state.failure != null ||
                                state.isAd,
                            trackId: track.id,
                          )
                        : plain.isEmpty
                        ? const SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lyrics_outlined,
                                    size: 44,
                                    color: AppColors.secondary,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Chưa có lời bài hát',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Bạn vẫn có thể tiếp tục nghe nhạc.',
                                    style: TextStyle(
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            key: ValueKey(('plain', track.id)),
                            padding: const EdgeInsets.fromLTRB(28, 20, 28, 48),
                            itemCount: plain.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: SelectableText(
                                plain[i],
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                  color: Color(0xFFE2DEEE),
                                ),
                              ),
                            ),
                          ),
                  ),
                  if (track != null) const _LyricsTransport(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncedLyrics extends ConsumerStatefulWidget {
  const _SyncedLyrics({
    super.key,
    required this.lines,
    required this.active,
    required this.loading,
    required this.trackId,
  });
  final List<LyricLine> lines;
  final int active;
  final bool loading;
  final String trackId;
  @override
  ConsumerState<_SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends ConsumerState<_SyncedLyrics> {
  final _scroll = ScrollController();
  bool _follow = true;
  int _lastActive = -2;
  Object? _measureKey;
  List<double> _heights = [], _offsets = [];
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _recenter() => setState(() {
    _follow = true;
    _lastActive = -2;
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final style = TextStyle(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        fontSize: box.maxWidth < 360 ? 27 : 32,
        height: 1.35,
        letterSpacing: -.6,
        fontWeight: FontWeight.w700,
      );
      final measureKey = (
        widget.lines,
        box.maxWidth,
        box.maxHeight,
        MediaQuery.textScalerOf(context),
        Directionality.of(context),
        style.fontFamily,
        Localizations.localeOf(context),
      );
      if (_measureKey != measureKey) {
        _measureKey = measureKey;
        _heights = [];
        _offsets = [];
        var offset = 0.0;
        for (final line in widget.lines) {
          final painter = TextPainter(
            text: TextSpan(text: line.text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.localeOf(context),
          )..layout(maxWidth: (box.maxWidth - 56).clamp(1, double.infinity));
          final height = (painter.height + 28).clamp(56.0, double.infinity);
          _offsets.add(offset);
          _heights.add(height);
          offset += height;
          painter.dispose();
        }
        _lastActive = -2;
      }
      final top = box.maxHeight * .16;
      if (_lastActive != widget.active) {
        final active = widget.active;
        _lastActive = active;
        final target = active < 0
            ? 0.0
            : top + _offsets[active] - box.maxHeight * .23;
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
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
      return Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (event) {
                if (event.dragDetails != null && _follow) {
                  setState(() => _follow = false);
                }
                return false;
              },
              child: ListView.builder(
                key: const ValueKey('synced-lyrics-list'),
                controller: _scroll,
                padding: EdgeInsets.only(top: top, bottom: box.maxHeight * .75),
                itemCount: widget.lines.length,
                itemExtentBuilder: (i, _) => _heights[i],
                itemBuilder: (context, i) {
                  final selected = i == widget.active;
                  final color = selected
                      ? AppColors.text
                      : i < widget.active
                      ? const Color(0x66FAFAFC)
                      : const Color(0x99FAFAFC);
                  return Semantics(
                    selected: selected,
                    button: true,
                    onTapHint: 'Tua đến ${playbackTime(widget.lines[i].at)}',
                    child: InkWell(
                      onTap: widget.loading
                          ? null
                          : () {
                              if (ref
                                      .read(playerControllerProvider)
                                      .track
                                      ?.id !=
                                  widget.trackId) {
                                return;
                              }
                              setState(() {
                                _follow = true;
                                _lastActive = i == widget.active
                                    ? -2
                                    : widget.active;
                              });
                              ref
                                  .read(playerControllerProvider.notifier)
                                  .seek(widget.lines[i].at);
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: AnimatedContainer(
                          duration: AppMotion.duration(context, 260),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0x22FFFFFF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: selected
                                ? Border.all(color: const Color(0x36FFFFFF))
                                : null,
                          ),
                          child: AnimatedScale(
                            scale: selected ? 1 : .98,
                            alignment: Alignment.centerLeft,
                            duration: AppMotion.duration(context, 260),
                            curve: Curves.easeOutCubic,
                            child: AnimatedDefaultTextStyle(
                              style: style.copyWith(
                                color: color,
                                shadows: selected
                                    ? const [
                                        Shadow(
                                          color: Color(0x55FFFFFF),
                                          blurRadius: 14,
                                        ),
                                      ]
                                    : null,
                              ),
                              duration: AppMotion.duration(context, 260),
                              curve: Curves.easeOutCubic,
                              child: Text(widget.lines[i].text),
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
              bottom: 12,
              left: 24,
              right: 24,
              child: Center(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF090A0D),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _recenter,
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('Về câu đang phát'),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _LyricsTransport extends ConsumerStatefulWidget {
  const _LyricsTransport();
  @override
  ConsumerState<_LyricsTransport> createState() => _LyricsTransportState();
}

class _LyricsTransportState extends ConsumerState<_LyricsTransport> {
  double? _draft;
  String? _scrubTrack;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    if (_scrubTrack != state.track?.id) _draft = null;
    final maximum = state.duration.inMilliseconds.toDouble();
    final enabled =
        !state.loading && !state.isAd && state.failure == null && maximum > 0;
    final position = (_draft ?? state.position.inMilliseconds.toDouble()).clamp(
      0.0,
      maximum > 0 ? maximum : 1.0,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: const BoxDecoration(
        color: Color(0xD90A0C12),
        border: Border(top: BorderSide(color: Color(0x24FFFFFF))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.failure != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    state.failure!.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: state.loading ? null : controller.play,
                  child: const Text('Thử phát lại'),
                ),
              ],
            ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
              activeTrackColor: Colors.white,
              thumbColor: Colors.white,
              inactiveTrackColor: const Color(0x33FFFFFF),
            ),
            child: Slider(
              label: playbackTime(Duration(milliseconds: position.round())),
              semanticFormatterCallback: (value) =>
                  playbackTime(Duration(milliseconds: value.round())),
              min: 0,
              max: maximum > 0 ? maximum : 1,
              value: position,
              onChangeStart: enabled
                  ? (_) => _scrubTrack = state.track?.id
                  : null,
              onChanged: enabled
                  ? (value) => setState(() => _draft = value)
                  : null,
              onChangeEnd: enabled
                  ? (value) {
                      if (_scrubTrack ==
                          ref.read(playerControllerProvider).track?.id) {
                        controller.seek(Duration(milliseconds: value.round()));
                      }
                      setState(() => _draft = null);
                    }
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  playbackTime(Duration(milliseconds: position.round())),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xCCFFFFFF),
                  ),
                ),
                Text(
                  playbackTime(state.duration),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xCCFFFFFF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Bài trước',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x22FFFFFF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0x0FFFFFFF),
                  disabledForegroundColor: const Color(0x4DFFFFFF),
                  minimumSize: const Size(48, 48),
                  side: const BorderSide(color: Color(0x2EFFFFFF)),
                ),
                onPressed: state.loading || state.isAd
                    ? null
                    : controller.previous,
                icon: const Icon(Icons.skip_previous_rounded, size: 28),
              ),
              const SizedBox(width: 18),
              DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x38FFFFFF),
                      blurRadius: 18,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: IconButton.filled(
                    tooltip: state.playing ? 'Tạm dừng' : 'Phát',
                    onPressed: state.loading
                        ? null
                        : state.playing
                        ? controller.pause
                        : controller.play,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.background,
                    ),
                    icon: state.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            state.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 32,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              IconButton(
                tooltip: 'Bài tiếp theo',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x22FFFFFF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0x0FFFFFFF),
                  disabledForegroundColor: const Color(0x4DFFFFFF),
                  minimumSize: const Size(48, 48),
                  side: const BorderSide(color: Color(0x2EFFFFFF)),
                ),
                onPressed: state.loading || state.isAd || state.queue.length < 2
                    ? null
                    : controller.next,
                icon: const Icon(Icons.skip_next_rounded, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
