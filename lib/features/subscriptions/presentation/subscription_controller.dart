import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/domain/catalog_models.dart';
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
    this.needsReview = false,
    this.failure,
  });
  final SubscriptionInfo? current;
  final List<PackageQuote> quotes;
  final List<ManagedSubscription> management;
  final PaymentOrder? order;
  final String status;
  final bool loading, busy, checking, needsReview;
  bool get hasPendingPayment => management.any(
    (item) => item.payments.any((payment) => payment.status == 'PENDING'),
  );
  final AppFailure? failure;
  SubscriptionState copy({
    SubscriptionInfo? current,
    List<PackageQuote>? quotes,
    List<ManagedSubscription>? management,
    PaymentOrder? order,
    String? status,
    bool? loading,
    bool? busy,
    bool? checking,
    bool? needsReview,
    AppFailure? failure,
    bool clearOrder = false,
  }) => SubscriptionState(
    current: current ?? this.current,
    quotes: quotes ?? this.quotes,
    management: management ?? this.management,
    order: clearOrder ? null : order ?? this.order,
    status: status ?? this.status,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    checking: checking ?? this.checking,
    needsReview: needsReview ?? this.needsReview,
    failure: failure,
  );
}

class SubscriptionController extends StateNotifier<SubscriptionState> {
  SubscriptionController(this.repository, this.authenticated)
    : super(const SubscriptionState());
  final SubscriptionRepository repository;
  final bool authenticated;
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
      state = state.copy(order: order, status: 'PENDING', busy: false);
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

  Future<void> check() async {
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
      state = state.copy(status: status, checking: false);
      if (status == 'SUCCESS') await load();
      _schedule();
    } catch (error) {
      if (mounted && state.order?.code == order.code) {
        state = state.copy(checking: false, failure: AppFailure.from(error));
      }
      // Stop automatic checks after a network failure; allow an explicit retry.
    }
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
    } catch (error) {
      if (mounted) {
        state = state.copy(busy: false, failure: AppFailure.from(error));
      }
    }
  }

  void closeCheckout() {
    _poll?.cancel();
    state = state.copy(clearOrder: true, status: '', checking: false);
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
