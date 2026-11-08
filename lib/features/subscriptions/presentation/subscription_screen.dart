import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/formatters/display_date.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/studio_banners.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../player/presentation/player_screen.dart';
import '../domain/subscription_models.dart';
import 'subscription_checkout.dart';
import 'subscription_controller.dart';

String vnd(Object? amount) {
  try {
    return '${NumberFormat.decimalPattern('vi_VN').format(paymentAmount(amount))} đ';
  } catch (_) {
    return 'Chưa có giá';
  }
}

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with WidgetsBindingObserver {
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
  void didChangeAppLifecycleState(AppLifecycleState state) => ref
      .read(subscriptionProvider.notifier)
      .active(state == AppLifecycleState.resumed);

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionControllerProvider).session == null) {
      return const GuestPrompt(
        title: 'Gói dịch vụ',
        message: 'Đăng nhập để xem gói hiện tại và báo giá cho tài khoản.',
        returnTo: '/subscriptions',
      );
    }
    final state = ref.watch(subscriptionProvider);
    final controller = ref.read(subscriptionProvider.notifier);
    final order = state.order;
    // Phản hồi khi kiểm tra thủ công mà đơn vẫn PENDING (như alert trên web).
    ref.listen(subscriptionProvider.select((s) => s.pendingNotice), (
      previous,
      next,
    ) {
      if (next != previous && next > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hệ thống chưa nhận được thanh toán. Đảm bảo bạn đã chuyển đúng '
              'số tiền và nội dung chuyển khoản!',
            ),
          ),
        );
      }
    });
    // "Tiếp tục thanh toán" không mở được đơn (hết hạn, lỗi mạng/máy chủ):
    // báo bằng SnackBar để người dùng thấy ngay cả khi đang cuộn ở lịch sử.
    ref.listen(subscriptionProvider.select((s) => s.resumeNotice), (
      previous,
      next,
    ) {
      if (next != previous && next > 0) {
        final message = ref.read(subscriptionProvider).failure?.message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message ?? 'Không tiếp tục được thanh toán. Vui lòng thử lại.',
            ),
          ),
        );
      }
    });
    return PopScope(
      canPop: order == null,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && order != null) controller.closeCheckout();
      },
      child: Scaffold(
        bottomNavigationBar: const MiniPlayer(),
        appBar: AppBar(
          title: Text(order == null ? 'Gói dịch vụ' : 'Thanh toán'),
          leading: order == null
              ? null
              : IconButton(
                  tooltip: 'Quay lại gói dịch vụ',
                  onPressed: controller.closeCheckout,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
        ),
        body: RefreshIndicator(
          onRefresh: order == null
              ? controller.load
              : () => controller.check(manual: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (state.loading || state.busy) const LinearProgressIndicator(),
              if (state.failure != null)
                LoadMessage(
                  message: state.failure!.message,
                  retry: order == null
                      ? controller.load
                      : () => controller.check(manual: true),
                ),
              if (order != null)
                SubscriptionCheckoutView(
                  order: order,
                  status: state.status,
                  checking: state.checking,
                  scheduledPayment: state.scheduledPayment,
                  lastCheckedAt: state.lastCheckedAt,
                  current: state.current,
                  onCheck: () => controller.check(manual: true),
                  onClose: controller.closeCheckout,
                  onRecreate: () => controller.recreateOrder(),
                )
              else ...[
                _CurrentPlanCard(current: state.current),
                const SizedBox(height: 16),
                const _BenefitList(),
                const SizedBox(height: 16),
                const StudioHeroBanner(
                  imageAsset: MoodifyWebAssets.adVipPremium,
                  eyebrow: 'MOODIFY VIP STUDIO',
                  eyebrowIcon: Icons.auto_awesome_rounded,
                  title: 'Không gian âm nhạc trọn vẹn mọi khoảnh khắc',
                  subtitle:
                      'Loại bỏ quảng cáo, mở khóa tải nhạc offline, tìm kiếm bài hát theo cảm xúc và phòng thu Karaoke nâng cao.',
                ),
                const SizedBox(height: 28),
                Text(
                  'Chọn gói cho bạn',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (state.hasPendingPayment)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Bạn có đơn đang chờ thanh toán. Chạm vào đơn trong lịch sử '
                      'gói để thanh toán tiếp, hoặc hủy đơn trước khi tạo đơn mới.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                if (!state.loading &&
                    state.quotes.isEmpty &&
                    state.failure == null)
                  const LoadMessage(message: 'Chưa có gói đang mở bán.'),
                for (final (index, quote) in state.quotes.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SectionEntrance(
                      order: index,
                      child: _PackageCard(
                        quote: quote,
                        recommended:
                            state.quotes.length > 2 &&
                            quote.days == _recommendedDays(state.quotes),
                        disabled:
                            state.busy ||
                            state.loading ||
                            state.needsReview ||
                            state.hasPendingPayment,
                        // Vào thẳng bước thanh toán VietQR: thông tin gói,
                        // giá và điều kiện áp dụng đã hiển thị đầy đủ trên
                        // thẻ nên không cần hộp thoại xác nhận nữa.
                        onSubscribe: () => controller.checkout(quote.id),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Lịch sử gói và thanh toán',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (!state.loading && state.management.isEmpty)
                  const LoadMessage(message: 'Chưa có giao dịch.'),
                for (final item in state.management)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _HistoryCard(
                      item: item,
                      busy: state.busy || state.loading || state.resuming,
                      resuming: state.resuming,
                      onCheck: (payment) => controller.refreshPayment(payment),
                      onResume: (payment) =>
                          controller.resumePayment(payment.code),
                      onCancel: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Hủy đơn hoặc lịch áp dụng?'),
                            content: const Text(
                              'Hủy lịch áp dụng không tự động hoàn tiền. Xác nhận hủy gói được chọn?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Giữ lại'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Xác nhận hủy'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && mounted) {
                          controller.cancel(item.id);
                        }
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Gói khuyến nghị: chu kỳ 90 ngày nếu đang bán (điểm cân bằng giá/ngày).
  int _recommendedDays(List<PackageQuote> quotes) {
    for (final quote in quotes) {
      if (quote.days == 90) return 90;
    }
    return -1;
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.current});
  final SubscriptionInfo? current;

  @override
  Widget build(BuildContext context) {
    final premium = current?.premium == true;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: premium
                ? AppColors.primary.withValues(alpha: .45)
                : AppColors.borderSoft,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                premium
                    ? MoodifyWebAssets.adBrandIdent
                    : MoodifyWebAssets.audioExperienceBanner,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xD8090A0D),
                      Color(0xEB0D0F16),
                      Color(0xF511131A),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: AppColors.lavender,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Gói hiện tại',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          current?.name ?? 'Tài khoản Miễn phí',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: premium
                              ? AppColors.primary.withValues(alpha: .16)
                              : AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: premium
                                ? AppColors.primary.withValues(alpha: .5)
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          premium ? 'Đang sử dụng' : 'Miễn phí',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: premium
                                    ? AppColors.lavender
                                    : AppColors.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  if (current?.expiresAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Có hiệu lực đến ${displayDate(current!.expiresAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitList extends StatelessWidget {
  const _BenefitList();

  @override
  Widget build(BuildContext context) {
    const benefits = [
      (Icons.block_rounded, 'Nghe nhạc không quảng cáo'),
      (Icons.download_rounded, 'Tải bài hát để nghe offline'),
      (Icons.all_inclusive_rounded, 'Không giới hạn số bài hát'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final (icon, label) in benefits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: AppColors.lavender),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.quote,
    required this.recommended,
    required this.disabled,
    required this.onSubscribe,
  });

  final PackageQuote quote;
  final bool recommended;
  final bool disabled;
  final Future<void> Function() onSubscribe;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final perDay = quote.days > 0 ? quote.amount / quote.days : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: recommended
              ? AppColors.primary.withValues(alpha: .65)
              : AppColors.border,
          width: recommended ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  quote.name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (recommended)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: .5),
                    ),
                  ),
                  child: Text(
                    'Phổ biến nhất',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.lavender,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                vnd(quote.amount),
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ ${quote.days} ngày',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          if (perDay != null && perDay > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '≈ ${NumberFormat.decimalPattern('vi_VN').format(perDay.round())} đ/ngày',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ),
          if (quote.description != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                quote.description!,
                style: textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
          if (quote.actionDescription != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                quote.actionDescription!,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.secondary,
                  height: 1.5,
                ),
              ),
            ),
          if (quote.startAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Áp dụng từ ${displayDate(quote.startAt)}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Mọi gói dùng chung một kiểu nút đăng ký (tím đậm, rõ đang bật):
          // trước đây gói thường dùng FilledButton.tonal màu nhạt khiến người
          // dùng tưởng gói bị vô hiệu. Gói khuyến nghị vẫn nổi bật nhờ badge
          // "Phổ biến nhất" và viền tím ở trên.
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: disabled ? null : onSubscribe,
              child: Text(quote.actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.busy,
    required this.resuming,
    required this.onCheck,
    required this.onResume,
    required this.onCancel,
  });

  final ManagedSubscription item;
  final bool busy;
  final bool resuming;
  final Future<void> Function(PaymentReceipt payment) onCheck;
  final Future<void> Function(PaymentReceipt payment) onResume;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusChip(status: item.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${displayDate(item.startAt)} → ${displayDate(item.endAt)}',
            style: textTheme.bodySmall?.copyWith(color: AppColors.secondary),
          ),
          for (final payment in item.payments) ...[
            const SizedBox(height: 10),
            _PaymentBlock(
              payment: payment,
              busy: busy,
              resuming: resuming,
              onCheck: onCheck,
              onResume: onResume,
            ),
          ],
          if (item.canCancel) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: busy ? null : () => onCancel(),
                child: const Text('Hủy đơn / lịch áp dụng'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Khối một giao dịch trong thẻ lịch sử. Với đơn "Chờ thanh toán" còn hiệu
/// lực, cả khối đều bấm được để mở lại màn thanh toán (resume QR) và có nút
/// "Tiếp tục thanh toán" nổi bật — người dùng lỡ thoát giữa chừng quay lại
/// được mà không phải tạo đơn mới.
class _PaymentBlock extends StatelessWidget {
  const _PaymentBlock({
    required this.payment,
    required this.busy,
    required this.resuming,
    required this.onCheck,
    required this.onResume,
  });

  final PaymentReceipt payment;
  final bool busy;
  final bool resuming;
  final Future<void> Function(PaymentReceipt payment) onCheck;
  final Future<void> Function(PaymentReceipt payment) onResume;

  bool get _canResume => payment.status == 'PENDING' && payment.code.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: !busy && _canResume ? () => onResume(payment) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      payment.code,
                      style: textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    vnd(payment.amount),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _StatusChip(status: payment.status, compact: true),
                  const Spacer(),
                  if (_canResume)
                    TextButton.icon(
                      onPressed: busy ? null : () => onCheck(payment),
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text(
                        'Kiểm tra',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
              if (_canResume) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: busy ? null : () => onResume(payment),
                    icon: resuming
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text('Tiếp tục thanh toán'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.compact = false});
  final Object? status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = switch (status) {
      'SUCCESS' || 'ACTIVE' => (
        status == 'ACTIVE' ? 'Đang áp dụng' : 'Đã thanh toán',
        const Color(0xFF7EE2B8),
        const Color(0x1434D399),
      ),
      'PENDING' => (
        'Chờ thanh toán',
        const Color(0xFFFCD34D),
        const Color(0x14F59E0B),
      ),
      'CANCELLED' => ('Đã hủy', AppColors.secondary, AppColors.surfaceRaised),
      'EXPIRED' => ('Hết hạn', AppColors.secondary, AppColors.surfaceRaised),
      _ => (
        status?.toString() ?? 'Chưa xác định',
        AppColors.secondary,
        AppColors.surfaceRaised,
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 11 : null,
        ),
      ),
    );
  }
}
