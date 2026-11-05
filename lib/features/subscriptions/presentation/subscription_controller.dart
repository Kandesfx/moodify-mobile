import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/domain/catalog_models.dart';
import '../application/premium_controller.dart';
import '../data/subscription_repository.dart';
import '../domain/subscription_models.dart';

final subscriptionProvider =
    StateNotifierProvider.autoDispose<
      SubscriptionController,
      SubscriptionState
    >((ref) {
      final user = ref.watch(
        sessionControllerProvider.select((s) => s.session?.user.id),
      );
      return SubscriptionController(
        ref.watch(subscriptionRepositoryProvider),
        user != null,
        // Parity event "moodify-subscription-updated" bên web: khi đơn
        // thanh toán thành công, trạng thái VIP toàn app cập nhật tức thì.
        onPaymentSuccess: () =>
            unawaited(ref.read(premiumProvider.notifier).refresh()),
      )..load();
    });

class SubscriptionState {
  const SubscriptionState({
    this.current,
    this.quotes = const [],
    this.management = const [],
    this.order,
    this.status = '',
    this.loading = false,
    this.busy = false,
    this.checking = false,
    this.resuming = false,
    this.needsReview = false,
    this.failure,
    this.lastCheckedAt,
    this.pendingNotice = 0,
    this.resumeNotice = 0,
    this.scheduledPayment = false,
    this.lastPackageId,
  });
  final SubscriptionInfo? current;
  final List<PackageQuote> quotes;
  final List<ManagedSubscription> management;
  final PaymentOrder? order;
  final String status;
  final bool loading, busy, checking, needsReview;
  // Đang mở lại một đơn PENDING từ lịch sử (riêng với busy để nút "Tiếp tục
  // thanh toán" có spinner của riêng nó).
  final bool resuming;
  bool get hasPendingPayment => management.any(
    (item) => item.payments.any((payment) => payment.status == 'PENDING'),
  );
  final AppFailure? failure;
  // Phản hồi cho lần kiểm tra thủ công gần nhất và báo hiệu đơn vẫn PENDING
  // (màn hình lắng nghe pendingNotice để hiện SnackBar như luồng web).
  final DateTime? lastCheckedAt;
  final int pendingNotice;
  // Báo hiệu lần "Tiếp tục thanh toán" thất bại gần nhất để màn hình hiện
  // SnackBar (lỗi chỉ render ở đầu danh sách thì không thấy khi đang cuộn).
  final int resumeNotice;
  // SUCCESS nhưng gói xếp lịch sau gói đang hiệu lực (isEffectiveNow == false).
  final bool scheduledPayment;
  final String? lastPackageId;
  SubscriptionState copy({
    SubscriptionInfo? current,
    List<PackageQuote>? quotes,
    List<ManagedSubscription>? management,
    PaymentOrder? order,
    String? status,
    bool? loading,
    bool? busy,
    bool? checking,
    bool? resuming,
    bool? needsReview,
    AppFailure? failure,
    bool clearOrder = false,
    DateTime? lastCheckedAt,
    bool clearLastCheckedAt = false,
    int? pendingNotice,
    int? resumeNotice,
    bool? scheduledPayment,
    String? lastPackageId,
  }) => SubscriptionState(
    current: current ?? this.current,
    quotes: quotes ?? this.quotes,
    management: management ?? this.management,
    order: clearOrder ? null : order ?? this.order,
    status: status ?? this.status,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    checking: checking ?? this.checking,
    resuming: resuming ?? this.resuming,
    needsReview: needsReview ?? this.needsReview,
    failure: failure,
    lastCheckedAt: clearLastCheckedAt
        ? null
        : lastCheckedAt ?? this.lastCheckedAt,
    pendingNotice: pendingNotice ?? this.pendingNotice,
    resumeNotice: resumeNotice ?? this.resumeNotice,
    scheduledPayment: scheduledPayment ?? this.scheduledPayment,
    lastPackageId: lastPackageId ?? this.lastPackageId,
  );
}

