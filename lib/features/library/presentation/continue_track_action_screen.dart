import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import 'pending_track_action.dart';
import 'library_controller.dart';

class ContinueTrackActionScreen extends ConsumerStatefulWidget {
  const ContinueTrackActionScreen({super.key});
  @override
  ConsumerState<ContinueTrackActionScreen> createState() =>
      _ContinueTrackActionScreenState();
}

class _ContinueTrackActionScreenState
    extends ConsumerState<ContinueTrackActionScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingTrackActionProvider);
    final signedIn = ref.watch(sessionControllerProvider).session != null;
    final library = signedIn && pending?.action == 'like'
        ? ref.watch(libraryControllerProvider)
        : null;
    final alreadyLiked =
        pending != null &&
        library?.likedIds.contains(pending.track.spotifyId) == true;
    final valid = pending != null && pending.expiresAt.isAfter(DateTime.now());
    final label = switch (pending?.action) {
      'download' => 'Tiếp tục tải bài này',
      'playlist' => 'Chọn playlist',
      _ => 'Tiếp tục lưu yêu thích',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Tiếp tục thao tác')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!valid)
              const Text(
                'Thao tác trước đó đã hết hạn. Hãy chọn lại bài hát từ thư viện hoặc tìm kiếm.',
              )
            else ...[
              Center(
                child: MusicArtwork(image: pending.track.image, size: 160),
              ),
              const SizedBox(height: 20),
              Text(
                pending.track.displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(pending.track.artist),
              const SizedBox(height: 24),
              if (library?.failure != null)
                LoadMessage(
                  message: library!.failure!.message,
                  retry: () =>
                      ref.read(libraryControllerProvider.notifier).load(),
                ),
              FilledButton(
                onPressed:
                    busy || library?.loading == true || library?.failure != null
                    ? null
                    : () async {
                        if (!signedIn) {
                          context.push('/sign-in?from=%2Fcontinue-action');
                          return;
                        }
                        if (!pending.expiresAt.isAfter(DateTime.now())) {
                          setState(() {});
                          return;
                        }
                        if (alreadyLiked) {
                          ref.read(pendingTrackActionProvider.notifier).state =
                              null;
                          context.go(pending.returnTo);
                          return;
                        }
                        final user = ref
                            .read(sessionControllerProvider)
                            .session
                            ?.user
                            .id;
                        setState(() => busy = true);
                        await performTrackAction(
                          context,
                          ref,
                          pending.track,
                          pending.action,
                        );
                        if (context.mounted &&
                            ref
                                    .read(sessionControllerProvider)
                                    .session
                                    ?.user
                                    .id ==
                                user) {
                          ref.read(pendingTrackActionProvider.notifier).state =
                              null;
                          if (pending.action != 'download') {
                            context.go(pending.returnTo);
                          } else {
                            setState(() => busy = false);
                          }
                        }
                      },
                child: Text(
                  alreadyLiked
                      ? 'Bài đã có trong yêu thích · Quay lại'
                      : signedIn
                      ? label
                      : 'Đăng nhập để tiếp tục',
                ),
              ),
            ],
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      final target = pending?.returnTo ?? '/home';
                      ref.read(pendingTrackActionProvider.notifier).state =
                          null;
                      context.go(target);
                    },
              child: const Text('Về trang trước'),
            ),
          ],
        ),
      ),
    );
  }
}
