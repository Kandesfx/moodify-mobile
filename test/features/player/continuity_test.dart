import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moodify_flutter/features/player/presentation/lyrics_screen.dart';
import 'package:moodify_flutter/app/app.dart';
import 'package:moodify_flutter/app/bootstrap.dart';
import 'package:moodify_flutter/app/router/app_router.dart';
import 'package:moodify_flutter/features/auth/presentation/session_controller.dart';
import 'package:moodify_flutter/features/catalog/data/catalog_repository.dart';
import 'package:moodify_flutter/features/catalog/domain/catalog_models.dart';
import 'package:moodify_flutter/features/catalog/presentation/catalog_controller.dart';
import 'package:moodify_flutter/features/library/presentation/pending_track_action.dart';
import 'package:moodify_flutter/features/player/data/playback_engine.dart';
import 'package:moodify_flutter/features/player/presentation/player_controller.dart';
import 'package:moodify_flutter/features/player/presentation/player_screen.dart';
import 'package:moodify_flutter/features/player/presentation/player_sheets.dart';
import '../../support/auth_harness.dart';
import '../../support/music_harness.dart';

void main() {
  test(
    'timed lyrics in the plain field are used when synced field is absent',
    () async {
      final repository = MusicRepositoryFake();
      final engine = PlaybackEngineFake();
      const track = Track(
        id: 'timed-plain',
        spotifyId: 'timed-plain',
        name: 'Timed lyrics',
        artist: 'Artist',
        localPath: 'audio.mp3',
        lyrics: '[00:12.50]Câu hát',
      );
      repository.onTrack = (_) async => track;
      final player = PlayerController(repository, () async => engine);
      await player.select([track], 0);
      final container = ProviderContainer(
        overrides: [playerControllerProvider.overrideWith((ref) => player)],
      );
      final lines = container.read(playerLyricLinesProvider);
      expect(lines.single.at, const Duration(milliseconds: 12500));
      expect(lines.single.text, 'Câu hát');
      container.dispose();
      await flushMusic();
      repository.remote.dio.close();
    },
  );

  test(
    'queue next and removal preserve active source, position and one engine',
    () async {
      final repository = MusicRepositoryFake();
      final engine = PlaybackEngineFake();
      final player = PlayerController(repository, () async => engine);
      await player.select([firstTrack], 0, source: 'HOME');
      engine.controller.add(
        const EngineEvent(playing: true, position: Duration(seconds: 12)),
      );
      expect(await player.enqueue(secondTrack, next: true), true);
      expect(player.current.position, const Duration(seconds: 12));
      expect(player.current.source, 'HOME');
      expect(engine.loaded, [firstTrack.id]);
      expect(await player.enqueue(secondTrack), false);
      expect(player.removeUpcoming(0), false);
      expect(player.removeUpcoming(1), true);
      expect(player.current.queue, [firstTrack]);
      player.dispose();
      await flushMusic();
      repository.remote.dio.close();
    },
  );

  testWidgets(
    'details retain mini player; pending guest action survives login and clears on logout',
    (tester) async {
      final auth = AuthHarness();
      final repository = MusicRepositoryFake();
      final engine = PlaybackEngineFake();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiDioProvider.overrideWithValue(auth.dio),
            authDioProvider.overrideWithValue(auth.dio),
            appConfigProvider.overrideWithValue(auth.config),
            sessionRepositoryProvider.overrideWithValue(auth.repository),
            catalogRepositoryProvider.overrideWithValue(repository),
            playbackEngineFactoryProvider.overrideWithValue(() async => engine),
            albumsProvider.overrideWith((ref) async => []),
            artistsProvider.overrideWith((ref, query) async => []),
          ],
          child: const MoodifyApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MoodifyApp)),
      );
      await tester.runAsync(
        () => container.read(playerControllerProvider.notifier).select([
          firstTrack,
        ], 0),
      );
      container.read(appRouterProvider).go('/artist/artist-id?name=Artist');
      await tester.pumpAndSettle();
      expect(find.byType(MiniPlayer), findsOneWidget);
      await tester.tap(find.byType(BackButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      container.read(appRouterProvider).go('/artist/artist-id?name=Artist');
      await tester.pumpAndSettle();
      container.read(pendingTrackActionProvider.notifier).state =
          PendingTrackAction(firstTrack, 'playlist', '/home');
      container.read(appRouterProvider).go('/sign-in?from=%2Fcontinue-action');
      await tester.pumpAndSettle();
      final login = container
          .read(sessionControllerProvider.notifier)
          .login('user', 'password');
      await tester.pumpAndSettle();
      await login;
      expect(find.text('Chọn playlist'), findsOneWidget);
      expect(find.text(firstTrack.name), findsOneWidget);
      expect(
        container.read(pendingTrackActionProvider)?.track.id,
        firstTrack.id,
      );
      final logout = container
          .read(sessionControllerProvider.notifier)
          .logout();
      await tester.pumpAndSettle();
      await logout;
      expect(container.read(pendingTrackActionProvider), isNull);
      await tester.pumpWidget(const SizedBox());
      final closing = auth.close();
      await tester.pump();
      await closing;
      repository.remote.dio.close();
    },
  );

  testWidgets(
    'lyrics follow real position, allow manual scroll and recenter with reduced motion',
    (tester) async {
      final repository = MusicRepositoryFake();
      final engine = PlaybackEngineFake();
      final lyrics = List.generate(
        50,
        (i) => '[00:${i.toString().padLeft(2, '0')}]Line $i',
      ).join('\n');
      final track = Track(
        id: 'lyrics',
        spotifyId: 'lyrics',
        name: 'Lyrics test',
        artist: 'Artist',
        localPath: 'audio.mp3',
        lyricsSynced: lyrics,
      );
      repository.onTrack = (_) async => track;
      final player = PlayerController(repository, () async => engine);
      final selection = player.select([track], 0);
      await tester.pump();
      await selection;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerControllerProvider.overrideWith((ref) => player),
            catalogRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, _) => Scaffold(
                    body: TextButton(
                      onPressed: () => showPlayerLyrics(context),
                      child: const Text('Lyrics'),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/lyrics',
                  builder: (_, _) => const LyricsScreen(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Lyrics'));
      await tester.pumpAndSettle();
      engine.controller.add(
        const EngineEvent(playing: true, position: Duration(seconds: 40)),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Line 40'), findsOneWidget);
      expect(
        tester
            .widget<AnimatedDefaultTextStyle>(
              find
                  .ancestor(
                    of: find.text('Line 40'),
                    matching: find.byType(AnimatedDefaultTextStyle),
                  )
                  .first,
            )
            .style
            .color,
        const Color(0xFFFAFAFC),
      );
      expect(find.text('Xem gói dịch vụ'), findsNothing);
      final list = find.byType(ListView).last;
      await tester.drag(list, const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(find.text('Về câu đang phát'), findsOneWidget);
      await tester.tap(find.text('Về câu đang phát'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Về câu đang phát'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      repository.remote.dio.close();
    },
  );
}