class SubscriptionController extends StateNotifier<SubscriptionState> {
  SubscriptionController(
    this.repository,
    this.authenticated, {
    this.onPaymentSuccess,
  }) : super(const SubscriptionState());
  final SubscriptionRepository repository;
  final bool authenticated;

  /// Được gọi khi một đơn thanh toán chuyển SUCCESS và có hiệu lực ngay —
  /// chỗ để báo `premiumProvider` refresh trạng thái VIP toàn app.
  final void Function()? onPaymentSuccess;
  Timer? _poll;
  bool _active = true;
  int _automaticChecks = 0;
  Future<void> load() async {
    if (!authenticated || state.loading || state.busy) return;
    state = state.copy(loading: true);
    try {
      final values = await Future.wait<Object>([
        repository.current(),
        repository.quotes(),
        repository.management(),
      ]);
      if (mounted) {
        state = state.copy(
          current: values[0] as SubscriptionInfo,
          quotes: values[1] as List<PackageQuote>,
          management: values[2] as List<ManagedSubscription>,
          loading: false,
          needsReview: false,
        );
      }
    } catch (error) {
      if (mounted) {
        state = state.copy(loading: false, failure: AppFailure.from(error));
      }
    }
  }

  Future<void> checkout(String id) async {
    if (!authenticated ||
        state.busy ||
        state.loading ||
        state.needsReview ||
        state.hasPendingPayment ||
        state.order != null) {
      return;
    }
    state = state.copy(busy: true);
    try {
      final order = await repository.checkout(id);
      if (!mounted) return;
      _automaticChecks = 0;
      state = state.copy(
        order: order,
        status: 'PENDING',
        busy: false,
        lastPackageId: id,
        clearLastCheckedAt: true,
      );
      _schedule();
    } catch (error) {
      if (mounted) {
        state = state.copy(
          busy: false,
          needsReview: true,
          failure: const AppFailure(
            'Chưa xác định được kết quả tạo đơn. Tải lại lịch sử gói để kiểm tra đơn trước khi thử tiếp.',
          ),
        );
      }
    }
  }

  void active(bool value) {
    _active = value;
    _poll?.cancel();
    if (value) _schedule();
  }

  void _schedule() {
    _poll?.cancel();
    if (mounted &&
        _active &&
        _automaticChecks < 180 &&
        state.order != null &&
        state.status == 'PENDING') {
      _poll = Timer(const Duration(seconds: 5), () {
        _automaticChecks++;
        unawaited(check());
      });
    }
  }

  Future<void> check({bool manual = false}) async {
    final order = state.order;
    if (!authenticated ||
        order == null ||
        state.checking ||
        state.status != 'PENDING') {
      return;
    }
    _poll?.cancel();
    state = state.copy(checking: true);
    try {
      final result = await repository.status(order.code);
      if (!mounted || state.order?.code != order.code) return;
      final status = requiredText(result, 'status');
      if (!{'PENDING', 'SUCCESS', 'CANCELLED', 'EXPIRED'}.contains(status)) {
        throw const FormatException('Invalid payment status');
      }
      if (result['orderCode'] != order.code ||
          paymentAmount(result['amount']) != order.amount) {
        throw const FormatException('Mismatched order');
      }
      final scheduled =
          status == 'SUCCESS' && result['isEffectiveNow'] == false;
      state = state.copy(
        status: status,
        checking: false,
        lastCheckedAt: DateTime.now(),
        scheduledPayment: scheduled,
        pendingNotice: status == 'PENDING' && manual
            ? state.pendingNotice + 1
            : null,
      );
      // Trạng thái cuối (SUCCESS/EXPIRED/CANCELLED): refresh lịch sử ngay để
      // hasPendingPayment không còn kẹt ở đơn cũ (cho phép "Tạo lại mã" hoặc
      // tạo đơn mới ngay từ màn kết quả).
      if (status != 'PENDING') {
        await load();
        if (status == 'SUCCESS' && !scheduled) onPaymentSuccess?.call();
      }
      _schedule();
    } catch (error) {
      if (mounted && state.order?.code == order.code) {
        state = state.copy(
          checking: false,
          failure: AppFailure.from(error),
          lastCheckedAt: DateTime.now(),
        );
      }
      // Stop automatic checks after a network failure; allow an explicit retry.
    }
  }

