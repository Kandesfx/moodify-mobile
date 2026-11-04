import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../../core/widgets/feedback_panel.dart';
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
      appBar: AppBar(title: const BrandLockup()),
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
                    const SizedBox(height: 24),
                    Text(
                      'Tài khoản',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      user.fullName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '@${user.username}',
                      style: const TextStyle(color: AppColors.secondary),
                    ),
                    const SizedBox(height: 24),
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
                      label: const Text('Cập nhật thông tin'),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(sessionControllerProvider.notifier).logout(),
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
