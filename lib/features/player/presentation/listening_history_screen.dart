import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/display_date.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import 'player_controller.dart';
import 'player_screen.dart';

final listeningHistoryProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, page) async {
      final user = ref.watch(
        sessionControllerProvider.select((s) => s.session?.user.id),
      );
      if (user == null) {
        throw const AppFailure('Đăng nhập để xem lịch sử nghe.');
      }
      final data = objectJson(
        (await ref
                .watch(apiDioProvider)
                .get<Object?>(
                  'analytics/my-history',
                  queryParameters: {'page': page, 'size': 20},
                ))
            .data,
      );
      final items = data['items'];
      if (items is! List) throw const FormatException('Invalid history');
      for (final raw in items) {
        requiredText(objectJson(raw), 'id');
      }
      return data;
    });

class ListeningHistoryScreen extends ConsumerStatefulWidget {
  const ListeningHistoryScreen({super.key});
  @override
  ConsumerState<ListeningHistoryScreen> createState() =>
      _ListeningHistoryScreenState();
}

class _ListeningHistoryScreenState
    extends ConsumerState<ListeningHistoryScreen> {
  int page = 0;
  bool busy = false;
  AppFailure? failure;
  Future<void> _remove(String? id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          id == null ? 'Xóa toàn bộ lịch sử nghe?' : 'Xóa mục lịch sử này?',
        ),
        content: const Text(
          'Thao tác này xóa lịch sử trên tài khoản. Bài hát và playlist vẫn được giữ.',
        ),
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
    if (!mounted || confirmed != true) return;
    final user = ref.read(sessionControllerProvider).session?.user.id;
    final dio = ref.read(apiDioProvider);
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final result = objectJson(
        (await dio.delete<Object?>(
          'analytics/my-history${id == null ? '' : '/${segment(id)}'}',
        )).data,
      );
      if (result['success'] != true) {
        throw const AppFailure(
          'Chưa xóa được mục lịch sử. Hãy tải lại để kiểm tra.',
        );
      }
      if (!mounted ||
          ref.read(sessionControllerProvider).session?.user.id != user) {
        return;
      }
      ref.invalidate(listeningHistoryProvider);
      setState(() => page = 0);
    } catch (error) {
      if (mounted &&
          ref.read(sessionControllerProvider).session?.user.id == user) {
        setState(() => failure = AppFailure.from(error));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionControllerProvider).session == null) {
      return const GuestPrompt(
        title: 'Lịch sử nghe',
        message: 'Đăng nhập để xem các bài đã nghe trên tài khoản.',
        returnTo: '/history',
      );
    }
    final history = ref.watch(listeningHistoryProvider(page));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử nghe'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: busy
                ? null
                : () => ref.invalidate(listeningHistoryProvider(page)),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Xóa toàn bộ lịch sử',
            onPressed: busy ? null : () => _remove(null),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LoadMessage(
          message: AppFailure.from(e).message,
          retry: () => ref.invalidate(listeningHistoryProvider(page)),
        ),
        data: (data) {
          final raw = data['items'];
          if (raw is! List) {
            return const LoadMessage(
              message: 'Dữ liệu lịch sử chưa đúng định dạng.',
            );
          }
          final items = raw.map(objectJson).toList();
          return ListView(
            children: [
              if (busy) const LinearProgressIndicator(),
              if (failure != null) LoadMessage(message: failure!.message),
              if (items.isEmpty)
                const LoadMessage(
                  message: 'Chưa có lượt nghe trong trang lịch sử này.',
                ),
              for (final item in items)
                ListTile(
                  leading: MusicArtwork(
                    image: optionalText(item['audioUrl'])?.isNotEmpty == true
                        ? optionalText(item['coverUrl'])
                        : null,
                  ),
                  title: Text(
                    optionalText(item['audioUrl'])?.isNotEmpty == true
                        ? (optionalText(item['title']) ?? 'Chưa có tên bài hát')
                        : 'Chưa nhận diện được bài hát trong lịch sử',
                  ),
                  subtitle: Text(
                    '${optionalText(item['audioUrl'])?.isNotEmpty == true ? (optionalText(item['artist']) ?? '') : 'Máy chủ chưa cung cấp đủ thông tin bản thu'}\n${displayDate(optionalText(item['startedAt']))}',
                  ),
                  isThreeLine: true,
                  onTap:
                      busy ||
                          optionalText(item['audioUrl'])?.isNotEmpty != true ||
                          optionalText(item['trackId']) == null
                      ? null
                      : () => ref
                            .read(playerControllerProvider.notifier)
                            .select(
                              [
                                Track(
                                  id: item['trackId'].toString(),
                                  spotifyId:
                                      optionalText(item['spotifyId']) ??
                                      item['trackId'].toString(),
                                  name:
                                      optionalText(item['title']) ?? 'Bài hát',
                                  artist:
                                      optionalText(item['artist']) ??
                                      'Chưa rõ nghệ sĩ',
                                ),
                              ],
                              0,
                              source: 'LIBRARY',
                            ),
                  trailing: IconButton(
                    tooltip: 'Xóa mục lịch sử',
                    onPressed: busy
                        ? null
                        : () => _remove(requiredText(item, 'id')),
                    icon: const Icon(Icons.close),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: busy || page == 0
                          ? null
                          : () => setState(() => page--),
                      child: const Text('Trang trước'),
                    ),
                    Text('Trang ${page + 1}'),
                    TextButton(
                      onPressed:
                          busy ||
                              page + 1 >=
                                  ((data['totalPages'] as num?)?.toInt() ?? 0)
                          ? null
                          : () => setState(() => page++),
                      child: const Text('Trang sau'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
