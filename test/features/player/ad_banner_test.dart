import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moodify_flutter/features/player/data/ad_policy.dart';
import 'package:moodify_flutter/app/bootstrap.dart';
import 'package:moodify_flutter/core/config/app_config.dart';
import 'package:moodify_flutter/features/auth/presentation/session_controller.dart';
import 'package:moodify_flutter/features/player/presentation/player_controller.dart';
import 'package:moodify_flutter/features/player/presentation/player_screen.dart';

import '../../support/auth_harness.dart';
import '../../support/music_harness.dart';

class TestAdPolicy extends AdPolicyService {
  TestAdPolicy({this.canSkip = true}) : super(Dio(), MemoryStore(), 'test');
  final bool canSkip;
  @override
  Future<AdDecision> decide(String? userId) async => AdDecision(true, canSkip);
}

void main() {
  for (final canSkip in [true, false]) {
    testWidgets(
      'ad banner fits small viewport with large text, canSkip=$canSkip',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.8;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repository = MusicRepositoryFake();
        final engine = PlaybackEngineFake();
        final player = PlayerController(
          repository,
          () async => engine,
          adPolicy: TestAdPolicy(canSkip: canSkip),
        );
        await player.select([firstTrack], 0);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWithValue(
                AppConfig(
                  apiBaseUrl: 'https://api.example.test',
                  premiumWebUrl: 'https://example.test/dashboard/premium',
                ),
              ),
              playerControllerProvider.overrideWith((ref) => player),
            ],
            child: const MaterialApp(
              home: Scaffold(bottomNavigationBar: MiniPlayer()),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Quảng cáo'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        repository.remote.dio.close();
      },
    );
  }
  testWidgets(
    'upgrade opens the in-app subscriptions screen and keeps the ad',
    (tester) async {
      final repository = MusicRepositoryFake();
      final engine = PlaybackEngineFake();
      final auth = AuthHarness();
      final player = PlayerController(
        repository,
        () async => engine,
        adPolicy: TestAdPolicy(),
      );
      await player.select([firstTrack], 0);
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) =>
                const Scaffold(bottomNavigationBar: MiniPlayer()),
          ),
          GoRoute(
            path: '/subscriptions',
            builder: (_, _) => const Scaffold(body: Text('Gói dịch vụ')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(auth.repository),
            playerControllerProvider.overrideWith((ref) => player),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('Lên FULL'));
      await tester.pumpAndSettle();
      expect(find.text('Gói dịch vụ'), findsOneWidget);
      // Điều hướng trong app không tự skip quảng cáo như luồng mở web cũ.
      expect(player.state.isAd, isTrue);
      expect(engine.loaded, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await auth.close();
      repository.remote.dio.close();
    },
  );
}
