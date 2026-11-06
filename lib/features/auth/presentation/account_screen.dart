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
                        color: isPremium ? null : AppColors.surfaceRaised,
                        gradient: isPremium
                            ? const LinearGradient(
                                colors: [
                                  AppColors.vipGradientTop,
                                  AppColors.vipGradientBottom,
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPremium
                              ? AppColors.vipBorder
                              : AppColors.borderSoft,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPremium
                                ? Icons.workspace_premium_rounded
                                : Icons.tune_rounded,
                            color: isPremium ? AppColors.vipGold : Colors.white,
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
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceGlass,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderSoft),
                              ),
                              child: const Icon(
                                Icons.manage_accounts_outlined,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                            title: const Text(
                              'Quản lý tài khoản',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Chỉnh sửa thông tin cá nhân',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.secondary,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/profile'),
                          ),
                          const Divider(height: 1, indent: 68),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isPremium
                                    ? const Color(0xFF332918)
                                    : AppColors.surfaceGlass,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isPremium
                                      ? AppColors.vipBorder
                                      : AppColors.borderSoft,
                                ),
                              ),
                              child: Icon(
                                Icons.workspace_premium_outlined,
                                color: isPremium
                                    ? AppColors.vipGold
                                    : Colors.white,
                                size: 21,
                              ),
                            ),
                            title: Text(
                              isPremium ? 'Quản lý gói dịch vụ' : 'Gói dịch vụ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              isPremium
                                  ? 'Gói đang dùng, gia hạn và thanh toán'
                                  : 'Gói miễn phí — Nâng cấp VIP',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.secondary,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/subscriptions'),
                          ),
                          const Divider(height: 1, indent: 68),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceGlass,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderSoft),
                              ),
                              child: const Icon(
                                Icons.download_for_offline_outlined,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                            title: const Text(
                              'Nhạc đã tải',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Bộ nhớ và bản quyền trên thiết bị',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.secondary,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/offline'),
                          ),
                          const Divider(height: 1, indent: 68),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceGlass,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderSoft),
                              ),
                              child: const Icon(
                                Icons.devices,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                            title: const Text(
                              'Thiết bị đăng nhập',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/devices'),
                          ),
                          const Divider(height: 1, indent: 68),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceGlass,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderSoft),
                              ),
                              child: const Icon(
                                Icons.history_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                            title: const Text(
                              'Lịch sử nghe',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Các bài đã nghe trên tài khoản',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.secondary,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/history'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
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