  /// Mở lại màn thanh toán cho một đơn "Chờ thanh toán" còn hiệu lực trong
  /// lịch sử (người dùng lỡ thoát giữa chừng mà cửa sổ QR 15 phút chưa hết):
  /// tái dùng đúng payload QR của đơn cũ thay vì tạo đơn mới. Đơn đã hủy/hết
  /// hạn → chỉ báo message và refresh lịch sử để thẻ gói mở khóa lại.
  Future<void> resumePayment(String orderCode) async {
    if (!authenticated ||
        state.busy ||
        state.loading ||
        state.resuming ||
        state.needsReview ||
        state.order != null) {
      return;
    }
    state = state.copy(resuming: true);
    try {
      final json = await repository.resume(orderCode);
      if (!mounted) return;
      if (requiredText(json, 'orderCode') != orderCode) {
        throw const FormatException('Mismatched order');
      }
      if (json['success'] != true) {
        state = state.copy(
          resuming: false,
          resumeNotice: state.resumeNotice + 1,
          failure: AppFailure(
            optionalText(json['message']) ??
                'Đơn không còn hiệu lực để thanh toán. Hãy tạo đơn mới.',
          ),
        );
        await load();
        return;
      }
      final order = PaymentOrder.fromJson(json);
      final status = requiredText(json, 'status');
      _automaticChecks = 0;
      state = state.copy(
        order: order,
        status: status,
        resuming: false,
        clearLastCheckedAt: true,
      );
      if (status == 'PENDING') {
        _schedule();
      } else {
        // Đã được thanh toán trong lúc người dùng vắng mặt.
        await load();
        if (status == 'SUCCESS' && json['isEffectiveNow'] != false) {
          onPaymentSuccess?.call();
        }
      }
    } catch (error) {
      if (mounted) {
        state = state.copy(
          resuming: false,
          resumeNotice: state.resumeNotice + 1,
          failure: AppFailure.from(error),
        );
      }
    }
  }

  /// Tạo lại mã thanh toán cho cùng gói sau khi đơn cũ hết hạn/bị hủy
  /// (parity với "Tạo lại mã thanh toán mới" trên web). Fallback sang
  /// packageId của đơn đang mở để hoạt động cả với đơn đã resume lại.
  Future<void> recreateOrder() async {
    final packageId = state.lastPackageId ?? state.order?.packageId;
    if (!authenticated ||
        packageId == null ||
        state.busy ||
        state.loading ||
        state.needsReview) {
      return;
    }
    _poll?.cancel();
    state = state.copy(clearOrder: true, status: '', checking: false);
    await checkout(packageId);
  }

  Future<void> refreshPayment(PaymentReceipt payment) async {
    if (!authenticated || state.busy || state.loading || state.order != null) {
      return;
    }
    state = state.copy(busy: true);
    try {
      final result = await repository.status(payment.code);
      if (!mounted) return;
      if (result['orderCode'] != payment.code ||
          paymentAmount(result['amount']) != payment.amount) {
        throw const FormatException('Mismatched order');
      }
      state = state.copy(busy: false);
      await load();
      if (requiredText(result, 'status') == 'SUCCESS') {
        onPaymentSuccess?.call();
      }
    } catch (error) {
      if (mounted) {
        state = state.copy(busy: false, failure: AppFailure.from(error));
      }
    }
  }

  void closeCheckout() {
    _poll?.cancel();
    state = state.copy(
      clearOrder: true,
      status: '',
      checking: false,
      clearLastCheckedAt: true,
    );
    unawaited(load());
  }

  Future<void> cancel(String id) async {
    if (!authenticated || state.busy || state.loading) return;
    state = state.copy(busy: true);
    try {
      await repository.cancel(id);
      if (!mounted) return;
      state = state.copy(busy: false);
      await load();
    } catch (error) {
      if (mounted) {
        state = state.copy(busy: false, failure: AppFailure.from(error));
      }
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
