import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/feedback_panel.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import 'library_controller.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(
          sessionControllerProvider.select((s) => s.session?.user.id),
        ) ==
        null) {
      return const GuestPrompt(
        title: 'Thư viện',
        message: 'Đăng nhập để lưu bài hát yêu thích và tạo playlist của bạn.',
        returnTo: '/library',
      );
    }
    final state = ref.watch(libraryControllerProvider);
    final controller = ref.read(libraryControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thư viện'),
        actions: [
          IconButton(
            tooltip: 'Tạo playlist',
            onPressed: state.busy || state.loading
                ? null
                : () => showDialog<void>(
                    context: context,
                    builder: (_) => const _CreatePlaylist(),
                  ),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (state.loading) const LinearProgressIndicator(),
            if (state.failure != null)
              LoadMessage(
                message: state.failure!.message,
                retry: controller.load,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Playlist của bạn',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (!state.loading &&
                state.playlists.isEmpty &&
                state.failure == null)
              const LoadMessage(
                message:
                    'Chưa có playlist. Nhấn dấu + để tạo playlist đầu tiên.',
              ),
            for (final playlist in state.playlists)
              ListTile(
                leading: MusicArtwork(image: playlist.image),
                title: Text(playlist.title),
                subtitle: Text('${playlist.trackCount} bài hát'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/playlist/${segment(playlist.id)}'),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Text(
                'Bài hát yêu thích',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (!state.loading && state.tracks.isEmpty && state.failure == null)
              const LoadMessage(
                message: 'Các bài hát bạn lưu sẽ xuất hiện ở đây.',
              ),
            for (var i = 0; i < state.tracks.length; i++)
              TrackTile(track: state.tracks[i], queue: state.tracks, index: i),
            if (state.hasMore)
              Padding(
                padding: const EdgeInsets.all(20),
                child: OutlinedButton(
                  onPressed: state.loading || state.busy
                      ? null
                      : () => controller.load(more: true),
                  child: const Text('Xem thêm'),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _CreatePlaylist extends ConsumerStatefulWidget {
  const _CreatePlaylist();
  @override
  ConsumerState<_CreatePlaylist> createState() => _CreatePlaylistState();
}

class _CreatePlaylistState extends ConsumerState<_CreatePlaylist> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryControllerProvider);
    return AlertDialog(
      title: const Text('Tạo playlist'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Tên playlist'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nhập tên playlist.'
                    : null,
              ),
              const SizedBox(height: 12),
              const Text('Playlist mới chỉ hiển thị với bạn.'),
              if (state.failure != null)
                FeedbackPanel(message: state.failure!.message),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: state.busy
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  final success = await ref
                      .read(libraryControllerProvider.notifier)
                      .create(_name.text);
                  if (context.mounted && success) Navigator.pop(context);
                },
          child: Text(state.busy ? 'Đang tạo…' : 'Tạo playlist'),
        ),
      ],
    );
  }
}
