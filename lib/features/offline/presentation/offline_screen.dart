import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../player/presentation/player_controller.dart';
import '../../player/presentation/player_screen.dart';
import '../data/offline_repository.dart';
import 'offline_controller.dart';

class OfflineScreen extends ConsumerWidget {
  const OfflineScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(offlineUserProvider) == null) {
      return const GuestPrompt(
        title: 'Nhạc đã tải',
        message: 'Đăng nhập để tải nhạc theo quyền của gói dịch vụ.',
        returnTo: '/offline',
      );
    }
    final state = ref.watch(offlineControllerProvider);
    final onlineSession = ref.watch(sessionControllerProvider).session != null;
    final controller = ref.read(offlineControllerProvider.notifier);
    final queue = state.entries
        .where((e) => !e.expired)
        .map((e) => e.track)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhạc đã tải'),
        actions: [
          PopupMenuButton<String>(
            enabled: onlineSession && !state.busy,
            onSelected: (value) async {
              await ref.read(playerControllerProvider.notifier).clear();
              await controller.verify(renew: value == 'renew');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'verify', child: Text('Xác minh bản quyền')),
              PopupMenuItem(
                value: 'renew',
                child: Text('Gia hạn theo gói hiện tại'),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '${state.entries.length} bài trên thiết bị · ${(state.entries.fold<int>(0, (sum, e) => sum + e.fileSize) / 1024 / 1024).toStringAsFixed(1)} MB',
            ),
          ),
          if (!onlineSession)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Đang dùng bản quyền đã lưu trên thiết bị. Kết nối mạng để đồng bộ hoặc gia hạn.',
              ),
            ),
          if (state.busy)
            Padding(
              padding: const EdgeInsets.all(20),
              child: LinearProgressIndicator(
                value: state.downloading == null ? null : state.progress,
              ),
            ),
          if (state.failure != null)
            LoadMessage(
              message: state.failure!.message,
              retry: controller.load,
            ),
          if (state.entries.isEmpty && !state.busy)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.download_for_offline_outlined, size: 64),
                  const SizedBox(height: 20),
                  const Text(
                    'Tải nhạc từ menu bài hát để nghe khi mất mạng.',
                    textAlign: TextAlign.center,
                  ),
                  if (onlineSession)
                    TextButton(
                      onPressed: () => context.go('/search'),
                      child: const Text('Tìm bài hát'),
                    ),
                ],
              ),
            ),
          for (final entry in state.entries)
            ListTile(
              leading: MusicArtwork(image: entry.track.image),
              title: Text(entry.track.displayName),
              subtitle: Text(
                entry.expired
                    ? 'Hết hạn · Kết nối mạng để gia hạn'
                    : '${entry.track.artist}\nBản quyền đến ${entry.expiresAt.toLocal().toString().split('.').first}',
              ),
              isThreeLine: true,
              onTap: entry.expired || state.busy
                  ? null
                  : () => ref
                        .read(playerControllerProvider.notifier)
                        .select(
                          queue,
                          queue.indexWhere((t) => t.id == entry.track.id),
                          offline: true,
                        ),
              trailing: IconButton(
                tooltip: 'Xóa bản tải xuống',
                onPressed: !onlineSession || state.busy
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Xóa bản tải xuống?'),
                            content: Text(entry.track.displayName),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Giữ lại'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Xóa'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !context.mounted) return;
                        if (ref.read(playerControllerProvider).track?.id ==
                            entry.track.id) {
                          await ref
                              .read(playerControllerProvider.notifier)
                              .clear();
                        }
                        await controller.remove(entry.track.id);
                      },
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ),
        ],
      ),
    );
  }
}
