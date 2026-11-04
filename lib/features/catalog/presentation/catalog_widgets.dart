import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/feedback_panel.dart';
import '../../auth/presentation/session_controller.dart';
import '../../library/presentation/library_controller.dart';
import '../../player/presentation/player_controller.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog_models.dart';

class MusicArtwork extends ConsumerWidget {
  const MusicArtwork({
    super.key,
    this.image,
    this.size = 52,
    this.round = false,
  });
  final String? image;
  final double size;
  final bool round;
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
      borderRadius: BorderRadius.circular(round ? size / 2 : 8),
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
  });
  final Track track;
  final List<Track> queue;
  final int index;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      playerControllerProvider.select((s) => s.track?.id == track.id),
    );
    final userId = ref.watch(
      sessionControllerProvider.select((s) => s.session?.user.id),
    );
    final library = userId == null
        ? null
        : ref.watch(libraryControllerProvider);
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
      onTap: () =>
          ref.read(playerControllerProvider.notifier).select(queue, index),
      trailing: PopupMenuButton<String>(
        tooltip: 'Tùy chọn cho ${track.displayName}',
        onSelected: (action) => _action(context, ref, action),
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
          if (track.artistId != null)
            const PopupMenuItem(value: 'artist', child: Text('Xem nghệ sĩ')),
        ],
      ),
    );
  }

  Future<void> _action(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
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
      context.push(
        Uri(
          path: '/sign-in',
          queryParameters: {'from': GoRouterState.of(context).uri.toString()},
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
              : state.failure?.message ??
                    'Thư viện đang tải. Vui lòng thử lại.',
        ),
      ),
    );
  }
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
            if (state.playlists.isEmpty && !state.loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bạn chưa có playlist. Tạo playlist trong Thư viện.',
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
  const LoadMessage({super.key, required this.message, this.retry});
  final String message;
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
            label: const Text('Thử lại'),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.library_music_outlined,
                size: 56,
                color: AppColors.secondary,
              ),
              const SizedBox(height: 24),
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
  );
}
