import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/display_date.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../player/presentation/player_controller.dart';
import '../../player/presentation/player_screen.dart';
import '../data/offline_repository.dart';
import '../data/offline_access_repository.dart';
import 'offline_controller.dart';

String offlineSize(int bytes) =>
    '${(bytes / 1024 / 1024).toStringAsFixed(1)} MiB';

class OfflineScreen extends ConsumerStatefulWidget {
  const OfflineScreen({super.key});
  @override
  ConsumerState<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends ConsumerState<OfflineScreen>
    with WidgetsBindingObserver {
  String query = '';
  bool expiredOnly = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(offlineAccessProvider);
    }
  }

  Future<void> _refresh() async {
    if (ref.read(offlineControllerProvider).busy) return;
    ref.invalidate(offlineAccessProvider);
    await ref.read(offlineControllerProvider.notifier).load();
  }

  Future<void> _verify({bool renew = false}) async {
    await ref.read(offlineControllerProvider.notifier).verify(renew: renew);
    if (!mounted) return;
    final player = ref.read(playerControllerProvider);
    final entries = ref.read(offlineControllerProvider).entries;
    if (player.offline &&
        !entries.any((e) => e.track.id == player.track?.id && !e.expired)) {
      await ref.read(playerControllerProvider.notifier).clear();
    }
  }

  Future<void> _remove(OfflineEntry entry) async {
    final user = ref.read(offlineUserProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa bản tải trên máy?'),
        content: Text(
          '${entry.track.displayName}\n\nGiải phóng ${offlineSize(entry.fileSize)}. Bài hát vẫn còn trong thư viện và playlist. Nếu đang nghe bản offline này, nhạc sẽ dừng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xóa bản tải'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        ref.read(offlineUserProvider) != user) {
      return;
    }
    final player = ref.read(playerControllerProvider);
    if (player.offline && player.track?.id == entry.track.id) {
      await ref.read(playerControllerProvider.notifier).clear();
    }
    if (!mounted || ref.read(offlineUserProvider) != user) return;
    await ref.read(offlineControllerProvider.notifier).remove(entry.track.id);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(offlineUserProvider) == null) {
      return const GuestPrompt(
        title: 'Nhạc đã tải',
        message: 'Đăng nhập để tải và quản lý nhạc offline trên thiết bị.',
        returnTo: '/offline',
      );
    }
    final state = ref.watch(offlineControllerProvider);
    final controller = ref.read(offlineControllerProvider.notifier);
    final online = ref.watch(sessionControllerProvider).session != null;
    final access = ref.watch(offlineAccessProvider);
    final ready = state.entries.where((e) => !e.expired).toList();
    final expired = state.entries.length - ready.length;
    final visible = state.entries
        .where(
          (e) =>
              (!expiredOnly || e.expired) &&
              '${e.track.displayName} ${e.track.artist}'.toLowerCase().contains(
                query.toLowerCase().trim(),
              ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhạc đã tải'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/library'),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới trạng thái',
            onPressed: state.busy ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Trên thiết bị này',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bản tải chỉ sẵn sàng nghe sau khi lưu và xác minh quyền.',
                      style: TextStyle(color: AppColors.secondary),
                    ),
                    const SizedBox(height: 20),
                    if (state.track != null) ...[
                      Text(
                        state.busy
                            ? 'Đang xử lý'
                            : state.failure != null
                            ? 'Cần xử lý'
                            : 'Tác vụ gần đây',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _TaskPanel(
                        state: state,
                        online: online,
                        retry: () => controller.download(state.track!),
                        cancel: controller.cancel,
                        dismiss: controller.clearTask,
                      ),
                      const SizedBox(height: 20),
                    ],
                    LayoutBuilder(
                      builder: (context, box) => Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _StorageStat(
                            width: (box.maxWidth - 12) / 2,
                            value: '${state.entries.length}',
                            label: 'Bài trên máy',
                            detail: expired > 0 ? '$expired hết hạn' : null,
                          ),
                          _StorageStat(
                            width: (box.maxWidth - 12) / 2,
                            value: offlineSize(
                              state.entries.fold<int>(
                                0,
                                (sum, e) => sum + e.fileSize,
                              ),
                            ),
                            label: 'Dung lượng bản tải',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _AccessPanel(
                      access: access,
                      online: online,
                      busy: state.busy,
                      retry: () => ref.invalidate(offlineAccessProvider),
                    ),
                    if (state.pendingCleanup > 0) ...[
                      const SizedBox(height: 12),
                      _Notice(
                        icon: Icons.sync_rounded,
                        text:
                            '${state.pendingCleanup} thay đổi bản tải chờ đồng bộ hạn mức với máy chủ.',
                        action: TextButton(
                          onPressed: online && !state.busy
                              ? () => _verify()
                              : null,
                          child: const Text('Đồng bộ ngay'),
                        ),
                      ),
                    ],
                    if (state.track == null) ...[
                      if (state.busy)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: LinearProgressIndicator(),
                        ),
                      if (state.failure != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _Notice(
                            icon: Icons.error_outline,
                            text: state.failure!.message,
                            action: TextButton(
                              onPressed: state.busy ? null : _refresh,
                              child: const Text('Tải lại danh sách'),
                            ),
                          ),
                        ),
                      if (state.notice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _Notice(
                            icon: Icons.check_circle_outline,
                            text: state.notice!,
                          ),
                        ),
                    ],
                    const SizedBox(height: 28),
                    Text(
                      'Thư viện offline',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${ready.length} bài sẵn sàng nghe${expired > 0 ? ' · $expired bài hết hạn' : ''}',
                      style: const TextStyle(color: AppColors.secondary),
                    ),
                    if (ready.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: FilledButton.icon(
                          onPressed: () => ref
                              .read(playerControllerProvider.notifier)
                              .select(
                                ready.map((e) => e.track).toList(),
                                0,
                                offline: true,
                                source: 'LIBRARY',
                              ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Phát các bài sẵn sàng'),
                        ),
                      ),
                    if (state.entries.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (value) => setState(() => query = value),
                        decoration: const InputDecoration(
                          labelText: 'Tìm trong bản tải',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      if (expired > 0)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: expiredOnly,
                          onChanged: (value) =>
                              setState(() => expiredOnly = value ?? false),
                          title: const Text('Chỉ hiện bài hết hạn'),
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: online && !state.busy
                                ? () => _verify()
                                : null,
                            icon: const Icon(Icons.verified_outlined),
                            label: const Text('Xác minh quyền'),
                          ),
                          if (expired > 0)
                            TextButton.icon(
                              onPressed: online && !state.busy
                                  ? () => _verify(renew: true)
                                  : null,
                              icon: const Icon(Icons.update_rounded),
                              label: const Text('Gia hạn theo gói'),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (state.entries.isEmpty && !state.busy)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: _EmptyDownloads(
                    allowed: access.hasError || access.isLoading
                        ? null
                        : access.valueOrNull?.allowed,
                    online: online,
                  ),
                ),
              ),
            if (state.entries.isNotEmpty && visible.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Không có bản tải phù hợp bộ lọc.'),
                ),
              ),
            SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (_, i) {
                final entry = visible[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: MusicArtwork(image: entry.track.image, size: 56),
                  title: Text(
                    entry.track.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${entry.track.artist}\n${offlineSize(entry.fileSize)} · ${entry.expired ? 'Hết hạn' : 'Sẵn sàng nghe'}\n${entry.expired ? 'Cần gia hạn' : 'Quyền đến'} ${displayDate(entry.expiresAt.toLocal().toIso8601String())}',
                  ),
                  onTap: entry.expired
                      ? null
                      : () => ref
                            .read(playerControllerProvider.notifier)
                            .select(
                              ready.map((e) => e.track).toList(),
                              ready.indexOf(entry),
                              offline: true,
                              source: 'LIBRARY',
                            ),
                  trailing: IconButton(
                    tooltip: 'Xóa bản tải của ${entry.track.displayName}',
                    onPressed: state.busy ? null : () => _remove(entry),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _StorageStat extends StatelessWidget {
  const _StorageStat({
    required this.width,
    required this.value,
    required this.label,
    this.detail,
  });
  final double width;
  final String value, label;
  final String? detail;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(label),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              style: const TextStyle(color: AppColors.secondary, fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22, color: AppColors.lavender),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(text), ?action],
        ),
      ),
    ],
  );
}

class _AccessPanel extends StatelessWidget {
  const _AccessPanel({
    required this.access,
    required this.online,
    required this.busy,
    required this.retry,
  });
  final AsyncValue<OfflineAccess?> access;
  final bool online, busy;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) {
    if (!online) {
      return const _Notice(
        icon: Icons.wifi_off_rounded,
        text:
            'Đang dùng bản quyền lưu trên máy. Kết nối và khôi phục phiên để tải thêm hoặc gia hạn.',
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: access.when(
        skipLoadingOnRefresh: false,
        loading: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đang kiểm tra quyền tải và hạn mức…'),
            SizedBox(height: 12),
            LinearProgressIndicator(),
          ],
        ),
        error: (e, _) => _Notice(
          icon: Icons.cloud_off_outlined,
          text: 'Chưa kiểm tra được quyền tải. ${AppFailure.from(e).message}',
          action: TextButton(
            onPressed: busy ? null : retry,
            child: const Text('Thử kiểm tra lại'),
          ),
        ),
        data: (value) => value == null
            ? const Text('Chưa có thông tin quyền tải.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        value.allowed
                            ? Icons.offline_pin_outlined
                            : Icons.lock_outline,
                        color: AppColors.lavender,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          value.packageName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    !value.allowed
                        ? 'Gói hiện tại chưa cho phép tải nhạc offline.'
                        : value.full
                        ? 'Hạn mức tải trên máy đã đầy.'
                        : 'Có thể tải nhạc để nghe khi mất mạng.',
                  ),
                  if (value.maximum > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Hạn mức trên thiết bị: ${value.used} / ${value.maximum} bài',
                      style: const TextStyle(color: AppColors.secondary),
                    ),
                  ],
                  if (value.maximum > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(
                        value: (value.used / value.maximum).clamp(0, 1),
                      ),
                    ),
                  if (value.expiresAt != null)
                    Text(
                      'Gói có hiệu lực đến ${displayDate(value.expiresAt)}',
                      style: const TextStyle(color: AppColors.secondary),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Kiểm tra lúc ${displayDate(value.checkedAt.toIso8601String())}',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 12,
                    ),
                  ),
                  if (!value.allowed)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton(
                        onPressed: () => context.push('/subscriptions'),
                        child: const Text('Xem gói có quyền offline'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _TaskPanel extends StatelessWidget {
  const _TaskPanel({
    required this.state,
    required this.online,
    required this.retry,
    required this.cancel,
    required this.dismiss,
  });
  final OfflineState state;
  final bool online;
  final VoidCallback retry, cancel, dismiss;
  @override
  Widget build(BuildContext context) {
    final update = state.update;
    final phase = switch (update?.phase) {
      DownloadPhase.receiving => 'Đang tải âm thanh',
      DownloadPhase.encrypting => 'Đang lưu bản tải an toàn',
      DownloadPhase.confirming => 'Đang xác nhận với máy chủ',
      DownloadPhase.verifying => 'Đang xác minh quyền nghe',
      _ => 'Đang kiểm tra và chuẩn bị tải',
    };
    final blocked = state.failure?.code == 'OFFLINE_FORBIDDEN';
    final limit = state.failure?.code == 'DOWNLOAD_LIMIT';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: state.failure == null
              ? AppColors.border
              : AppColors.error.withValues(alpha: .5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MusicArtwork(image: state.track!.image, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.track!.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      state.track!.artist,
                      style: const TextStyle(color: AppColors.secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.busy) ...[
            Text(phase),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: update?.phase == DownloadPhase.receiving
                  ? update?.fraction
                  : null,
            ),
            if (update?.phase == DownloadPhase.receiving)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${offlineSize(update!.received)}${update.total == null ? ' đã nhận' : ' / ${offlineSize(update.total!)} · ${(update.fraction! * 100).floor()}%'}',
                ),
              ),
            TextButton(onPressed: cancel, child: const Text('Hủy tải')),
          ] else ...[
            Text(
              state.failure?.message ?? state.notice ?? 'Tác vụ đã dừng.',
              style: TextStyle(
                color: state.failure != null
                    ? AppColors.error
                    : AppColors.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (online &&
                    !blocked &&
                    !limit &&
                    !state.entries.any(
                      (entry) =>
                          entry.track.id == state.track!.id && !entry.expired,
                    ))
                  TextButton(
                    onPressed: retry,
                    child: const Text('Thử tải lại bài này'),
                  ),
                if (blocked)
                  TextButton(
                    onPressed: () => context.push('/subscriptions'),
                    child: const Text('Kiểm tra gói dịch vụ'),
                  ),
                if (blocked)
                  TextButton(
                    onPressed: () => context.push('/devices'),
                    child: const Text('Kiểm tra thiết bị'),
                  ),
                TextButton(
                  onPressed: dismiss,
                  child: const Text('Đóng tác vụ'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({required this.allowed, required this.online});
  final bool? allowed;
  final bool online;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.library_music_outlined,
          size: 36,
          color: AppColors.secondary,
        ),
        const SizedBox(height: 16),
        Text(
          'Chưa có bản tải trên máy',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          !online
              ? 'Các bài đã tải hợp lệ sẽ xuất hiện ở đây để nghe khi mất mạng.'
              : allowed == null
              ? 'Mở menu của bài hát để tải sau khi app kiểm tra được quyền offline. Các bản tải hợp lệ sẽ xuất hiện ở đây.'
              : allowed!
              ? 'Mở menu của bài hát và chọn Tải để nghe offline. Bài tải xong sẽ xuất hiện tại đây.'
              : 'Bạn vẫn có thể nghe nhạc trực tuyến. Để lưu nhạc trên thiết bị, cần gói có quyền offline.',
          style: const TextStyle(color: AppColors.secondary),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => context.go('/search'),
          icon: const Icon(Icons.search),
          label: Text(allowed == true ? 'Tìm bài để tải' : 'Tìm nhạc để nghe'),
        ),
      ],
    ),
  );
}
