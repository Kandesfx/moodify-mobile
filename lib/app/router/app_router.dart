import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/brand_lockup.dart';
import '../../core/widgets/app_motion.dart';
import '../../core/widgets/feedback_panel.dart';
import '../../features/auth/domain/session_state.dart';
import '../../features/auth/presentation/account_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/session_controller.dart';
import '../../features/catalog/presentation/detail_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/notifications/presentation/notification_screen.dart';
import '../../features/subscriptions/presentation/subscription_screen.dart';
import '../../features/offline/presentation/offline_screen.dart';
import '../main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(sessionControllerProvider, (_, _) => refresh.notify());
  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, route) {
      final session = ref.read(sessionControllerProvider);
      final path = route.uri.path;
      if (session.phase == SessionPhase.restoring ||
          session.phase == SessionPhase.restoreFailed) {
        if (session.phase == SessionPhase.restoreFailed &&
            session.offlineUserId != null &&
            (path == '/offline' || path == '/player')) {
          return null;
        }
        return path == '/restoring'
            ? null
            : Uri(
                path: '/restoring',
                queryParameters: {'from': _destination(route.uri)},
              ).toString();
      }
      if (session.phase == SessionPhase.signedOut) {
        return path == '/restoring' ? _destination(route.uri) : null;
      }
      if (path == '/sign-in' || path == '/sign-up' || path == '/restoring') {
        return _destination(route.uri);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/home'),
      GoRoute(path: '/restoring', builder: (_, _) => const _RestoringScreen()),
      GoRoute(
        path: '/sign-in',
        builder: (_, route) => AuthScreen(
          key: const ValueKey('sign-in'),
          returnTo: _destination(route.uri),
        ),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (_, route) => AuthScreen(
          key: const ValueKey('sign-up'),
          register: true,
          returnTo: _destination(route.uri),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigation) => MainShell(navigation: navigation),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (_, _) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (_, _) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/player',
        pageBuilder: (context, route) =>
            _slidePage(context, route, const PlayerScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, route) =>
            _slidePage(context, route, const NotificationScreen()),
      ),
      GoRoute(
        path: '/subscriptions',
        pageBuilder: (context, route) =>
            _slidePage(context, route, const SubscriptionScreen()),
      ),
      GoRoute(
        path: '/offline',
        pageBuilder: (context, route) =>
            _slidePage(context, route, const OfflineScreen()),
      ),
      GoRoute(
        path: '/album/:id',
        pageBuilder: (context, route) => _slidePage(
          context,
          route,
          CollectionScreen(id: route.pathParameters['id']!, album: true),
        ),
      ),
      GoRoute(
        path: '/playlist/:id',
        pageBuilder: (context, route) => _slidePage(
          context,
          route,
          CollectionScreen(id: route.pathParameters['id']!, album: false),
        ),
      ),
      GoRoute(
        path: '/artist/:id',
        pageBuilder: (context, route) => _slidePage(
          context,
          route,
          ArtistScreen(
            id: route.pathParameters['id']!,
            name: route.uri.queryParameters['name'] ?? 'Nghệ sĩ',
          ),
        ),
      ),
    ],
    errorBuilder: (context, _) => Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Không tìm thấy trang này.'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

// Only destinations implemented by this app may be restored after authentication.
CustomTransitionPage<void> _slidePage(
  BuildContext context,
  GoRouterState route,
  Widget child,
) => CustomTransitionPage<void>(
  key: route.pageKey,
  transitionDuration: AppMotion.duration(context, 320),
  reverseTransitionDuration: AppMotion.duration(context, 240),
  child: child,
  transitionsBuilder: (_, animation, _, child) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        ),
    child: child,
  ),
);

String _destination(Uri uri) {
  final requested = uri.queryParameters['from'] ?? uri.path;
  final parsed = Uri.tryParse(requested);
  if (parsed == null ||
      parsed.hasAuthority ||
      parsed.hasScheme ||
      parsed.hasFragment) {
    return '/home';
  }
  if (const {
        '/home',
        '/search',
        '/library',
        '/account',
        '/player',
        '/notifications',
        '/subscriptions',
        '/offline',
      }.contains(parsed.path) ||
      RegExp(r'^/(album|playlist|artist)/[^/]+$').hasMatch(parsed.path)) {
    return parsed.toString();
  }
  return '/home';
}

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _RestoringScreen extends ConsumerWidget {
  const _RestoringScreen();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionControllerProvider);
    final controller = ref.read(sessionControllerProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLockup(large: true),
                  const SizedBox(height: 32),
                  if (state.phase == SessionPhase.restoreFailed) ...[
                    FeedbackPanel(message: state.failure!.message),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: controller.restore,
                      child: const Text('Thử lại'),
                    ),
                    TextButton(
                      onPressed: controller.logout,
                      child: const Text('Xóa phiên và đăng nhập lại'),
                    ),
                    if (state.offlineUserId != null)
                      OutlinedButton.icon(
                        onPressed: () => context.push('/offline'),
                        icon: const Icon(Icons.download_for_offline_outlined),
                        label: const Text('Nghe nhạc đã tải'),
                      ),
                  ] else
                    const CircularProgressIndicator(
                      semanticsLabel: 'Đang khôi phục phiên',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
