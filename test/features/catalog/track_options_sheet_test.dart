import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/auth/domain/session_state.dart';
import 'package:moodify_flutter/features/auth/presentation/session_controller.dart';
import 'package:moodify_flutter/features/catalog/data/catalog_repository.dart';
import 'package:moodify_flutter/features/catalog/presentation/catalog_widgets.dart';
import 'package:moodify_flutter/features/player/data/ad_policy.dart';
import 'package:moodify_flutter/features/player/presentation/player_controller.dart';

import '../../support/auth_harness.dart' show MemoryStore;
import '../../support/music_harness.dart';

class TestAdPolicy extends AdPolicyService {
  TestAdPolicy() : super(Dio(), MemoryStore(), 'test');
  @override
  Future<AdDecision> decide(String? userId) async =>
      const AdDecision(false, false);
}

class GuestSessionController extends SessionController {
  @override
  SessionState build() => const SessionState(phase: SessionPhase.signedOut);
}

void main() {
  testWidgets(
    'track options open a bottom sheet and queue action enqueues the track',
    (tester) async {
      final music = MusicRepositoryFake();
      final engine = PlaybackEngineFake();
      final player = PlayerController(
        music,
        () async => engine,
        adPolicy: TestAdPolicy(),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        music.remote.dio.close();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith(GuestSessionController.new),
            adPolicyProvider.overrideWithValue(TestAdPolicy()),
            playbackEngineFactoryProvider.overrideWithValue(() async => engine),
            catalogRepositoryProvider.overrideWithValue(music),
            playerControllerProvider.overrideWith((ref) => player),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: TrackOptionsButton(track: firstTrack)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Tùy chọn cho ${firstTrack.displayName}'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lưu vào yêu thích'), findsOneWidget);
      expect(find.text('Thêm vào playlist'), findsOneWidget);
      expect(find.text('Tải để nghe offline'), findsOneWidget);
      expect(find.text('Thêm vào hàng đợi'), findsOneWidget);
      expect(find.text('Phát tiếp theo'), findsOneWidget);
      expect(find.text('Chia sẻ bài hát'), findsOneWidget);
      expect(find.text('Bỏ khỏi playlist'), findsNothing);
      expect(find.text('Xem nghệ sĩ'), findsNothing);
      await tester.tap(find.text('Thêm vào hàng đợi'));
      await tester.pumpAndSettle();
      // Sheet đã đóng và snackbar xác nhận hiện ra.
      expect(find.text('Thêm vào hàng đợi'), findsNothing);
      expect(find.text('Đã thêm vào hàng đợi.'), findsOneWidget);
      expect(engine.loaded, [firstTrack.id]);
      expect(tester.takeException(), isNull);
    },
  );
}
