import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../offline/presentation/offline_controller.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/feedback_panel.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/app_sheets.dart';
import '../../auth/presentation/session_controller.dart';
import '../../library/presentation/library_controller.dart';
import '../../library/presentation/playlist_dialog.dart';
import '../../library/presentation/pending_track_action.dart';
import '../../player/presentation/player_controller.dart';
import '../../player/presentation/track_share_sheet.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog_models.dart';

class MusicArtwork extends ConsumerWidget {
  const MusicArtwork({
    super.key,
    this.image,
    this.size = 52,
    this.round = false,
    this.radius = 12,
  });
  final String? image;
  final double size;
  final bool round;
  final double radius;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = ref.watch(catalogRepositoryProvider).artwork(image);
    final borderRadius = BorderRadius.circular(round ? size / 2 : radius);
    final placeholder = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E212A), Color(0xFF13151B)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.secondary,
          size: (size * .35).clamp(20, 64),
        ),
      ),
    );
    return RepaintBoundary(
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: const Color(0x16FFFFFF)),
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: SizedBox.square(
            dimension: size,
            child: uri == null
                ? placeholder
                : Image.network(
                    uri.toString(),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    gaplessPlayback: true,
                    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                        .round()
                        .clamp(64, 720),
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => placeholder,
                  ),
          ),
        ),
      ),
    );
  }
}

class TrackTile extends ConsumerWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.queue,
    required this.index,
    this.remove,
    this.onSelected,
  });
  final Track track;
  final List<Track> queue;
  final int index;
  final VoidCallback? remove;
  final VoidCallback? onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      playerControllerProvider.select((s) => s.track?.id == track.id),
    );
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1C2029) : const Color(0xFF12141A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? const Color(0x38FFFFFF) : const Color(0x10FFFFFF),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                MusicArtwork(image: track.image, size: 52, radius: 12),
                if (active)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1C2029),
                          width: 2,
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              track.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                color: active ? Colors.white : AppColors.text,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: -0.15,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.secondary,
                ),
              ),
            ),
            onTap: () {
              onSelected?.call();
              final path = GoRouterState.of(context).uri.path;
              final source = path.startsWith('/album/')
                  ? 'ALBUM'
                  : path.startsWith('/artist/')
                  ? 'ARTIST'
                  : path.startsWith('/playlist/')
                  ? 'PLAYLIST'
                  : path == '/search'
                  ? 'SEARCH'
                  : path == '/library'
                  ? 'LIBRARY'
                  : path == '/home'
                  ? 'HOME'
                  : 'OTHER';
              ref
                  .read(playerControllerProvider.notifier)
                  .select(queue, index, source: source);
            },
            selected: active,
            selectedTileColor: Colors.transparent,
            trailing: TrackOptionsButton(track: track, remove: remove),
          ),
        ),
      ),
    );
  }
}

class TrackOptionsButton extends ConsumerWidget {
  const TrackOptionsButton({super.key, required this.track, this.remove});
  final Track track;
  final VoidCallback? remove;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Tùy chọn cho ${track.displayName}',
      onPressed: () =>
          showTrackOptionsSheet(context, ref, track, remove: remove),
      icon: const Icon(Icons.more_vert_rounded),
    );
  }
}

/// Sheet tuỳ chọn bài hát thay cho popup menu cũ — bố cục theo mẫu các app
/// nhạc phổ biến: header bài hát, nhóm hành động có icon, phân tách nhẹ.
Future<void> showTrackOptionsSheet(
  BuildContext context,
  WidgetRef ref,
  Track track, {
  VoidCallback? remove,
}) {
  return showAppModalSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _TrackOptionsSheet(
      track: track,
      remove: remove,
      // Hành động chạy với context/ref của nút mở sheet: sau khi sheet pop,
      // sheetContext không còn dùng được cho push/snackbar.
      onAction: (action) => performTrackAction(context, ref, track, action),
    ),
  );
}

class _TrackOptionsSheet extends ConsumerWidget {
  const _TrackOptionsSheet({
    required this.track,
    required this.onAction,
    this.remove,
  });
  final Track track;
  final Future<void> Function(String action) onAction;
  final VoidCallback? remove;

