import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/feedback_panel.dart';
import '../../../core/widgets/studio_banners.dart';
import 'session_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../subscriptions/application/premium_controller.dart';
import '../../app_update/data/app_update_service.dart';
import '../../app_update/presentation/app_update_dialog.dart';

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
    final installedVersion =
        ref.watch(appVersionProvider).valueOrNull?.versionName ?? '0.1.1';
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            ref.read(sessionControllerProvider.notifier).refreshProfile(),
            ref.read(premiumProvider.notifier).refresh(),
          ]),
          child: SectionEntrance(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isPremium
                                ? AppColors.vipBorder
                                : const Color(0x28FFFFFF),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.48,
                                  child: Image.asset(
                                    isPremium
                                        ? MoodifyWebAssets.audioExperienceBanner
                                        : MoodifyWebAssets.heroBannerWide,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.low,
                                    excludeFromSemantics: true,
                                    errorBuilder: (_, _, _) => const ColoredBox(
                                      color: AppColors.surfaceRaised,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: isPremium
                                          ? const [
                                              Color(0xEE241B0D),
                                              Color(0xD813121A),
                                            ]
                                          : const [
                                              Color(0xEE0C0E14),
                                              Color(0xCC171A24),
                                            ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: isPremium
                                            ? const Color(0x33F59E0B)
                                            : AppColors.surfaceGlass,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isPremium
                                              ? AppColors.vipBorder
                                              : AppColors.border,
                                        ),
                                      ),
                                      child: Icon(
                                        isPremium
                                            ? Icons.workspace_premium_rounded
                                            : Icons.tune_rounded,
                                        color: isPremium
                                            ? AppColors.vipGold
                                            : Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                  : Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            isPremium
                                                ? '${premium.packageName ?? 'Gói VIP'}'
                                                      ' • còn ${premium.daysRemaining} ngày'
                                                : 'Quản lý tài khoản và trải nghiệm nghe',
                                            style: const TextStyle(
                                              color: Color(0xFFD0D4E0),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!isPremium) ...[
                        const StudioVipAdBanner(
                          badge: 'ĐẶC QUYỀN MOODIFY VIP',
                          title: 'Nâng cấp tài khoản lên chuẩn Studio VIP',
                          subtitle:
                              'Nghe nhạc không quảng cáo, tải bài hát nghe offline và tìm kiếm theo cảm xúc.',
                          ctaLabel: 'Nâng cấp ngay',
                        ),
                        const SizedBox(height: 16),
                      ],
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
                                  border: Border.all(
                                    color: AppColors.borderSoft,
                                  ),
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
                                isPremium
                                    ? 'Quản lý gói dịch vụ'
                                    : 'Gói dịch vụ',
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
                                  border: Border.all(
                                    color: AppColors.borderSoft,
                                  ),
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
                                  border: Border.all(
                                    color: AppColors.borderSoft,
                                  ),
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
                                  border: Border.all(
                                    color: AppColors.borderSoft,
                                  ),
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
                                  border: Border.all(
                                    color: AppColors.borderSoft,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.system_update_rounded,
                                  color: Colors.white,
                                  size: 21,
                                ),
                              ),
                              title: const Text(
                                'Kiểm tra bản cập nhật',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'Phiên bản hiện tại: v$installedVersion',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.secondary,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Đang kiểm tra bản cập nhật...'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                                final service = ref.read(appUpdateServiceProvider);
                                final info = await service.checkForUpdate();
                                if (info != null) {
                                  if (context.mounted) {
                                    AppUpdateDialog.show(context, info, service: service);
                                  }
                                } else {
                                  messenger.hideCurrentSnackBar();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Ứng dụng đang ở phiên bản mới nhất (v$installedVersion)',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final scale = MediaQuery.textScalerOf(
                            context,
                          ).scale(1);
                          final twoCols =
                              constraints.maxWidth >= 300 && scale <= 1.35;
                          final w = twoCols
                              ? (constraints.maxWidth - 10) / 2
                              : constraints.maxWidth;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              SizedBox(
                                width: w,
                                child: StudioCoverTopicCard(
                                  title: 'Phòng thu Karaoke',
                                  subtitle: 'Hát solo & phòng hát trực tuyến',
                                  badge: 'STUDIO LIVE',
                                  imageAsset: MoodifyWebAssets.creatorStudio,
                                  onTap: () => context.go('/karaoke'),
                                ),
                              ),
                              SizedBox(
                                width: w,
                                child: StudioCoverTopicCard(
                                  title: 'Khám phá cảm xúc',
                                  subtitle: 'Tìm bài hát theo tâm trạng',
                                  badge: 'MOOD AI',
                                  imageAsset: MoodifyWebAssets.moodBanner,
                                  onTap: () => context.go('/search'),
                                ),
                              ),
                            ],
                          );
                        },
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
      ),
    );
  }
}
