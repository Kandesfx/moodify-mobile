import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/player/presentation/player_screen.dart';
import 'theme/app_theme.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigation});
  final StatefulNavigationShell navigation;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigation,
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MiniPlayer(),
        NavigationBar(
          backgroundColor: AppColors.background,
          indicatorColor: AppColors.surfaceRaised,
          selectedIndex: navigation.currentIndex,
          onDestinationSelected: (index) => navigation.goBranch(
            index,
            initialLocation: index == navigation.currentIndex,
          ),
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
