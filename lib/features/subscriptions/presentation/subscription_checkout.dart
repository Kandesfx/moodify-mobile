import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';
import '../domain/subscription_models.dart';

/// Màn thanh toán SePay: QR + đếm ngược 15 phút + thông tin chuyển khoản
/// và các trạng thái kết quả (thành công / hết hạn / đã hủy).
class SubscriptionCheckoutView extends StatelessWidget {
  const SubscriptionCheckoutView({
    super.key,
    required this.order,
    required this.status,
    required this.checking,
    required this.scheduledPayment,
    required this.lastCheckedAt,
    required this.current,
    required this.onCheck,
    required this.onClose,
    required this.onRecreate,
  });

  final PaymentOrder order;
  final String status;
  final bool checking;
  final bool scheduledPayment;
  final DateTime? lastCheckedAt;
  final SubscriptionInfo? current;
  final Future<void> Function() onCheck;
  final VoidCallback onClose;
  final Future<void> Function() onRecreate;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      'SUCCESS' => _ResultView(
        order: order,
        badge: const _SuccessBadge(),
        title: scheduledPayment
            ? 'Gói đã được xếp lịch'
            : 'Quyền lợi VIP đã mở khóa',
        message: scheduledPayment
            ? 'Thanh toán thành công. Gói sẽ bắt đầu theo lịch áp dụng bên dưới.'
            : 'Thanh toán thành công. Gói đã có hiệu lực trên tài khoản của bạn.',
        planLine: current == null
            ? null
            : '${current!.name} · ${_displayDate(order.startAt)} → ${_displayDate(order.expiresAt)}',
        actionLabel: 'Về gói dịch vụ',
        onAction: onClose,
      ),
      'EXPIRED' || 'CANCELLED' => _ResultView(
        order: order,
        badge: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceRaised,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            status == 'EXPIRED'
                ? Icons.hourglass_bottom_rounded
                : Icons.cancel_outlined,
            size: 44,
            color: AppColors.secondary,
          ),
        ),
        title: status == 'EXPIRED' ? 'Đơn đã hết hạn' : 'Đơn đã bị hủy',
        message:
            'Mã QR và đơn thanh toán có hiệu lực tối đa trong 15 phút. '
            'Tạo lại mã để tiếp tục đăng ký gói.',
        actionLabel: 'Tạo lại mã thanh toán',
        onAction: onRecreate,
        secondaryActionLabel: 'Về gói dịch vụ',
        onSecondaryAction: onClose,
      ),
      _ => _PendingCheckout(
        order: order,
        checking: checking,
        lastCheckedAt: lastCheckedAt,
        onCheck: onCheck,
        onExpiredCheck: onCheck,
      ),
    };
  }
}

class _PendingCheckout extends StatelessWidget {
  const _PendingCheckout({
    required this.order,
    required this.checking,
    required this.lastCheckedAt,
    required this.onCheck,
    required this.onExpiredCheck,
  });

  final PaymentOrder order;
  final bool checking;
  final DateTime? lastCheckedAt;
  final Future<void> Function() onCheck;
  final VoidCallback onExpiredCheck;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _PendingPill(),
            const SizedBox(width: 8),
            _CountdownPill(
              // Đếm ngược cửa sổ QR 15 phút (paymentExpiresAt), không phải
              // ngày kết thúc kỳ hạn dịch vụ (expiresAt).
              expiresAt: _parseDate(order.paymentExpiresAt),
              onExpired: onExpiredCheck,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Quét VietQR hoặc sao chép thông tin để chuyển khoản đúng số tiền và nội dung.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppColors.secondary),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Image.network(
              order.qr.toString(),
              width: 240,
              height: 240,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 220,
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
        _TransferDetailsCard(order: order),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: checking ? null : onCheck,
          icon: checking
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded, size: 19),
          label: Text(checking ? 'Đang kiểm tra…' : 'Kiểm tra thanh toán'),
        ),
        const SizedBox(height: 8),
        Text(
          'Tự động kiểm tra mỗi 5 giây'
          '${lastCheckedAt == null ? '' : ' · Lần cuối ${DateFormat('HH:mm:ss').format(lastCheckedAt!)}'}',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppColors.secondary),
        ),
        const SizedBox(height: 12),
        Text(
          'Đơn đang chờ xác nhận từ ngân hàng. Bạn có thể kiểm tra lại hoặc quay lại xem đơn trong lịch sử gói.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppColors.secondary),
        ),
      ],
    );
  }
}

