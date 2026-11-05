import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../offline/presentation/offline_controller.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/feedback_panel.dart';
import '../../../core/widgets/app_motion.dart';
import '../../auth/presentation/session_controller.dart';
import '../../library/presentation/library_controller.dart';
import '../../library/presentation/playlist_dialog.dart';
import '../../library/presentation/pending_track_action.dart';
import '../../player/presentation/player_controller.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog_models.dart';

class MusicArtwork extends ConsumerWidget {
  const MusicArtwork({
    super.key,
    this.image,
    this.size = 52,
    this.round = false,
    this.radius = 8,
  });
  final String? image;
  final double size;
  final bool round;
  final double radius;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = ref.watch(catalogRepositoryProvider).artwork(image);
    final placeholder = ColoredBox(
      color: AppColors.surfaceRaised,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.secondary,
          size: (size * .35).clamp(20, 64),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(round ? size / 2 : radius),
      child: SizedBox.square(
        dimension: size,
        child: uri == null
            ? placeholder
            : Image.network(
                uri.toString(),
                fit: BoxFit.cover,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .round()
                    .clamp(64, 1000),
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => placeholder,
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: MusicArtwork(image: track.image),
      title: Text(
        track.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: active ? const Color(0xFFB7A7FF) : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
      selectedTileColor: AppColors.primary.withValues(alpha: .07),
      trailing: TrackOptionsButton(track: track, remove: remove),
    );
  }
}

class TrackOptionsButton extends ConsumerWidget {
  const TrackOptionsButton({super.key, required this.track, this.remove});
  final Track track;
  final VoidCallback? remove;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(
      sessionControllerProvider.select((s) => s.session?.user.id),
    );
    final library = userId == null
        ? null
        : ref.watch(libraryControllerProvider);
    final downloads = ref.watch(offlineControllerProvider);
    final downloaded = downloads.entries.any((e) => e.track.id == track.id);
    return PopupMenuButton<String>(
      tooltip: 'Tùy chọn cho ${track.displayName}',
      onSelected: (action) => action == 'remove'
          ? remove?.call()
          : performTrackAction(context, ref, track, action),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'like',
          enabled:
              library == null ||
              (!library.loading && !library.busy && library.failure == null),
          child: Text(
            library?.likedIds.contains(track.spotifyId) == true
                ? 'Bỏ lưu yêu thích'
                : 'Lưu vào yêu thích',
          ),
        ),
        const PopupMenuItem(
          value: 'playlist',
          child: Text('Thêm vào playlist'),
        ),
        PopupMenuItem(
          value: downloaded || downloads.downloading == track.id
              ? 'downloads'
              : 'download',
          child: Text(
            downloaded
                ? 'Xem bản đã tải'
                : downloads.downloading == track.id
                ? 'Xem tiến độ tải'
                : 'Tải để nghe offline',
          ),
        ),
        const PopupMenuItem(value: 'queue', child: Text('Thêm vào hàng đợi')),
        const PopupMenuItem(value: 'next', child: Text('Phát tiếp theo')),
        const PopupMenuItem(value: 'share', child: Text('Chia sẻ bài hát')),
        if (remove != null)
          const PopupMenuItem(value: 'remove', child: Text('Bỏ khỏi playlist')),
        if (track.artistId != null)
          const PopupMenuItem(value: 'artist', child: Text('Xem nghệ sĩ')),
      ],
    );
  }
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
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          text: '${track.displayName} — ${track.artist}',
          title: 'Moodify',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa mở được bảng chia sẻ.')),
        );
      }
    }
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
    await showModalBottomSheet<void>(
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.surfaceRaised,
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 32,
                      color: AppColors.lavender,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Khách vãng lai',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
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
