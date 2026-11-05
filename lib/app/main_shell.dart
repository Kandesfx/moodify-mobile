import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/player/presentation/player_screen.dart';
import '../core/widgets/app_motion.dart';
import 'theme/app_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigation});
  final StatefulNavigationShell navigation;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
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
  Widget build(BuildContext context) => Scaffold(
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
        NavigationBar(
          height: 64,
          backgroundColor: AppColors.background,
          indicatorColor: Colors.transparent,
          selectedIndex: widget.navigation.currentIndex,
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
      ],
    ),
  );
}
