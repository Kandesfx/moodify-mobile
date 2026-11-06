import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/app_sheets.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/artwork_backdrop.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../domain/lyric_line.dart';
import 'player_controller.dart';
import 'player_sheets.dart';

/// Hiển thị bảng chia sẻ chi tiết theo chuẩn Spotify & Moodify Web:
/// Hỗ trợ chia sẻ bài hát (thẻ bài hát + liên kết) và trích dẫn lời bài hát (Lyric Card)
/// với ràng buộc chặt chẽ cho các bài hát không có lời.
void showShareTrackSheet(BuildContext context, Track track) {
  showAppModalSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _TrackShareSheet(track: track),
  );
}

class _TrackShareSheet extends ConsumerStatefulWidget {
  const _TrackShareSheet({required this.track});
  final Track track;

  @override
  ConsumerState<_TrackShareSheet> createState() => _TrackShareSheetState();
}

class _TrackShareSheetState extends ConsumerState<_TrackShareSheet> {
  int _selectedTabIndex = 0; // 0: Bài hát, 1: Trích dẫn lời
  int _selectedLyricIndex = 0;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    // Khởi tạo câu lời mặc định dựa theo thời gian đang phát
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final position = ref.read(playerControllerProvider).position;
      final lines = ref.read(playerLyricLinesProvider);
      if (lines.isNotEmpty) {
        final active = lines.lastIndexWhere((line) => line.at <= position);
        final initial = active >= 0 ? active : 0;
        setState(() {
          _selectedLyricIndex = initial;
          _selectedIndices.add(initial);
        });
      }
    });
  }

  void _toggleLyricSelection(int index) {
    setState(() {
      _selectedLyricIndex = index;
      if (_selectedIndices.contains(index)) {
        if (_selectedIndices.length > 1) {
          _selectedIndices.remove(index);
        }
      } else {
        // Cho phép chọn tối đa 3 câu lời liên tiếp
        if (_selectedIndices.length >= 3) {
          _selectedIndices.clear();
        }
        _selectedIndices.add(index);
      }
    });
  }

  String _buildShareUrl() =>
      'https://moodify.click/dashboard/player?track=${widget.track.spotifyId}';

  Future<void> _copyTrackLink() async {
    final url = _buildShareUrl();
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép liên kết bài hát vào bộ nhớ tạm.'),
      ),
    );
  }

  Future<void> _shareTrack() async {
    final box = context.findRenderObject() as RenderBox?;
    final text =
        'Nghe bài hát "${widget.track.displayName}" của ${widget.track.artist} trên Moodify: ${_buildShareUrl()}';
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        title: 'Moodify',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _copyLyricQuote(String quoteText) async {
    final text =
        '“$quoteText”\n\n— Bài hát: ${widget.track.displayName} · ${widget.track.artist}\nNghe trên Moodify: ${_buildShareUrl()}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép đoạn trích lời bài hát vào bộ nhớ tạm.'),
      ),
    );
  }

  Future<void> _shareLyricQuote(String quoteText) async {
    final box = context.findRenderObject() as RenderBox?;
    final text =
        '“$quoteText”\n\n— Bài hát: ${widget.track.displayName} · ${widget.track.artist}\nNghe trên Moodify: ${_buildShareUrl()}';
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        title: 'Moodify - Trích dẫn lời bài hát',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(playerLyricLinesProvider);
    final plain = ref.watch(playerPlainLyricsProvider);
    final hasLyrics = lines.isNotEmpty || plain.isNotEmpty;

    // Lấy nội dung câu trích dẫn hiển thị trên Lyric Card
    final quoteList = <String>[];
    if (lines.isNotEmpty) {
      final sorted = _selectedIndices.toList()..sort();
      for (final idx in sorted) {
        if (idx >= 0 && idx < lines.length) {
          quoteList.add(lines[idx].text);
        }
      }
      if (quoteList.isEmpty &&
          _selectedLyricIndex >= 0 &&
          _selectedLyricIndex < lines.length) {
        quoteList.add(lines[_selectedLyricIndex].text);
      }
    } else if (plain.isNotEmpty) {
      final idx = _selectedLyricIndex.clamp(0, plain.length - 1);
      quoteList.add(plain[idx]);
    }
    final quoteText = quoteList.join('\n');

    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFF10131B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0x38FFFFFF)),
          left: BorderSide(color: Color(0x22FFFFFF)),
          right: BorderSide(color: Color(0x22FFFFFF)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thanh gạt & nút đóng
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x40FFFFFF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.ios_share_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Chia sẻ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xB8FFFFFF),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // Bộ chuyển đổi Tab (Bài hát / Trích dẫn lời)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x24FFFFFF)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ShareModeTab(
                        icon: Icons.music_note_rounded,
                        label: 'Thẻ bài hát',
                        selected: _selectedTabIndex == 0,
                        onTap: () => setState(() => _selectedTabIndex = 0),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _ShareModeTab(
                        icon: Icons.format_quote_rounded,
                        label: hasLyrics ? 'Trích dẫn lời' : 'Không có lời',
                        selected: _selectedTabIndex == 1,
                        disabled: !hasLyrics,
                        onTap: () {
                          if (!hasLyrics) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Bài hát này không có lời (bản hòa tấu hoặc chưa cập nhật lời).',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() => _selectedTabIndex = 1);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Nội dung theo Tab đã chọn
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.duration(context, 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _selectedTabIndex == 0
                    ? _TrackShareView(
                        key: const ValueKey('track-share-view'),
                        track: widget.track,
                        onCopyLink: _copyTrackLink,
                        onShare: _shareTrack,
                      )
                    : _LyricsShareView(
                        key: const ValueKey('lyrics-share-view'),
                        track: widget.track,
                        lines: lines,
                        plain: plain,
                        selectedIndices: _selectedIndices,
                        selectedLyricIndex: _selectedLyricIndex,
                        quoteText: quoteText,
                        onSelectLine: _toggleLyricSelection,
                        onCopyQuote: () => _copyLyricQuote(quoteText),
                        onShareQuote: () => _shareLyricQuote(quoteText),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareModeTab extends StatelessWidget {
  const _ShareModeTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: AppMotion.duration(context, 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected
                  ? const Color(0xFF090A0D)
                  : disabled
                  ? const Color(0x4DFFFFFF)
                  : const Color(0xB8FFFFFF),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF090A0D)
                    : disabled
                    ? const Color(0x4DFFFFFF)
                    : const Color(0xB8FFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Giao diện chia sẻ thẻ bài hát tiêu chuẩn
class _TrackShareView extends StatelessWidget {
  const _TrackShareView({
    super.key,
    required this.track,
    required this.onCopyLink,
    required this.onShare,
  });
  final Track track;
  final VoidCallback onCopyLink;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        children: [
          // Thẻ bài hát Studio Dark xem trước
          ArtworkPaletteBuilder(
            image: track.image,
            builder: (context, palette, _) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.dominant.withValues(alpha: 0.85),
                    palette.deep.withValues(alpha: 0.95),
                    const Color(0xF2090C12),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x38FFFFFF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.graphic_eq_rounded,
                            size: 14,
                            color: palette.accent,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'MOODIFY AUDIO',
                            style: TextStyle(
                              fontSize: 10.5,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x28FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'BẢN GHI ÂM SỐ',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x50000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: MusicArtwork(
                      image: track.image,
                      size: 150,
                      radius: 18,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    track.displayName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xC2FFFFFF),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x20000000),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x1AFFFFFF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 13,
                          color: Color(0xB8FFFFFF),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'moodify.click/dashboard/player?track=${track.spotifyId.length > 12 ? track.spotifyId.substring(0, 12) : track.spotifyId}...',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            color: Color(0xB8FFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Các nút hành động
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopyLink,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0x1CFFFFFF),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x38FFFFFF)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text(
                    'Sao chép link',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onShare,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF090A0D),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 17),
                  label: const Text(
                    'Chia sẻ bài hát',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Giao diện trích dẫn câu lời bài hát (Spotify Lyric Card style)
class _LyricsShareView extends StatelessWidget {
  const _LyricsShareView({
    super.key,
    required this.track,
    required this.lines,
    required this.plain,
    required this.selectedIndices,
    required this.selectedLyricIndex,
    required this.quoteText,
    required this.onSelectLine,
    required this.onCopyQuote,
    required this.onShareQuote,
  });

  final Track track;
  final List<LyricLine> lines;
  final List<String> plain;
  final Set<int> selectedIndices;
  final int selectedLyricIndex;
  final String quoteText;
  final ValueChanged<int> onSelectLine;
  final VoidCallback onCopyQuote;
  final VoidCallback onShareQuote;

  @override
  Widget build(BuildContext context) {
    final lineCount = lines.isNotEmpty ? lines.length : plain.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thẻ Lyric Card xem trước
          ArtworkPaletteBuilder(
            image: track.image,
            builder: (context, palette, _) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.dominant.withValues(alpha: 0.90),
                    palette.deep.withValues(alpha: 0.95),
                    const Color(0xF2090C12),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x38FFFFFF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            size: 16,
                            color: palette.accent,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'MOODIFY LYRICS',
                            style: TextStyle(
                              fontSize: 10.5,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x28FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'TRÍCH DẪN',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    quoteText.isEmpty
                        ? 'Chạm câu bên dưới để trích dẫn lời bài hát...'
                        : quoteText,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.45,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                      shadows: [
                        Shadow(color: Color(0x66000000), blurRadius: 10),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0x24FFFFFF), height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      MusicArtwork(image: track.image, size: 36, radius: 9),
                      const SizedBox(width: 10),
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
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xB8FFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Danh sách chọn câu lời
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Chọn câu lời muốn trích dẫn:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xCCFFFFFF),
                ),
              ),
              Text(
                'Đã chọn ${selectedIndices.length} câu',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0x99FFFFFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: lineCount,
              itemBuilder: (context, index) {
                final lineText = lines.isNotEmpty
                    ? lines[index].text
                    : plain[index];
                final isSelected = selectedIndices.contains(index);

                return InkWell(
                  onTap: () => onSelectLine(index),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0x28FFFFFF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: const Color(0x38FFFFFF))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : const Color(0x66FFFFFF),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lineText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0x99FFFFFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 18),

          // Các nút hành động
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopyQuote,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0x1CFFFFFF),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x38FFFFFF)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text(
                    'Sao chép lời',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onShareQuote,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF090A0D),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 17),
                  label: const Text(
                    'Chia sẻ trích dẫn',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
