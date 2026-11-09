import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/display_date.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/app_sheets.dart';
import '../../../core/widgets/studio_banners.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../player/presentation/player_screen.dart';
import '../data/fcm_service.dart';
import '../data/notification_repository.dart';

final latestNotificationAlertProvider = StateProvider<InboxItem?>(
  (ref) => null,
);

final inboxProvider =
    StateNotifierProvider.autoDispose<
      InboxController,
      AsyncValue<List<InboxItem>>
    >((ref) {
      final user = ref.watch(
        sessionControllerProvider.select((s) => s.session?.user.id),
      );
      final controller = InboxController(
        ref.watch(notificationRepositoryProvider),
        user != null,
        userId: user,
        store: ref.watch(keyValueStoreProvider),
        alertService: ref.watch(notificationAlertServiceProvider),
        onNewAlert: (item) {
          ref.read(latestNotificationAlertProvider.notifier).state = item;
        },
      );
      if (!InboxController.isWidgetTest && user != null) {
        controller.startAutoSync();
      }
      return controller;
    });

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(inboxProvider).valueOrNull ?? const <InboxItem>[];
  return items.where((e) => !e.read).length;
});

class InboxController extends StateNotifier<AsyncValue<List<InboxItem>>> {
  InboxController(
    this.repository,
    this.authenticated, {
    this.userId,
    this.store,
    this.alertService,
    this.onNewAlert,
  }) : super(const AsyncLoading());

  final NotificationRepository repository;
  final bool authenticated;
  final String? userId;
  final KeyValueStore? store;
  final NotificationAlertService? alertService;
  final void Function(InboxItem item)? onNewAlert;

  bool _busy = false;
  bool _loadedSeenStore = false;
  final Set<String> _seenIds = <String>{};
  Timer? _pollTimer;

