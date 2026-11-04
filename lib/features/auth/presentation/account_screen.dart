import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/feedback_panel.dart';
import '../../../core/widgets/app_motion.dart';
import 'session_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(sessionControllerProvider.notifier).refreshProfile(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionEntrance(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: Color(0xFF35264E),
                              child: Icon(
                                Icons.person_rounded,
                                size: 30,
                                color: AppColors.lavender,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.fullName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '@${user.username}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: const Text('Gói dịch vụ'),
                      subtitle: const Text(
                        'Gói hiện tại, gia hạn và thanh toán',
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
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.notifications_none_rounded),
                      title: const Text('Thông báo'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/notifications'),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    _detail(context, 'Email', user.email),
                    if (user.phone != null && user.phone!.isNotEmpty)
                      _detail(context, 'Số điện thoại', user.phone!),
                    const Divider(),
                    const SizedBox(height: 24),
                    if (state.notice != null) ...[
                      FeedbackPanel(message: state.notice!, isError: false),
                      const SizedBox(height: 16),
                    ],
                    if (state.failure != null) ...[
                      FeedbackPanel(message: state.failure!.message),
                      const SizedBox(height: 16),
                    ],
                    OutlinedButton.icon(
                      onPressed: state.isBusy
                          ? null
                          : () => ref
                                .read(sessionControllerProvider.notifier)
                                .refreshProfile(),
                      icon: state.isBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('Tải lại thông tin tài khoản'),
                    ),
                    const SizedBox(height: 12),
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

  Widget _detail(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
        ),
        const SizedBox(height: 6),
        SelectableText(value),
      ],
    ),
  );
}
