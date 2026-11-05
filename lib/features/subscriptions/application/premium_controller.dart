import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_controller.dart';
import '../data/subscription_repository.dart';
import '../domain/subscription_models.dart';

/// Trạng thái VIP toàn app — nguồn duy nhất để các màn hình phân biệt giao
/// diện trước/sau khi active gói (đối tác mobile của event
/// "moodify-subscription-updated" bên web).
class PremiumState {
  const PremiumState({this.info, this.loading = false});
  final SubscriptionInfo? info;
  final bool loading;

  bool get isPremium => info?.premium ?? false;
  String get tier => info?.tier ?? 'FREE';
  int get daysRemaining => info?.daysRemaining ?? 0;
  String? get packageName => info?.name;
}

class PremiumController extends Notifier<PremiumState> {
  SubscriptionRepository get _repository =>
      ref.read(subscriptionRepositoryProvider);

  // Bảo vệ race: phản hồi của lần fetch cũ (hoặc của phiên cũ) không được
  // ghi đè trạng thái mới.
  int _generation = 0;

  @override
  PremiumState build() {
    final userId = ref.watch(
      sessionControllerProvider.select((s) => s.session?.user.id),
    );
    // Đổi phiên (đăng nhập/đăng xuất/đổi tài khoản) → vô hiệu fetch đang bay.
    _generation++;
    if (userId == null) return const PremiumState();
    unawaited(Future.microtask(refresh));
    return const PremiumState();
  }

  /// Tải lại trạng thái gói từ `subscriptions/me`: gọi sau khi thanh toán
  /// thành công, khi app quay lại foreground hoặc khi pull-to-refresh.
  Future<void> refresh() async {
    final signedIn = ref.read(
      sessionControllerProvider.select((s) => s.session?.user.id != null),
    );
    if (!signedIn) {
      _generation++;
      state = const PremiumState();
      return;
    }
    final generation = ++_generation;
    state = PremiumState(info: state.info, loading: true);
    try {
      final info = await _repository.current();
      if (generation == _generation) {
        state = PremiumState(info: info);
      }
    } catch (_) {
      // Lỗi mạng: giữ nhận định cũ (không lật UI về free oan) và tắt loading.
      if (generation == _generation) {
        state = PremiumState(info: state.info);
      }
    }
  }
}

final premiumProvider =
    NotifierProvider<PremiumController, PremiumState>(PremiumController.new);
