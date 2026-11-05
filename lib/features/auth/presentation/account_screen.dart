import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/feedback_panel.dart';
import 'session_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../subscriptions/application/premium_controller.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionControllerProvider);
    final user = state.session?.user;
    if (user == null) {
      return const GuestPrompt(
        title: 'Tài khoản',
        message: 'Đăng nhập để quản lý tài khoản và thư viện nhạc của bạn.',
        returnTo: '/account',
      );
    }
    final premium = ref.watch(premiumProvider);
    final isPremium = premium.isPremium;
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            ref.read(sessionControllerProvider.notifier).refreshProfile(),
            ref.read(premiumProvider.notifier).refresh(),
          ]),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPremium
                              ? const [
                                  AppColors.vipGradientTop,
                                  AppColors.vipGradientBottom,
                                ]
                              : const [Color(0xFF34234F), Color(0xFF1D1C2B)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: isPremium
                            ? Border.all(color: AppColors.vipBorder)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPremium
                                ? Icons.workspace_premium_rounded
                                : Icons.tune_rounded,
                            color: isPremium
                                ? AppColors.vipGold
                                : AppColors.lavender,
                            size: 30,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isPremium
                                      ? 'Không gian VIP của bạn'
                                      : 'Không gian của bạn',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: isPremium
                                        ? AppColors.vipGoldSoft
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isPremium
                                      ? '${premium.packageName ?? 'Gói VIP'}'
                                            ' • còn ${premium.daysRemaining} ngày'
                                      : 'Quản lý tài khoản và trải nghiệm nghe',
                                  style: const TextStyle(
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.manage_accounts_outlined,
                        color: AppColors.lavender,
                      ),
                      title: const Text('Quản lý tài khoản'),
                      subtitle: const Text('Chỉnh sửa thông tin cá nhân'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/profile'),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.workspace_premium_outlined,
                        color: isPremium ? AppColors.vipGold : null,
                      ),
                      title: Text(isPremium ? 'Quản lý gói dịch vụ' : 'Gói dịch vụ'),
                      subtitle: Text(
                        isPremium
                            ? 'Gói đang dùng, gia hạn và thanh toán'
                            : 'Gói miễn phí — Nâng cấp VIP',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/subscriptions'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.download_for_offline_outlined),
                      title: const Text('Nhạc đã tải'),
                      subtitle: const Text('Bộ nhớ và bản quyền trên thiết bị'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/offline'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.devices),
                      title: const Text('Thiết bị đăng nhập'),
                      onTap: () => context.push('/devices'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.history_rounded),
                      title: const Text('Lịch sử nghe'),
                      subtitle: const Text('Các bài đã nghe trên tài khoản'),
                      onTap: () => context.push('/history'),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 24),
                    if (state.failure != null) ...[
                      FeedbackPanel(message: state.failure!.message),
                      const SizedBox(height: 16),
                    ],
                    TextButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Đăng xuất?'),
                            content: const Text(
                              'Nhạc đã tải và khóa offline của tài khoản sẽ được xóa khỏi thiết bị.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Ở lại'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Đăng xuất'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref
                              .read(sessionControllerProvider.notifier)
                              .logout();
                        }
                      },
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