  void _run(BuildContext sheetContext, String action) {
    Navigator.of(sheetContext).pop();
    if (action == 'remove') {
      remove?.call();
      return;
    }
    unawaited(onAction(action));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(
      sessionControllerProvider.select((s) => s.session?.user.id),
    );
    final library = userId == null
        ? null
        : ref.watch(libraryControllerProvider);
    final liked = library?.likedIds.contains(track.spotifyId) == true;
    // Chỉ chờ thao tác thư viện đang chạy; failure của lần tải nền
    // không được khoá menu (like là optimistic, sẽ tự phục hồi khi load lại).
    final libraryReady = library == null || !library.busy;
    final downloads = ref.watch(offlineControllerProvider);
    final downloaded = downloads.entries.any((e) => e.track.id == track.id);
    final downloading = downloads.downloading == track.id;
    return SafeArea(
      // Sheet cuộn được khi màn hình thấp hoặc chữ lớn.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header bài hát
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161922),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x24FFFFFF)),
              ),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: MusicArtwork(
                      image: track.image,
                      size: 56,
                      radius: 14,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Nhóm 1: Thư viện & Tải nhạc
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF131620),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _OptionTile(
                    icon: liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    iconColor: liked ? const Color(0xFFFF4D6D) : Colors.white,
                    label: liked ? 'Bỏ lưu yêu thích' : 'Lưu vào yêu thích',
                    enabled: libraryReady,
                    onTap: () => _run(context, 'like'),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 68,
                    endIndent: 16,
                    color: Color(0x10FFFFFF),
                  ),
                  _OptionTile(
                    icon: Icons.playlist_add_rounded,
                    label: 'Thêm vào playlist',
                    enabled: libraryReady,
                    onTap: () => _run(context, 'playlist'),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 68,
                    endIndent: 16,
                    color: Color(0x10FFFFFF),
                  ),
                  _OptionTile(
                    icon: downloaded
                        ? Icons.check_circle_rounded
                        : downloading
                        ? Icons.downloading_rounded
                        : Icons.download_rounded,
                    iconColor: downloaded
                        ? const Color(0xFF2ECC71)
                        : downloading
                        ? const Color(0xFFFFB800)
                        : Colors.white,
                    label: downloaded
                        ? 'Xem bản đã tải'
                        : downloading
                        ? 'Xem tiến độ tải'
                        : 'Tải để nghe offline',
                    subtitle: downloaded
                        ? 'Đã tải về máy'
                        : downloading
                        ? 'Đang tải xuống...'
                        : null,
                    onTap: () => _run(
                      context,
                      downloaded || downloading ? 'downloads' : 'download',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Nhóm 2: Phát nhạc & Điều hướng
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF131620),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _OptionTile(
                    icon: Icons.queue_music_rounded,
                    label: 'Thêm vào hàng đợi',
                    onTap: () => _run(context, 'queue'),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 68,
                    endIndent: 16,
                    color: Color(0x10FFFFFF),
                  ),
                  _OptionTile(
                    icon: Icons.playlist_play_rounded,
                    label: 'Phát tiếp theo',
                    onTap: () => _run(context, 'next'),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 68,
                    endIndent: 16,
                    color: Color(0x10FFFFFF),
                  ),
                  _OptionTile(
                    icon: Icons.ios_share_rounded,
                    label: 'Chia sẻ bài hát',
                    onTap: () => _run(context, 'share'),
                  ),
                  if (track.artistId != null) ...[
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 68,
                      endIndent: 16,
                      color: Color(0x10FFFFFF),
                    ),
                    _OptionTile(
                      icon: Icons.person_rounded,
                      label: 'Xem nghệ sĩ',
                      onTap: () => _run(context, 'artist'),
                    ),
                  ],
                  if (remove != null) ...[
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 68,
                      endIndent: 16,
                      color: Color(0x10FFFFFF),
                    ),
                    _OptionTile(
                      icon: Icons.playlist_remove_rounded,
                      iconColor: const Color(0xFFFF5252),
                      label: 'Bỏ khỏi playlist',
                      onTap: () => _run(context, 'remove'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.subtitle,
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1D2230),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0x24FFFFFF)),
              ),
              child: Icon(
                icon,
                size: 20,
                color: enabled
                    ? (iconColor ?? Colors.white)
                    : const Color(0x4DFFFFFF),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: enabled ? Colors.white : const Color(0x59FFFFFF),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0x8CFFFFFF),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: enabled
                  ? const Color(0x52FFFFFF)
                  : const Color(0x1FFFFFFF),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> performTrackAction(
  BuildContext context,
  WidgetRef ref,
  Track track,
  String action,
) async {
  if (action == 'queue' || action == 'next') {
    final success = await ref
        .read(playerControllerProvider.notifier)
        .enqueue(track, next: action == 'next');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Đã thêm vào hàng đợi.'
                : 'Chưa thêm được. Bài có thể đã trong hàng đợi, hàng đợi đã đầy hoặc đang dùng chế độ offline/karaoke.',
          ),
        ),
      );
    }
    return;
  }
  if (action == 'downloads') {
    context.push('/offline');
    return;
  }
  if (action == 'share') {
    showShareTrackSheet(context, track);
    return;
  }
  if (action == 'artist') {
    context.push(
      Uri(
        path: '/artist/${segment(track.artistId!)}',
        queryParameters: {'name': track.artist},
      ).toString(),
    );
    return;
  }
  if (ref.read(sessionControllerProvider).session == null) {
    ref.read(pendingTrackActionProvider.notifier).state = PendingTrackAction(
      track,
      action,
      GoRouterState.of(context).uri.toString(),
    );
    context.push(
      Uri(
        path: '/sign-in',
        queryParameters: {'from': '/continue-action'},
      ).toString(),
    );
    return;
  }
  if (action == 'playlist') {
    await showAppModalSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlaylistPicker(track: track),
    );
    return;
  }
  if (action == 'download') {
    final controller = ref.read(offlineControllerProvider.notifier);
    final operation = controller.download(track);
    context.push('/offline');
    await operation;
    return;
  }
  final controller = ref.read(libraryControllerProvider.notifier);
  final success = await controller.toggleLike(track);
  if (!context.mounted) return;
  final state = ref.read(libraryControllerProvider);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        success
            ? (state.likedIds.contains(track.spotifyId)
                  ? 'Đã lưu vào bài hát yêu thích.'
                  : 'Đã bỏ lưu bài hát.')
            : state.failure?.message ?? 'Thư viện đang tải. Vui lòng thử lại.',
      ),
    ),
  );
}

