import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/display_date.dart';
import '../../../core/widgets/app_motion.dart';
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
    final totalBytes = state.entries.fold<int>(0, (sum, e) => sum + e.fileSize);
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!online)
                      const _Notice(
                        icon: Icons.wifi_off_rounded,
                        text:
                            'Đang dùng bản quyền lưu trên máy. Kết nối và khôi phục phiên để tải thêm hoặc gia hạn.',
                      ),
                    // Tác vụ tải đặt lên đầu: đây là thông tin đang thay đổi.
                    if (state.track != null) ...[
                      if (!online) const SizedBox(height: 20),
                      Text(
                        state.busy
                            ? 'Đang xử lý'
                            : state.failure != null
                            ? 'Cần xử lý'
                            : 'Tác vụ gần đây',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SectionEntrance(
                        child: _TaskCard(
                          state: state,
                          online: online,
                          retry: () => controller.download(state.track!),
                          cancel: controller.cancel,
                          dismiss: controller.clearTask,
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
                          padding: const EdgeInsets.only(top: 20),
                          child: _Notice(
                            icon: Icons.error_outline_rounded,
                            color: AppColors.error,
                            text: state.failure!.message,
                            action: TextButton(
                              onPressed: state.busy ? null : _refresh,
                              child: const Text('Tải lại danh sách'),
                            ),
                          ),
                        ),
                      if (state.notice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: _Notice(
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.lavender,
                            text: state.notice!,
                          ),
                        ),
                    ],
                    const SizedBox(height: 28),
                    SectionEntrance(
                      order: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Quyền tải offline',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Bản tải chỉ sẵn sàng nghe sau khi lưu và xác minh quyền.',
                            style: TextStyle(color: AppColors.secondary),
                          ),
                          const SizedBox(height: 12),
                          _AccessCard(
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SectionEntrance(
                      order: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Bản tải trên máy',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          // Một dòng số thật thay cho các thẻ số liệu.
                          Text.rich(
                            TextSpan(
                              style: Theme.of(context).textTheme.bodyLarge,
                              children: [
                                TextSpan(text: '${ready.length} bài sẵn sàng'),
                                TextSpan(
                                  text: ' · ${offlineSize(totalBytes)} đã tải',
                                  style: const TextStyle(
                                    color: AppColors.secondary,
                                  ),
                                ),
                                if (expired > 0)
                                  TextSpan(
                                    text: ' · $expired hết hạn',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (ready.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
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
                          ],
                          if (state.entries.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            TextField(
                              onChanged: (value) =>
                                  setState(() => query = value),
                              decoration: const InputDecoration(
                                labelText: 'Tìm trong bản tải',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (expired > 0)
                                  FilterChip(
                                    selected: expiredOnly,
                                    onSelected: (value) =>
                                        setState(() => expiredOnly = value),
                                    label: const Text('Chỉ hiện bài hết hạn'),
                                  ),
                                TextButton.icon(
                                  onPressed: online && !state.busy
                                      ? () => _verify()
                                      : null,
                                  icon: const Icon(
                                    Icons.verified_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Xác minh quyền'),
                                ),
                                if (expired > 0)
                                  TextButton.icon(
                                    onPressed: online && !state.busy
                                        ? () => _verify(renew: true)
                                        : null,
                                    icon: const Icon(
                                      Icons.update_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Gia hạn theo gói'),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (state.entries.isEmpty && !state.busy)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                  padding: EdgeInsets.all(20),
                  child: Text('Không có bản tải phù hợp bộ lọc.'),
                ),
              ),
            if (visible.isNotEmpty)
              SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (_, i) {
                  final entry = visible[i];
                  return Column(
                    children: [
                      _DownloadRow(
                        entry: entry,
                        onPlay: () => ref
                            .read(playerControllerProvider.notifier)
                            .select(
                              ready.map((e) => e.track).toList(),
                              ready.indexOf(entry),
                              offline: true,
                              source: 'LIBRARY',
                            ),
                        onRemove: state.busy ? null : () => _remove(entry),
                      ),
                      if (i < visible.length - 1)
                        const Divider(height: 1, indent: 88),
                    ],
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

/// Hệ container duy nhất của màn: nền surface, viền hairline, radius 12.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.borderColor});
  final Widget child;
  final Color? borderColor;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor ?? AppColors.border),
    ),
    child: child,
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    this.color,
    this.action,
  });
  final IconData icon;
  final String text;
  final Color? color;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppColors.secondary;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(text), ?action],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
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
    return _Card(
      borderColor: state.failure == null
          ? null
          : AppColors.error.withValues(alpha: .5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MusicArtwork(image: state.track!.image, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.track!.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.track!.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.busy) ...[
            Text(
              phase,
              style: const TextStyle(
                color: AppColors.lavender,
                fontWeight: FontWeight.w600,
              ),
            ),
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
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: cancel,
                child: const Text('Hủy tải'),
              ),
            ),
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
              runSpacing: 4,
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

class _AccessCard extends StatelessWidget {
  const _AccessCard({
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
        icon: Icons.cloud_off_outlined,
        text:
            'Chưa kiểm tra được quyền tải khi offline. Kết nối lại để xem hạn mức và gói hiện tại.',
      );
    }
    return _Card(
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
                    children: [
                      Icon(
                        value.allowed
                            ? Icons.offline_pin_outlined
                            : Icons.lock_outline,
                        size: 20,
                        color: value.allowed
                            ? AppColors.lavender
                            : AppColors.secondary,
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
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(
                        value: (value.used / value.maximum).clamp(0, 1),
                      ),
                    ),
                  ],
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
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () => context.push('/subscriptions'),
                          child: const Text('Xem gói có quyền offline'),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({
    required this.entry,
    required this.onPlay,
    required this.onRemove,
  });
  final OfflineEntry entry;
  final VoidCallback onPlay;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) {
    final expired = entry.expired;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: MusicArtwork(image: entry.track.image, size: 52),
      title: Text(
        entry.track.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '${entry.track.artist} · ${offlineSize(entry.fileSize)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.secondary),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (expired) ...[
                const Icon(
                  Icons.history_rounded,
                  size: 13,
                  color: AppColors.error,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  expired
                      ? 'Hết hạn · cần gia hạn'
                      : 'Quyền đến ${displayDate(entry.expiresAt.toLocal().toIso8601String())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: expired ? AppColors.error : AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: expired ? null : onPlay,
      trailing: IconButton(
        tooltip: 'Xóa bản tải của ${entry.track.displayName}',
        onPressed: onRemove,
        icon: const Icon(Icons.delete_outline_rounded),
      ),
      // onRemove null khi đang bận — nút xóa hiển thị nhưng không tác động.
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({required this.allowed, required this.online});
  final bool? allowed;
  final bool online;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.library_music_outlined,
            size: 24,
            color: AppColors.secondary,
          ),
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
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => context.go('/search'),
          icon: const Icon(Icons.search, size: 18),
          label: Text(allowed == true ? 'Tìm bài để tải' : 'Tìm nhạc để nghe'),
        ),
      ],
    ),
  );
}
