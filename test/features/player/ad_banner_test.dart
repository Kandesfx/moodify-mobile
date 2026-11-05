import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/player/data/ad_policy.dart';
import 'package:moodify_flutter/app/bootstrap.dart';
import 'package:moodify_flutter/core/config/app_config.dart';
import 'package:moodify_flutter/features/player/presentation/player_controller.dart';
import 'package:moodify_flutter/features/player/presentation/player_screen.dart';

import '../../support/auth_harness.dart' show MemoryStore;
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
  for (final launchSucceeds in [true, false]) {
    testWidgets(
      'upgrade opens web and only skips current ad when launch succeeds: $launchSucceeds',
      (tester) async {
        final repository = MusicRepositoryFake();
        final engine = PlaybackEngineFake();
        final player = PlayerController(
          repository,
          () async => engine,
          adPolicy: TestAdPolicy(),
        );
        await player.select([firstTrack], 0);
        Uri? opened;
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
              premiumUrlLauncherProvider.overrideWithValue((uri) async {
                opened = uri;
                return launchSucceeds;
              }),
            ],
            child: const MaterialApp(
              home: Scaffold(bottomNavigationBar: MiniPlayer()),
            ),
          ),
        );
        await tester.tap(find.text('Lên FULL'));
        await tester.pumpAndSettle();
        expect(opened.toString(), 'https://example.test/dashboard/premium');
        expect(player.state.isAd, !launchSucceeds);
        expect(engine.loaded, launchSucceeds ? [firstTrack.id] : isEmpty);
        if (!launchSucceeds) {
          expect(
            find.text('Không mở được trang nâng cấp. Vui lòng thử lại.'),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        repository.remote.dio.close();
      },
    );
  }
}