class _PlaylistPicker extends ConsumerWidget {
  const _PlaylistPicker({required this.track});
  final Track track;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryControllerProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Thêm vào playlist',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (state.loading) const LinearProgressIndicator(),
            if (state.failure != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: FeedbackPanel(message: state.failure!.message),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton.icon(
                onPressed: state.busy || state.loading
                    ? null
                    : () async {
                        final playlist = await showCreatePlaylist(context);
                        if (playlist == null || !context.mounted) return;
                        final success = await ref
                            .read(libraryControllerProvider.notifier)
                            .add(playlist.id, track);
                        if (success && context.mounted) Navigator.pop(context);
                      },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo playlist mới'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: state.playlists.length,
                itemBuilder: (_, index) {
                  final playlist = state.playlists[index];
                  return ListTile(
                    title: Text(playlist.title),
                    subtitle: Text('${playlist.trackCount} bài hát'),
                    enabled: !state.busy && !state.loading,
                    onTap: () async {
                      final success = await ref
                          .read(libraryControllerProvider.notifier)
                          .add(playlist.id, track);
                      if (context.mounted && success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã thêm bài hát vào playlist.'),
                          ),
                        );
                      }
                    },
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

class LoadMessage extends StatelessWidget {
  const LoadMessage({
    super.key,
    required this.message,
    this.retry,
    this.retryLabel = 'Thử lại',
  });
  final String message;
  final String retryLabel;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.secondary),
        ),
        if (retry != null)
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(retryLabel),
          ),
      ],
    ),
  );
}

class GuestPrompt extends StatelessWidget {
  const GuestPrompt({
    super.key,
    required this.title,
    required this.message,
    required this.returnTo,
  });
  final String title, message, returnTo;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SectionEntrance(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 32,
                      color: AppColors.lavender,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Khách vãng lai',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.push(
                      Uri(
                        path: '/sign-in',
                        queryParameters: {'from': returnTo},
                      ).toString(),
                    ),
                    child: const Text('Đăng nhập'),
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

class TrackDownloadButton extends ConsumerWidget {
  const TrackDownloadButton({super.key, required this.track});
  final Track track;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(offlineControllerProvider);
    final ready = downloads.entries.any((e) => e.track.id == track.id);
    final active = downloads.busy && downloads.downloading == track.id;
    return IconButton(
      tooltip: ready
          ? 'Xem bản đã tải'
          : active
          ? 'Xem tiến độ tải'
          : 'Tải để nghe offline',
      onPressed: () => performTrackAction(
        context,
        ref,
        track,
        ready || active ? 'downloads' : 'download',
      ),
      icon: active
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              ready
                  ? Icons.download_done_rounded
                  : Icons.arrow_circle_down_outlined,
              color: ready ? AppColors.lavender : AppColors.secondary,
              size: 27,
            ),
    );
  }
}
