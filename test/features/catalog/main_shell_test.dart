import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/app/app.dart';
import 'package:moodify_flutter/app/bootstrap.dart';
import 'package:moodify_flutter/features/auth/presentation/session_controller.dart';
import 'package:moodify_flutter/features/catalog/data/catalog_repository.dart';
import 'package:moodify_flutter/features/catalog/presentation/catalog_controller.dart';
import 'package:moodify_flutter/features/catalog/presentation/catalog_widgets.dart';
import 'package:moodify_flutter/features/player/presentation/player_controller.dart';
import 'package:moodify_flutter/features/player/presentation/player_screen.dart';

import '../../support/auth_harness.dart';
import '../../support/music_harness.dart';

void main() {
  for (final largeText in [false, true]) {
    testWidgets(
      'guest browses and plays real repository results; largeText=$largeText',
      (tester) async {
        final auth = AuthHarness();
        final music = MusicRepositoryFake();
        final engine = PlaybackEngineFake();
        if (largeText) {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.8;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
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
              playbackEngineFactoryProvider.overrideWithValue(
                () async => engine,
              ),
              albumsProvider.overrideWith((ref) async => []),
              artistsProvider.overrideWith((ref, query) async => []),
            ],
            child: const MoodifyApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text('Nghe ngay'), findsOneWidget);
        final track = find.byType(TrackTile);
        await tester.scrollUntilVisible(
          track,
          180,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(track);
        await tester.pumpAndSettle();
        expect(engine.loaded, [firstTrack.id]);
        expect(find.byType(MiniPlayer), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(MiniPlayer),
            matching: find.text(firstTrack.name),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PlayerScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Thu nhỏ'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(NavigationDestination).at(2));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
        expect(auth.requests, isEmpty);
        await tester.tap(find.byType(NavigationDestination).at(1));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