class _TransferDetailsCard extends StatelessWidget {
  const _TransferDetailsCard({required this.order});
  final PaymentOrder order;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        _CopyRow(label: 'Ngân hàng', value: order.bank),
        _divider(),
        _CopyRow(label: 'Số tài khoản', value: order.account, mono: true),
        _divider(),
        _CopyRow(label: 'Chủ tài khoản', value: order.owner),
        _divider(),
        _CopyRow(
          label: 'Số tiền',
          value: order.amount.toStringAsFixed(0),
          mono: true,
        ),
        _divider(),
        _CopyRow(
          label: 'Nội dung chuyển khoản',
          value: order.content,
          mono: true,
          emphasized: true,
        ),
      ],
    ),
  );

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);
}

class _CopyRow extends StatefulWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    this.mono = false,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool mono;
  final bool emphasized;

  @override
  State<_CopyRow> createState() => _CopyRowState();
}

class _CopyRowState extends State<_CopyRow> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final valueStyle = widget.mono
        ? const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          )
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.emphasized
                      ? '${widget.label} (Bắt buộc chính xác)'
                      : widget.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: widget.emphasized
                        ? AppColors.lavender
                        : AppColors.secondary,
                    fontWeight: widget.emphasized
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 3),
                Text(widget.value, style: valueStyle),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Sao chép ${widget.label}',
            onPressed: _copy,
            icon: AnimatedSwitcher(
              duration: AppMotion.duration(context, 180),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                key: ValueKey(_copied),
                size: 19,
                color: _copied ? AppColors.lavender : AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPill extends StatefulWidget {
  const _PendingPill();

  @override
  State<_PendingPill> createState() => _PendingPillState();
}

class _PendingPillState extends State<_PendingPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _reduced = false;
  @override
  void initState() {
    super.initState();
    // Không tra cứu MediaQuery trong initState (vi phạm inherited widget);
    // cấu hình reduce-motion được đọc trong didChangeDependencies bên dưới.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    if (reduced) {
      _pulse.stop();
      _pulse.value = 1;
    } else {
      _pulse.value = 0;
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween<double>(
            begin: .25,
            end: 1,
          ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
          child: const Icon(Icons.circle, size: 8, color: AppColors.lavender),
        ),
        const SizedBox(width: 8),
        Text(
          'Đang chờ thanh toán',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _CountdownPill extends StatefulWidget {
  const _CountdownPill({required this.expiresAt, required this.onExpired});
  final DateTime? expiresAt;
  final VoidCallback onExpired;

  @override
  State<_CountdownPill> createState() => _CountdownPillState();
}

class _CountdownPillState extends State<_CountdownPill> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  bool _announced = false;

  @override
  void initState() {
    super.initState();
    _recompute();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _recompute());
  }

  void _recompute() {
    final expiresAt = widget.expiresAt;
    final next = expiresAt == null
        ? Duration.zero
        : expiresAt.difference(DateTime.now());
    if (!mounted) return;
    setState(() => _remaining = next.isNegative ? Duration.zero : next);
    if (_remaining <= Duration.zero && !_announced) {
      _announced = true;
      // Hết giờ: yêu cầu kiểm tra để backend chốt EXPIRED cho đơn.
      widget.onExpired();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining <= Duration.zero;
    final seconds = _remaining.inSeconds;
    final label = expired
        ? 'Đã hết hạn chờ'
        : 'Hết hạn sau ${seconds ~/ 60}:${String.fromCharCode(48 + (seconds % 60) ~/ 10)}${seconds % 10}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: expired
            ? AppColors.surface
            : AppColors.primary.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: expired
              ? AppColors.border
              : AppColors.primary.withValues(alpha: .4),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: expired ? AppColors.secondary : AppColors.lavender,
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.order,
    required this.badge,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.planLine,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final PaymentOrder order;
  final Widget badge;
  final String title, message, actionLabel;
  final VoidCallback onAction;
  final String? planLine;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 24),
      Center(child: badge),
      const SizedBox(height: 20),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.secondary,
          height: 1.5,
        ),
      ),
      if (planLine != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            planLine!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
      const SizedBox(height: 24),
      FilledButton(onPressed: onAction, child: Text(actionLabel)),
      if (secondaryActionLabel != null) ...[
        const SizedBox(height: 8),
        TextButton(
          onPressed: onSecondaryAction,
          child: Text(secondaryActionLabel!),
        ),
      ],
    ],
  );
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: AppMotion.duration(context, 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.scale(scale: .6 + .4 * value, child: child),
      ),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: .16),
          border: Border.all(color: AppColors.primary, width: 1.6),
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 46,
          color: AppColors.lavender,
        ),
      ),
    );
  }
}

String _displayDate(String? value) {
  final date = DateTime.tryParse((value ?? '').replaceFirst(' ', 'T'));
  if (date == null) return '—';
  return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
}

DateTime? _parseDate(String? value) =>
    DateTime.tryParse((value ?? '').replaceFirst(' ', 'T'));