  static bool get isWidgetTest {
    try {
      return const bool.fromEnvironment('FLUTTER_TEST') ||
          WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  String? get _storageKey =>
      userId == null ? null : 'notifications.seen.$userId';

  void startAutoSync() {
    if (!authenticated) return;
    if (alertService != null) {
      unawaited(alertService!.ensurePermission());
    }
    unawaited(load());
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) unawaited(load());
    });
  }

  Future<void> _restoreSeenIds() async {
    if (_loadedSeenStore) return;
    _loadedSeenStore = true;
    final key = _storageKey;
    final kv = store;
    if (key == null || kv == null) return;
    try {
      final raw = await kv.read(key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is String && item.isNotEmpty) {
            _seenIds.add(item);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _persistSeenIds() async {
    final key = _storageKey;
    final kv = store;
    if (key == null || kv == null) return;
    try {
      final list = _seenIds.take(200).toList(growable: false);
      await kv.write(key, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> load() async {
    if (!authenticated || _busy) return;
    _busy = true;
    try {
      await _restoreSeenIds();
      final items = await repository.load();
      if (!mounted) return;
      await _checkAndNotifyNewItems(items);
      if (mounted) state = AsyncData(items);
    } catch (error, stack) {
      if (mounted) state = AsyncError(AppFailure.from(error), stack);
      return;
    } finally {
      _busy = false;
    }
  }

  void markSeen({String? id, String? title, String? message}) {
    if (id != null && id.isNotEmpty) {
      _seenIds.add(id);
    }
    if (title != null && message != null) {
      final fingerprint = '${title.trim()}|${message.trim()}';
      if (fingerprint.isNotEmpty) {
        _seenIds.add(fingerprint);
      }
    }
    unawaited(_persistSeenIds());
  }

  Future<void> _checkAndNotifyNewItems(List<InboxItem> items) async {
    final unreadNew = items
        .where((item) {
          if (item.read) return false;
          if (_seenIds.contains(item.id)) return false;
          final fingerprint = '${item.title.trim()}|${item.message.trim()}';
          if (fingerprint.isNotEmpty && _seenIds.contains(fingerprint)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    for (final item in items) {
      _seenIds.add(item.id);
      final fingerprint = '${item.title.trim()}|${item.message.trim()}';
      if (fingerprint.isNotEmpty) {
        _seenIds.add(fingerprint);
      }
    }
    if (unreadNew.isNotEmpty) {
      await _persistSeenIds();
      final newest = unreadNew.first;
      onNewAlert?.call(newest);
      await alertService?.alertNewNotification(newest);
    } else if (items.isNotEmpty) {
      await _persistSeenIds();
    }
  }

  /// Phát thử thông báo hệ thống kèm tiếng nhận diện thương hiệu "Moodify".
  Future<void> previewBrandAlert() async {
    final current = state.valueOrNull ?? const <InboxItem>[];
    final sample = current.isNotEmpty
        ? current.first
        : InboxItem(
            id: 'preview-${DateTime.now().millisecondsSinceEpoch}',
            title: 'Thông báo từ hệ thống Moodify',
            message: 'Âm báo nhận diện thương hiệu Moodify đã được kích hoạt.',
            read: false,
            createdAt: DateTime.now().toIso8601String(),
          );
    await alertService?.ensurePermission();
    onNewAlert?.call(sample);
    await alertService?.alertNewNotification(sample);
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

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});
  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(inboxProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            tooltip: 'Nghe thử âm báo Moodify',
            onPressed: () =>
                ref.read(inboxProvider.notifier).previewBrandAlert(),
            icon: const Icon(Icons.volume_up_rounded),
          ),
          IconButton(
            tooltip: 'Mã FCM Token thiết bị',
            onPressed: () => _showFcmTokenDialog(context),
            icon: const Icon(Icons.cloud_sync_rounded),
          ),
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
              itemCount: items.isEmpty ? 2 : items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return StudioHeroBanner(
                    imageAsset: MoodifyWebAssets.adBrandIdent,
                    eyebrow: 'HỘP THƯ MOODIFY · ÂM BÁO THƯƠNG HIỆU',
                    eyebrowIcon: Icons.notifications_active_rounded,
                    title: 'Thông báo & cập nhật tài khoản',
                    subtitle:
                        'Theo dõi trạng thái gói dịch vụ, bảo mật thiết bị và các thông báo hệ thống kèm âm báo nhận diện "Moodify".',
                    footer: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => ref
                            .read(inboxProvider.notifier)
                            .previewBrandAlert(),
                        icon: const Icon(Icons.graphic_eq_rounded, size: 18),
                        label: const Text('Nghe thử âm báo Moodify'),
                      ),
                    ),
                  );
                }
                if (items.isEmpty) {
                  return const LoadMessage(message: 'Bạn chưa có thông báo.');
                }
                final item = items[i - 1];
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

  void _showFcmTokenDialog(BuildContext context) {
    final token = ref.read(fcmServiceProvider).fcmToken;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mã FCM Token thiết bị'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dùng mã token này trên Firebase Console để gửi thông báo thử nghiệm khi tắt app:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: SelectableText(
                token ??
                    'Chưa có token (Vui lòng kiểm tra kết nối mạng và thử lại sau vài giây).',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (token != null)
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: token));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép mã FCM Token vào bộ nhớ tạm!'),
                    duration: Duration(seconds: 2),
                  ),
                );
                Navigator.of(dialogContext).pop();
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Sao chép'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

/// Lớp phủ hiển thị biểu ngữ thông báo nổi hiện đại trong ứng dụng khi có thông báo mới
/// từ hệ thống (hỗ trợ chuyển động mượt mà, vuốt lên hoặc vuốt ngang để đóng ngay,
/// không bị dính cứng mép trên và phân loại màu sắc thẩm mỹ chuẩn Studio Dark).
class NotificationToastOverlay extends ConsumerStatefulWidget {
  const NotificationToastOverlay({
    super.key,
    required this.child,
    this.onOpenNotifications,
  });

  final Widget child;
  final VoidCallback? onOpenNotifications;

  @override
  ConsumerState<NotificationToastOverlay> createState() =>
      _NotificationToastOverlayState();
}

class _NotificationToastOverlayState
    extends ConsumerState<NotificationToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  Timer? _dismissTimer;
  InboxItem? _currentAlert;
  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeInQuad,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    final initial = ref.read(latestNotificationAlertProvider);
    if (initial != null) {
      _currentAlert = initial;
      _animController.value = 1.0;
      _scheduleAutoDismiss();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _scheduleAutoDismiss() {
    _dismissTimer?.cancel();
    if (InboxController.isWidgetTest) return;
    _dismissTimer = Timer(const Duration(seconds: 5), () {
      _dismiss();
    });
  }

  void _dismiss({bool clearProvider = true}) {
    _dismissTimer?.cancel();
    if (!mounted) return;
    if (_animController.isDismissed) {
      if (_currentAlert != null) {
        setState(() {
          _currentAlert = null;
          _dragOffsetY = 0.0;
        });
      }
      if (clearProvider && ref.read(latestNotificationAlertProvider) != null) {
        ref.read(latestNotificationAlertProvider.notifier).state = null;
      }
      return;
    }
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentAlert = null;
          _dragOffsetY = 0.0;
        });
        if (clearProvider &&
            ref.read(latestNotificationAlertProvider) != null) {
          ref.read(latestNotificationAlertProvider.notifier).state = null;
        }
      }
    });
  }

  void _showAlert(InboxItem alert) {
    setState(() {
      _currentAlert = alert;
      _dragOffsetY = 0.0;
    });
    _animController.forward(from: 0.0);
    _scheduleAutoDismiss();
  }

  (Color, IconData, String) _styleForType(String type, String fallbackLabel) {
    return switch (type) {
      'BILLING' => (
        AppColors.vipGold,
        Icons.workspace_premium_rounded,
        'GÓI DỊCH VỤ',
      ),
      'PROMO' => (const Color(0xFFF43F5E), Icons.local_offer_rounded, 'ƯU ĐÃI'),
      'ANNOUNCEMENT' => (
        const Color(0xFF38BDF8),
        Icons.campaign_rounded,
        'THÔNG BÁO',
      ),
      'MODERATION' => (
        const Color(0xFFFB923C),
        Icons.gavel_rounded,
        'KIỂM DUYỆT',
      ),
      _ => (
        AppColors.lavender,
        Icons.notifications_active_rounded,
        fallbackLabel.isNotEmpty ? fallbackLabel : 'HỆ THỐNG',
      ),
    };
  }

  Widget _buildCard(BuildContext context, InboxItem alert) {
    final (accentColor, iconData, badgeLabel) = _styleForType(
      alert.type,
      alert.typeLabel,
    );

    return Dismissible(
      key: ValueKey('toast-${alert.id}-${alert.createdAt}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => _dismiss(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragDown: (_) => _dismissTimer?.cancel(),
        onVerticalDragCancel: _scheduleAutoDismiss,
        onVerticalDragUpdate: (details) {
          if (details.delta.dy < 0) {
            setState(() {
              _dragOffsetY = (_dragOffsetY + details.delta.dy).clamp(
                -120.0,
                0.0,
              );
            });
          } else if (_dragOffsetY < 0) {
            setState(() {
              _dragOffsetY = (_dragOffsetY + details.delta.dy).clamp(
                -120.0,
                0.0,
              );
            });
          }
        },
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (_dragOffsetY < -20 || velocity < -120) {
            _dismiss();
          } else {
            setState(() => _dragOffsetY = 0.0);
            _scheduleAutoDismiss();
          }
        },
        child: Transform.translate(
          offset: Offset(0, _dragOffsetY),
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xF8181A28), Color(0xF412141F)],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.4),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    _dismiss();
                    widget.onOpenNotifications?.call();
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Thanh pill nhỏ hiển thị khả năng vuốt lên để đóng
                      Center(
                        child: Container(
                          width: 36,
                          height: 3.5,
                          margin: const EdgeInsets.only(top: 8, bottom: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 10, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    accentColor.withValues(alpha: 0.22),
                                    accentColor.withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Icon(
                                iconData,
                                color: accentColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: accentColor.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          badgeLabel,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                            color: accentColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        '· MOODIFY',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                          color: Color(0xFF8E92A4),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    alert.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.25,
                                    ),
                                  ),
                                  if (alert.message.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      alert.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFCACDD8),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'Đóng thông báo',
                              onPressed: _dismiss,
                              icon: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<InboxItem?>(latestNotificationAlertProvider, (prev, next) {
      if (next != null && next.id != prev?.id) {
        _showAlert(next);
      } else if (next == null &&
          _currentAlert != null &&
          !_animController.isDismissed) {
        _dismiss(clearProvider: false);
      }
    });

    final alert = _currentAlert;
    final showToast = alert != null;

    return Stack(
      children: [
        widget.child,
        if (showToast)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: _buildCard(context, alert),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
