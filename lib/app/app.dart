import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/brand_lockup.dart';
import '../core/widgets/feedback_panel.dart';
import '../features/auth/domain/session_state.dart';
import '../features/auth/presentation/session_controller.dart';
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(sessionControllerProvider).phase == SessionPhase.signedIn) {
      unawaited(ref.read(sessionControllerProvider.notifier).refreshProfile());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Moodify',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    locale: const Locale('vi'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('vi'), Locale('en')],
    routerConfig: ref.watch(appRouterProvider),
  );
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
                  const SizedBox(height: 40),
                  Text(
                    'Chưa thể kết nối',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  FeedbackPanel(message: message),
                  const SizedBox(height: 16),
                  const SelectableText(
                    'Cấu hình API_BASE_URL khi chạy ứng dụng.\n'
                    'Xem hướng dẫn môi trường trong README.md.',
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
