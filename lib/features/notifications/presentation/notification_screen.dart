import '../../player/presentation/player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/formatters/display_date.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/app_sheets.dart';
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
      bottomNavigationBar: const MiniPlayer(),
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
        // Thân màn vào nhẹ một lần khi mở; đổi trạng thái loading/data không chạy lại.
        child: SectionEntrance(
          child: state.when(
            loading: () =>
                ListView(children: const [LinearProgressIndicator()]),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: items.isEmpty ? 1 : items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                if (items.isEmpty) {
                  return const LoadMessage(message: 'Bạn chưa có thông báo.');
                }
                final item = items[i];
                // Thẻ thông báo cùng ngôn ngữ Studio Dark với các màn khác.
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                      color: item.read
                          ? AppColors.borderSoft
                          : AppColors.primary.withValues(alpha: .35),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.read
                            ? AppColors.surfaceGlass
                            : AppColors.primary.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(AppRadii.xs),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Icon(
                        item.read
                            ? Icons.notifications_none_rounded
                            : Icons.notifications_active_rounded,
                        size: 20,
                        color: item.read
                            ? AppColors.secondary
                            : AppColors.lavender,
                      ),
                    ),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: item.read
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (!item.read)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Text(
                                displayDate(item.createdAt),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.secondary,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      if (!item.read) {
                        ref.read(inboxProvider.notifier).read(item.id);
                      }
                      showAppModalSheet<void>(
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
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: () {
                                        Navigator.pop(sheetContext);
                                        context.push(item.destination!);
                                      },
                                      child: const Text('Xem gói dịch vụ'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
