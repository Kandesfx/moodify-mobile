import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/brand_lockup.dart';
import '../core/widgets/brand_splash.dart';
import '../core/widgets/feedback_panel.dart';
import '../features/auth/domain/session_state.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/notifications/data/fcm_service.dart';
import '../features/notifications/data/notification_repository.dart';
import '../features/notifications/presentation/notification_screen.dart';
import '../features/offline/presentation/offline_controller.dart';
import '../features/player/presentation/player_controller.dart';
import '../features/subscriptions/application/premium_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class MoodifyApp extends ConsumerStatefulWidget {
  const MoodifyApp({super.key});
  @override
  ConsumerState<MoodifyApp> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<MoodifyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(
      () => ref.read(sessionControllerProvider.notifier).restore(),
    );
    Future.microtask(
      () => ref.read(notificationAlertServiceProvider).ensurePermission(),
    );
    Future.microtask(
      () => ref
          .read(fcmServiceProvider)
          .initialize(
            alertService: ref.read(notificationAlertServiceProvider),
            onNewAlert: (item) {
              ref.read(latestNotificationAlertProvider.notifier).state = item;
            },
            onMarkSeen: ({id, title, message}) {
              ref
                  .read(inboxProvider.notifier)
                  .markSeen(id: id, title: title, message: message);
            },
          ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(sessionControllerProvider).phase == SessionPhase.signedIn) {
      unawaited(ref.read(sessionControllerProvider.notifier).refreshProfile());
      // Bắt kịp thay đổi gói khi app rời nền: mua trên web, gia hạn hoặc
      // gói hết hạn trong lúc thiết bị im lặng.
      unawaited(ref.read(premiumProvider.notifier).refresh());
      unawaited(_verifyOffline());
      if (!InboxController.isWidgetTest) {
        unawaited(ref.read(inboxProvider.notifier).load());
      }
    }
  }

  Future<void> _verifyOffline() async {
    await ref.read(offlineControllerProvider.notifier).load(verify: true);
    if (!mounted) return;
    final player = ref.read(playerControllerProvider);
    final entries = ref.read(offlineControllerProvider).entries;
    if (player.offline &&
        !entries.any((e) => e.track.id == player.track?.id && !e.expired)) {
      await ref.read(playerControllerProvider.notifier).clear();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the account-scoped offline service alive so logout also purges files
    // when the download screen has not been opened during this app session.
    ref.watch(offlinePlaybackAccessProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Moodify',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('vi'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('vi'), Locale('en')],
      routerConfig: router,
      builder: (context, child) => SplashLaunchGate(
        child: NotificationToastOverlay(
          onOpenNotifications: () => router.push('/notifications'),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class ConfigurationApp extends StatelessWidget {
  const ConfigurationApp({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Moodify',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandLockup(large: true),
                  const SizedBox(height: 36),
                  Text(
                    'Cấu hình kết nối chưa hợp lệ',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FeedbackPanel(message: message),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 18,
                              color: AppColors.lavender,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Hướng dẫn khắc phục',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          '1. Môi trường Production (máy thật/máy ảo):\n'
                          '   flutter run --dart-define-from-file=config/production.json\n\n'
                          '2. Môi trường Cục bộ (Local backend):\n'
                          '   flutter run --dart-define-from-file=config/local/development.json\n\n'
                          '3. Khởi chạy nhanh bằng công cụ script:\n'
                          '   Chạy file run.bat trong thư mục dự án.\n\n'
                          'Xem thêm chi tiết tại tài liệu README.md.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.secondary,
                                height: 1.55,
                              ),
                        ),
                      ],
                    ),
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
