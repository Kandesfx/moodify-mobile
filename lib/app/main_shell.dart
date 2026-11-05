import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/player/presentation/player_screen.dart';
import '../features/subscriptions/application/premium_controller.dart';
import '../core/widgets/app_motion.dart';
import 'theme/app_theme.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigation});
  final StatefulNavigationShell navigation;
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );
  late int _index;
  @override
  void initState() {
    super.initState();
    _index = widget.navigation.currentIndex;
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index != widget.navigation.currentIndex) {
      _index = widget.navigation.currentIndex;
      _fade.duration = AppMotion.duration(context, 180);
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Gói VIP đang hiệu lực → điểm nhấn chuyển sang tông vàng Hoàng Kim.
    final isPremium = ref.watch(premiumProvider.select((s) => s.isPremium));
    final accent = isPremium ? AppColors.vipGold : AppColors.primary;
    return Scaffold(
      body: FadeTransition(
        opacity: Tween<double>(
          begin: .65,
          end: 1,
        ).animate(CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic)),
        child: widget.navigation,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (MediaQuery.disableAnimationsOf(context))
            const MiniPlayer()
          else
            AnimatedSize(
              duration: AppMotion.duration(context),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: const MiniPlayer(),
            ),
          // NavigationBar của SDK này không có tham số iconTheme riêng;
          // màu icon tab được theme qua NavigationBarThemeData bọc ngoài.
          NavigationBarTheme(
            data: NavigationBarThemeData(
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  size: 22,
                  color: states.contains(WidgetState.selected)
                      ? accent
                      : AppColors.secondary,
                ),
              ),
            ),
            child: NavigationBar(
              height: 64,
              backgroundColor: AppColors.background,
              indicatorColor: Colors.transparent,
              selectedIndex: widget.navigation.currentIndex,
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: states.contains(WidgetState.selected)
                      ? (isPremium ? AppColors.vipGold : AppColors.lavender)
                      : AppColors.secondary,
                ),
              ),
              overlayColor: WidgetStatePropertyAll(
                accent.withValues(alpha: .08),
              ),
              onDestinationSelected: (index) {
                if (widget.navigation.currentIndex == 2 && index != 2) {
                  // Release karaoke screens, microphone and room timers on tab exit.
                  widget.navigation.goBranch(2, initialLocation: true);
                }
                widget.navigation.goBranch(
                  index,
                  initialLocation: index == widget.navigation.currentIndex,
                );
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Trang chủ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_rounded),
                  label: 'Tìm kiếm',
                ),
                NavigationDestination(
                  icon: Icon(Icons.mic_none_rounded),
                  selectedIcon: Icon(Icons.mic_rounded),
                  label: 'Karaoke',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded),
                  label: 'Thư viện',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Tài khoản',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
