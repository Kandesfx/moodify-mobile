import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/app/app.dart';
import 'package:moodify_flutter/app/bootstrap.dart';
import 'package:moodify_flutter/core/widgets/brand_splash.dart';
import 'package:moodify_flutter/features/auth/domain/auth_session.dart';
import 'package:moodify_flutter/features/auth/presentation/session_controller.dart';
import 'package:moodify_flutter/features/catalog/data/catalog_repository.dart';
import 'package:moodify_flutter/features/catalog/presentation/catalog_controller.dart';
import 'package:moodify_flutter/features/player/presentation/player_controller.dart';

import '../support/auth_harness.dart';
import '../support/music_harness.dart';

void main() {
  testWidgets(
    'splash waits for non-zero viewport, animates logo on launch, waits for session restore, and unmounts cleanly',
    (tester) async {
      final profileGate = Completer<ResponseBody>();
      final auth = AuthHarness(
        handler: (request) => request.uri.path == '/api/auth/me'
            ? profileGate.future
            : AuthHarness.defaultResponse(request),
      );
      final music = MusicRepositoryFake();
      final engine = PlaybackEngineFake();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        final closed = auth.close();
        await tester.pump();
        await closed;
        music.remote.dio.close();
      });

      await auth.storage.write(
        AuthSession.fromAuthResponse(authResponse(), auth.now),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(auth.config),
            sessionRepositoryProvider.overrideWithValue(auth.repository),
            catalogRepositoryProvider.overrideWithValue(music),
            playbackEngineFactoryProvider.overrideWithValue(() async => engine),
            albumsProvider.overrideWith((ref) async => []),
            artistsProvider.overrideWith((ref, query) async => []),
          ],
          child: const MoodifyApp(),
        ),
      );

      // Frame 0: Splash overlay is active and starts after post-frame callback.
      expect(find.byType(SplashLaunchGate), findsOneWidget);
      expect(find.byType(BrandSplashHero), findsWidgets);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      final midHero = tester.widgetList<BrandSplashHero>(
        find.byType(BrandSplashHero),
      );
      expect(
        midHero.any((hero) => hero.progress > 0.2 && hero.progress < 0.9),
        isTrue,
      );

      // Entrance finishes at 1850ms, but splash stays up while profile restore is pending.
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.bySemanticsLabel('Đang khôi phục phiên'), findsWidgets);

      // Complete profile verification; splash fades out and unmounts.
      profileGate.complete(jsonResponse(profileResponse()));
      await tester.pumpAndSettle();

      expect(find.byType(BrandSplashHero), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion skips splash delay and small viewport/large text do not overflow',
    (tester) async {
      final auth = AuthHarness();
      final music = MusicRepositoryFake();
      final engine = PlaybackEngineFake();
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        final closed = auth.close();
        await tester.pump();
        await closed;
        music.remote.dio.close();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(auth.config),
            sessionRepositoryProvider.overrideWithValue(auth.repository),
            catalogRepositoryProvider.overrideWithValue(music),
            playbackEngineFactoryProvider.overrideWithValue(() async => engine),
            albumsProvider.overrideWith((ref) async => []),
            artistsProvider.overrideWith((ref, query) async => []),
          ],
          child: const MoodifyApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(BrandSplashHero), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
