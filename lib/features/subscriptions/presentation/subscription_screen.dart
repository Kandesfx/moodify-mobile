import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/formatters/display_date.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/subscription_models.dart';
import '../../catalog/presentation/catalog_widgets.dart';
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
    return PopScope(
      canPop: order == null,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && order != null) controller.closeCheckout();
      },
      child: Scaffold(
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
          onRefresh: order == null ? controller.load : controller.check,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (state.loading || state.busy) const LinearProgressIndicator(),
              if (state.failure != null)
                LoadMessage(
                  message: state.failure!.message,
                  retry: order == null ? controller.load : controller.check,
                ),
              if (order != null) ...[
                Text(
                  order.packageName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  vnd(order.amount),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                if (state.status == 'PENDING') ...[
                  const Text(
                    'Quét VietQR hoặc sao chép thông tin để chuyển khoản đúng số tiền và nội dung.',
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: Image.network(
                        order.qr.toString(),
                        width: 260,
                        height: 260,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 240,
                          height: 100,
                          child: Center(
                            child: Text(
                              'Chưa tải được QR',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _copy('Ngân hàng', order.bank),
                  _copy('Số tài khoản', order.account),
                  _copy('Chủ tài khoản', order.owner),
                  _copy('Số tiền', order.amount.toStringAsFixed(0)),
                  _copy('Nội dung chuyển khoản', order.content),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: state.checking ? null : controller.check,
                    icon: const Icon(Icons.sync_rounded),
                    label: Text(
                      state.checking ? 'Đang kiểm tra…' : 'Kiểm tra thanh toán',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Đơn đang chờ xác nhận từ ngân hàng. Bạn có thể kiểm tra lại hoặc quay lại xem đơn trong lịch sử gói.',
                  ),
                ] else ...[
                  Icon(
                    state.status == 'SUCCESS'
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(switch (state.status) {
                    'SUCCESS' => 'Máy chủ đã xác nhận thanh toán.',
                    'EXPIRED' => 'Đơn thanh toán đã hết hạn.',
                    _ => 'Đơn thanh toán đã bị hủy.',
                  }, textAlign: TextAlign.center),
                  if (state.status == 'SUCCESS' && state.current != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Gói hiện tại: ${state.current!.name}\nThời hạn gói đã mua: ${displayDate(order.startAt)} → ${displayDate(order.expiresAt)}',
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: controller.closeCheckout,
                    child: const Text('Về gói dịch vụ'),
                  ),
                ],
              ] else ...[
                Text(
                  state.current?.name ?? 'Gói hiện tại',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (state.current?.expiresAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Có hiệu lực đến ${displayDate(state.current!.expiresAt)}',
                    ),
                  ),
                const SizedBox(height: 28),
                Text(
                  'Chọn gói cho bạn',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (state.hasPendingPayment)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Bạn có đơn đang chờ thanh toán. Kiểm tra hoặc hủy đơn trong lịch sử gói trước khi tạo đơn mới.',
                    ),
                  ),
                if (!state.loading &&
                    state.quotes.isEmpty &&
                    state.failure == null)
                  const LoadMessage(message: 'Chưa có gói đang mở bán.'),
                for (final quote in state.quotes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quote.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${vnd(quote.amount)} / ${quote.days} ngày',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (quote.description != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(quote.description!),
                              ),
                            if (quote.actionDescription != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(quote.actionDescription!),
                              ),
                            if (quote.startAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Áp dụng từ ${displayDate(quote.startAt)}',
                                ),
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed:
                                    state.busy ||
                                        state.loading ||
                                        state.needsReview ||
                                        state.hasPendingPayment
                                    ? null
                                    : () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: const Text(
                                              'Tạo đơn thanh toán?',
                                            ),
                                            content: Text(
                                              '${quote.name}\n${vnd(quote.amount)}\n${quote.actionDescription ?? ''}',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, false),
                                                child: const Text('Hủy'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, true),
                                                child: const Text('Tạo VietQR'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true && mounted) {
                                          controller.checkout(quote.id);
                                        }
                                      },
                                child: Text(quote.actionLabel),
                              ),
                            ),
                          ],
                        ),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${displayDate(item.startAt)} → ${displayDate(item.endAt)}',
                        ),
                        Text('Trạng thái: ${_status(item.status)}'),
                        for (final payment in item.payments) ...[
                          Text(
                            '${payment.code} · ${vnd(payment.amount)} · ${_status(payment.status)}',
                          ),
                          if (payment.status == 'PENDING' &&
                              payment.code.isNotEmpty)
                            TextButton.icon(
                              onPressed: state.busy || state.loading
                                  ? null
                                  : () => controller.refreshPayment(payment),
                              icon: const Icon(Icons.sync_rounded),
                              label: const Text('Kiểm tra đơn thanh toán'),
                            ),
                        ],
                        if (item.canCancel)
                          TextButton(
                            onPressed: state.busy
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text(
                                          'Hủy đơn hoặc lịch áp dụng?',
                                        ),
                                        content: const Text(
                                          'Hủy lịch áp dụng không tự động hoàn tiền. Xác nhận hủy gói được chọn?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('Giữ lại'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('Xác nhận hủy'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true && mounted) {
                                      controller.cancel(item.id);
                                    }
                                  },
                            child: const Text('Hủy đơn / lịch áp dụng'),
                          ),
                        const Divider(),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _copy(String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: SelectableText(value),
    trailing: IconButton(
      tooltip: 'Sao chép $label',
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Đã sao chép $label.')));
        }
      },
      icon: const Icon(Icons.copy_rounded, size: 20),
    ),
  );
  String _status(Object? value) => switch (value) {
    'PENDING' => 'Chờ thanh toán',
    'SUCCESS' => 'Đã thanh toán',
    'ACTIVE' => 'Đang áp dụng',
    'CANCELLED' => 'Đã hủy',
    'EXPIRED' => 'Hết hạn',
    _ => value?.toString() ?? 'Chưa xác định',
  };
}
