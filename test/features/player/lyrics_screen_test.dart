import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moodify_flutter/app/theme/app_theme.dart';
import 'package:moodify_flutter/features/catalog/data/catalog_repository.dart';
import 'package:moodify_flutter/features/catalog/domain/catalog_models.dart';
import 'package:moodify_flutter/features/player/data/playback_engine.dart';
import 'package:moodify_flutter/features/player/presentation/lyrics_screen.dart';
import 'package:moodify_flutter/features/player/presentation/player_controller.dart';
import 'package:moodify_flutter/features/player/presentation/player_sheets.dart';

import '../../support/music_harness.dart';

const timedTrack = Track(
  id: 'lyrics-screen-fixture',
  spotifyId: 'fixture',
  name: 'Bài hát kiểm thử lời đồng bộ',
  artist: 'Dữ liệu chỉ dùng trong test',
  localPath: 'fixture.mp3',
  lyricsSynced:
      '[00:20.00]Ngày mai ta lại đi cùng nhau\n[00:26.50]Qua những con đường đầy nắng\n[00:33.20]Giữ lấy một lời hẹn còn xanh\n[00:40.00]Dẫu mai này mình xa cách\n[00:48.00]Vẫn nhớ về ngày hôm nay',
);

class LyricsPlayerHarness extends PlayerController {
  LyricsPlayerHarness(super.repository, super.createEngine);
  void simulateAd() => state = state.copy(isAd: true, adCanSkip: false);
}

