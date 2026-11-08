import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/display_date.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/studio_banners.dart';
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
        edgeOffset: 8,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tác vụ tải đặt lên đầu: đây là thông tin đang thay đổi.
                    if (state.track != null) ...[
                      _SectionHeading(
                        state.busy
                            ? 'Đang xử lý'
                            : state.failure != null
                            ? 'Cần xử lý'
                            : 'Tác vụ gần đây',
                      ),
                      _TaskCard(
                        state: state,
                        online: online,
                        retry: () => controller.download(state.track!),
                        cancel: controller.cancel,
                        dismiss: controller.clearTask,
                      ),
                    ],
                    if (state.track == null) ...[
                      if (state.busy)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: _RoundedProgress(),
                        ),
                      if (state.failure != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
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
                          padding: const EdgeInsets.only(top: 16),
                          child: _Notice(
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.lavender,
                            text: state.notice!,
                          ),
                        ),
                    ],
                    _SectionHeading('Quyền tải offline'),
                    SectionEntrance(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AccessCard(
                            access: access,
                            online: online,
                            busy: state.busy,
                            retry: () => ref.invalidate(offlineAccessProvider),
                          ),
                          if (state.pendingCleanup > 0) ...[
                            const SizedBox(height: 10),
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
                    _SectionHeading('Bản tải trên máy'),
                    // Khối số thật: số lớn + nhãn, chip hết hạn bên phải.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '${ready.length}',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(height: 1),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'bài sẵn sàng nghe',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${offlineSize(totalBytes)} đã tải${expired > 0 ? ' · $expired hết hạn' : ''}',
                                  style: const TextStyle(
                                    color: AppColors.secondary,
                                    fontSize: 12,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (expired > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$expired cần gia hạn',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SectionEntrance(
                      order: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (ready.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
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
                                  OutlinedButton.icon(
                                    onPressed: () => ref
                                        .read(playerControllerProvider.notifier)
                                        .playCollection(
                                          ready.map((e) => e.track).toList(),
                                          shuffled: true,
                                          offline: true,
                                          source: 'LIBRARY',
                                        ),
                                    icon: const Icon(
                                      Icons.shuffle_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Trộn bài'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (state.entries.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: TextField(
                                onChanged: (value) =>
                                    setState(() => query = value),
                                decoration: const InputDecoration(
                                  labelText: 'Tìm trong bản tải',
                                  prefixIcon: Icon(Icons.search_rounded),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (expired > 0)
                                    FilterChip(
                                      selected: expiredOnly,
                                      onSelected: (value) =>
                                          setState(() => expiredOnly = value),
                                      showCheckmark: false,
                                      label: const Text('Chỉ hiện bài hết hạn'),
                                      labelStyle: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: expiredOnly
                                            ? AppColors.text
                                            : AppColors.secondary,
                                      ),
                                      shape: const StadiumBorder(
                                        side: BorderSide(
                                          color: AppColors.borderSoft,
                                        ),
                                      ),
                                      backgroundColor: AppColors.surfaceRaised,
                                      selectedColor: AppColors.primary
                                          .withValues(alpha: .22),
                                      side: const BorderSide(
                                        color: AppColors.borderSoft,
                                      ),
                                    ),
                                  TextButton.icon(
                                    onPressed: online && !state.busy
                                        ? () => _verify()
                                        : null,
                                    icon: const Icon(
                                      Icons.verified_outlined,
                                      size: 17,
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
                                        size: 17,
                                      ),
                                      label: const Text('Gia hạn theo gói'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            if (state.entries.isEmpty && !state.busy)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final entry = visible[i];
                    return _DownloadRow(
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
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

/// Heading section theo ngôn ngữ Studio Dark của Home: thanh nhấn trắng
/// 3.5×18 + tiêu đề titleLarge.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
    child: Row(
      children: [
        Container(
          width: 3.5,
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    ),
  );
}

/// Thẻ chuẩn Studio Dark: nền surfaceRaised, viền hairline borderSoft,
/// radius lớn theo AppRadii.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.borderColor});
  final Widget child;
  final Color? borderColor;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      border: Border.all(color: borderColor ?? AppColors.borderSoft),
    ),
    child: child,
  );
}

/// Thanh tiến độ bo tròn dùng chung cho màn.
class _RoundedProgress extends StatelessWidget {
  const _RoundedProgress({this.value});
  final double? value;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: LinearProgressIndicator(
      value: value,
      minHeight: 6,
      backgroundColor: AppColors.surfaceGlass,
      color: AppColors.primary,
    ),
  );
}

/// Notice dạng hàng phẳng: icon + chữ + hành động, có liveRegion cho
/// screen reader.
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
          Icon(icon, size: 19, color: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.secondary,
                  ),
                ),
                ?action,
              ],
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
          : AppColors.error.withValues(alpha: .45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MusicArtwork(image: state.track!.image, size: 56, radius: 12),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.track!.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.track!.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.busy) ...[
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    phase,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RoundedProgress(
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
                    fontSize: 12.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: cancel,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                ),
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
                fontSize: 13,
                height: 1.5,
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
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                  ),
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
            _RoundedProgress(),
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
                      // Icon trong khối kính nhỏ — cùng ngôn ngữ thẻ thiết bị.
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: value.allowed
                              ? AppColors.primary.withValues(alpha: .14)
                              : AppColors.surfaceGlass,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: Icon(
                          value.allowed
                              ? Icons.offline_pin_rounded
                              : Icons.lock_outline_rounded,
                          size: 20,
                          color: value.allowed
                              ? AppColors.lavender
                              : AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value.packageName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              !value.allowed
                                  ? 'Gói hiện tại chưa cho phép tải nhạc offline.'
                                  : value.full
                                  ? 'Hạn mức tải trên máy đã đầy.'
                                  : 'Có thể tải nhạc để nghe khi mất mạng.',
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (value.maximum > 0) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _RoundedProgress(
                            value: (value.used / value.maximum).clamp(0, 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${value.used}/${value.maximum}',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Hạn mức tải trên thiết bị này',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Gói có hiệu lực đến ${value.expiresAt == null ? '—' : displayDate(value.expiresAt)}'
                    ' · Kiểm tra lúc ${displayDate(value.checkedAt.toIso8601String())}',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 11.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (!value.allowed)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.push('/subscriptions'),
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            side: const BorderSide(color: AppColors.borderSoft),
                          ),
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

/// Hàng bản tải — thẻ nhỏ cùng ngôn ngữ với các hàng playlist/thiết bị.
class _DownloadRow extends ConsumerWidget {
  const _DownloadRow({
    required this.entry,
    required this.onPlay,
    required this.onRemove,
  });
  final OfflineEntry entry;
  final VoidCallback onPlay;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expired = entry.expired;
    // Trạng thái đang phát lấy từ player thật, không suy đoán.
    final playing = ref.watch(
      playerControllerProvider.select(
        (s) => s.offline && s.track?.id == entry.track.id,
      ),
    );
    // Đếm ngược từ expiresAt của server; chỉ hiện khi gần hết hạn.
    final daysLeft = expired
        ? null
        : entry.expiresAt.difference(DateTime.now()).inDays;
    final soon = daysLeft != null && daysLeft >= 0 && daysLeft <= 3;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: playing ? AppColors.surfaceRaised : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: expired
                ? AppColors.error.withValues(alpha: .28)
                : playing
                ? AppColors.primary.withValues(alpha: .4)
                : AppColors.borderSoft,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          onTap: expired ? null : onPlay,
          leading: MusicArtwork(image: entry.track.image, size: 52, radius: 12),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  entry.track.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: playing ? const Color(0xFFB7A7FF) : null,
                  ),
                ),
              ),
              if (playing) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.graphic_eq_rounded,
                  size: 15,
                  color: AppColors.lavender,
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Text(
                '${entry.track.artist} · ${offlineSize(entry.fileSize)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              expired
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 12,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Hết hạn · cần gia hạn',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Quyền đến ${displayDate(entry.expiresAt.toLocal().toIso8601String())}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 11.5,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        if (soon) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: daysLeft == 0
                                  ? AppColors.error.withValues(alpha: .12)
                                  : AppColors.surfaceGlass,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              daysLeft == 0
                                  ? 'Hết hạn hôm nay'
                                  : 'Còn $daysLeft ngày',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: daysLeft == 0
                                    ? AppColors.error
                                    : AppColors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ],
          ),
          // onRemove null khi đang bận — nút xóa mờ đi, không tác động.
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TrackOptionsButton(track: entry.track, offline: true),
              IconButton(
                tooltip: 'Xóa bản tải của ${entry.track.displayName}',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.secondary,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({required this.allowed, required this.online});
  final bool? allowed;
  final bool online;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  MoodifyWebAssets.soundwaveDark,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xD6090A0D),
                        Color(0xEB0D0F16),
                        Color(0xF811131A),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 24,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: const Icon(
                        Icons.library_music_outlined,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có bản tải trên máy',
                      textAlign: TextAlign.center,
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
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: () => context.go('/search'),
                      icon: const Icon(Icons.search_rounded, size: 17),
                      label: Text(
                        allowed == true ? 'Tìm bài để tải' : 'Tìm nhạc để nghe',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      if (allowed == false) ...[
        const SizedBox(height: 16),
        StudioVipAdBanner(
          title: 'Mở khóa tải nhạc Offline không giới hạn',
          subtitle:
              'Lưu bài hát yêu thích về máy để thưởng thức mọi lúc ngay cả khi không có kết nối mạng.',
          ctaLabel: 'Nâng cấp VIP',
          onTap: () => context.push('/subscriptions'),
        ),
      ],
    ],
  );
}
