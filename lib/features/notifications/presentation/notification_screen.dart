import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/formatters/display_date.dart';
import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../data/notification_repository.dart';

final inboxProvider =
    StateNotifierProvider.autoDispose<
      InboxController,
      AsyncValue<List<InboxItem>>
    >((ref) {
      final user = ref.watch(
        sessionControllerProvider.select((s) => s.session?.user.id),
      );
      return InboxController(
        ref.watch(notificationRepositoryProvider),
        user != null,
      )..load();
    });

class InboxController extends StateNotifier<AsyncValue<List<InboxItem>>> {
  InboxController(this.repository, this.authenticated)
    : super(const AsyncLoading());
  final NotificationRepository repository;
  final bool authenticated;
  bool _busy = false;
  Future<void> load() async {
    if (!authenticated || _busy) return;
    _busy = true;
    try {
      final items = await repository.load();
      if (mounted) state = AsyncData(items);
    } catch (error, stack) {
      if (mounted) state = AsyncError(AppFailure.from(error), stack);
      return;
    } finally {
      _busy = false;
    }
  }

  Future<void> read(String? id) async {
    if (_busy || !authenticated) return;
    _busy = true;
    try {
      await repository.read(id);
    } catch (error, stack) {
      if (mounted) state = AsyncError(AppFailure.from(error), stack);
      return;
    } finally {
      _busy = false;
    }
    if (mounted) await load();
  }
}

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionControllerProvider).session == null) {
      return const GuestPrompt(
        title: 'Thông báo',
        message: 'Đăng nhập để xem thông báo của tài khoản.',
        returnTo: '/notifications',
      );
    }
    final state = ref.watch(inboxProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          if ((state.valueOrNull ?? []).any((e) => !e.read))
            IconButton(
              tooltip: 'Đọc tất cả',
              onPressed: () => ref.read(inboxProvider.notifier).read(null),
              icon: const Icon(Icons.done_all_rounded),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(inboxProvider.notifier).load(),
        child: state.when(
          loading: () => ListView(children: const [LinearProgressIndicator()]),
          error: (error, _) => ListView(
            children: [
              LoadMessage(
                message: AppFailure.from(error).message,
                retry: () => ref.read(inboxProvider.notifier).load(),
              ),
            ],
          ),
          data: (items) => ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.isEmpty ? 1 : items.length,
            separatorBuilder: (_, _) =>
                const Divider(indent: 20, endIndent: 20),
            itemBuilder: (_, i) {
              if (items.isEmpty) {
                return const LoadMessage(message: 'Bạn chưa có thông báo.');
              }
              final item = items[i];
              return ListTile(
                contentPadding: const EdgeInsets.all(20),
                isThreeLine: true,
                leading: Icon(
                  item.read
                      ? Icons.notifications_none_rounded
                      : Icons.notifications_active_outlined,
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: item.read ? FontWeight.w400 : FontWeight.w700,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.message),
                      const SizedBox(height: 8),
                      Text(
                        displayDate(item.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  if (!item.read) {
                    ref.read(inboxProvider.notifier).read(item.id);
                  }
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (sheetContext) => SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            SelectableText(item.message),
                            const SizedBox(height: 16),
                            Text(displayDate(item.createdAt)),
                            if (item.destination != null) ...[
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  context.push(item.destination!);
                                },
                                child: const Text('Xem gói dịch vụ'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