void main() {
  setUpAll(() async {
    final font = FontLoader('BeVietnamPro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$weight.ttf'));
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<(PlayerController, PlaybackEngineFake, GoRouter, MusicRepositoryFake)>
  mount(
    WidgetTester tester, {
    Track track = timedTrack,
    bool largeText = false,
  }) async {
    tester.view.physicalSize = largeText
        ? const Size(320, 640)
        : const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = largeText ? 1.8 : 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = MusicRepositoryFake()..onTrack = (_) async => track;
    final engine = PlaybackEngineFake();
    final player = LyricsPlayerHarness(repository, () async => engine);
    await player.select([track], 0);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showPlayerLyrics(context),
                child: const Text('Mở lyrics'),
              ),
            ),
          ),
        ),
        GoRoute(path: '/lyrics', builder: (_, _) => const LyricsScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(repository),
          playerControllerProvider.overrideWith((ref) => player),
        ],
        child: RepaintBoundary(
          key: const ValueKey('lyrics-capture'),
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở lyrics'));
    await tester.pumpAndSettle();
    return (player, engine, router, repository);
  }

  Future<void> close(
    WidgetTester tester,
    GoRouter router,
    MusicRepositoryFake repository,
  ) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    router.dispose();
    repository.remote.dio.close();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('LYRICS_CAPTURE')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('lyrics-capture')),
    );
    await tester.runAsync(() async {
      final bitmap = await boundary.toImage(pixelRatio: 2);
      final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      final folder = Directory('artifacts/lyrics-review');
      await folder.create(recursive: true);
      await File(
        '${folder.path}/test-render-$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      bitmap.dispose();
    });
  }

  testWidgets(
    'full lyrics follows engine, seeks measured cue and closes without reloading audio',
    (tester) async {
      final (player, engine, router, repository) = await mount(tester);
      expect(find.text('Nhạc dạo · Lời bắt đầu 0:20'), findsOneWidget);
      engine.controller.add(
        const EngineEvent(
          playing: true,
          position: Duration(seconds: 34),
          duration: Duration(minutes: 2),
        ),
      );
      await tester.pumpAndSettle();
      final line = find.text('Giữ lấy một lời hẹn còn xanh');
      expect(line, findsOneWidget);
      await capture(tester, 'synced');
      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(engine.sought, const Duration(milliseconds: 33200));
      expect(engine.loaded, hasLength(1));
      await tester.tap(find.byTooltip('Tạm dừng'));
      await tester.pumpAndSettle();
      expect(engine.pauses, 1);
      final position = player.current.position;
      await tester.tap(find.byTooltip('Đóng lời bài hát'));
      await tester.pumpAndSettle();
      expect(find.text('Mở lyrics'), findsOneWidget);
      expect(engine.loaded, hasLength(1));
      expect(player.current.position, position);
      await close(tester, router, repository);
    },
  );

  testWidgets(
    'guests use measured LRC from legacy plain field without subscription checks',
    (tester) async {
      final track = Track(
        id: 'legacy-lrc',
        spotifyId: 'fixture',
        name: 'Legacy LRC',
        artist: 'Test',
        localPath: 'fixture.mp3',
        lyrics: timedTrack.lyricsSynced,
      );
      final (_, engine, router, repository) = await mount(
        tester,
        track: track,
        largeText: true,
      );
      expect(find.byKey(const ValueKey('synced-lyrics-list')), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      expect(find.textContaining('Xem gói'), findsNothing);
      expect(engine.loaded, hasLength(1));
      expect(tester.takeException(), isNull);
      await close(tester, router, repository);
    },
  );

  testWidgets(
    'plain and absent lyrics have separate states, no synthetic timing',
    (tester) async {
      const track = Track(
        id: 'plain',
        spotifyId: 'plain',
        name: 'Bài kiểm thử lời tĩnh',
        artist: 'Test',
        localPath: 'fixture.mp3',
        lyrics: 'Một câu lời chưa có timestamp\nMột câu tiếp theo',
      );
      final (_, engine, router, repository) = await mount(tester, track: track);
      expect(
        find.text('Lời tĩnh · Bài này chưa có mốc thời gian đồng bộ.'),
        findsOneWidget,
      );
      expect(find.byType(SelectableText), findsWidgets);
      await capture(tester, 'plain');
      repository.onTrack = (_) async => secondTrack;
      await tester.runAsync(() async {
        final scope = ProviderScope.containerOf(
          tester.element(find.byType(LyricsScreen)),
        );
        await scope.read(playerControllerProvider.notifier).select([
          secondTrack,
        ], 0);
      });
      await tester.pumpAndSettle();
      expect(find.text('Chưa có lời bài hát'), findsOneWidget);
      expect(find.text('Một câu lời chưa có timestamp'), findsNothing);
      expect(engine.sought, Duration.zero);
      expect(tester.takeException(), isNull);
      await close(tester, router, repository);
    },
  );

  testWidgets('long wrapped lyrics follow the last cue with large text', (
    tester,
  ) async {
    final source = List.generate(
      80,
      (i) =>
          '[${(i ~/ 60).toString().padLeft(2, '0')}:${(i % 60).toString().padLeft(2, '0')}.00]Câu hát số $i dài qua nhiều dòng để kiểm tra cuộn đúng vị trí',
    ).join('\n');
    final track = Track(
      id: 'wrapped',
      spotifyId: 'wrapped',
      name: 'Kiểm thử dòng dài',
      artist: 'Test',
      localPath: 'fixture.mp3',
      lyricsSynced: source,
    );
    final (_, engine, router, repository) = await mount(
      tester,
      track: track,
      largeText: true,
    );
    engine.controller.add(
      const EngineEvent(
        playing: true,
        position: Duration(seconds: 79),
        duration: Duration(minutes: 2),
      ),
    );
    await tester.pumpAndSettle();
    final list = tester.widget<ListView>(
      find.byKey(const ValueKey('synced-lyrics-list')),
    );
    expect(list.controller!.position.pixels, greaterThan(1000));
    expect(
      find.text(
        'Câu hát số 79 dài qua nhiều dòng để kiểm tra cuộn đúng vị trí',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Câu hát số 0 dài qua nhiều dòng để kiểm tra cuộn đúng vị trí'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await capture(tester, 'synced-large');
    await close(tester, router, repository);
  });

  testWidgets('lyrics cannot seek pending music during an advertisement', (
    tester,
  ) async {
    final (player, _, router, repository) = await mount(tester);
    (player as LyricsPlayerHarness).simulateAd();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('synced-lyrics-list')), findsNothing);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.skip_previous_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.skip_next_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('Quảng cáo đang phát'), findsOneWidget);
    await close(tester, router, repository);
  });

  testWidgets('changing track during slider drag cannot seek the next song', (
    tester,
  ) async {
    final (player, engine, router, repository) = await mount(tester);
    final slider = find.byType(Slider);
    final widget = tester.widget<Slider>(slider);
    widget.onChangeStart!(40000);
    widget.onChanged!(40000);
    repository.onTrack = (_) async => secondTrack;
    await player.select([secondTrack], 0);
    widget.onChangeEnd!(40000);
    await tester.pumpAndSettle();
    expect(engine.sought, Duration.zero);
    expect(player.current.track?.id, secondTrack.id);
    expect(tester.takeException(), isNull);
    await close(tester, router, repository);
  });
}
