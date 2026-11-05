import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/app/bootstrap.dart';
import 'package:moodify_flutter/app/theme/app_theme.dart';
import 'package:moodify_flutter/features/auth/presentation/session_controller.dart';
import 'package:moodify_flutter/features/catalog/data/catalog_repository.dart';
import 'package:moodify_flutter/features/offline/data/offline_repository.dart';
import 'package:moodify_flutter/features/offline/data/offline_access_repository.dart';
import 'package:moodify_flutter/features/auth/domain/session_state.dart';
import 'package:moodify_flutter/features/auth/domain/auth_session.dart';
import 'package:moodify_flutter/features/offline/presentation/offline_controller.dart';
import 'package:moodify_flutter/features/offline/presentation/offline_screen.dart';
import 'package:moodify_flutter/features/player/data/ad_policy.dart';
import 'package:moodify_flutter/features/player/presentation/player_controller.dart';
import '../../support/auth_harness.dart';
import '../../support/music_harness.dart';

class TestAdPolicy extends AdPolicyService {
  TestAdPolicy() : super(Dio(), MemoryStore(), 'test');
  @override
  Future<AdDecision> decide(String? userId) async =>
      const AdDecision(false, false);
}

class ScreenDownloads extends OfflineController {
  ScreenDownloads() : super(null) {
    state = OfflineState(
      entries: [
        OfflineEntry(
          firstTrack,
          DateTime.now().add(const Duration(hours: 1)),
          1234,
        ),
      ],
      busy: true,
      downloading: secondTrack.id,
      track: secondTrack,
      update: const DownloadUpdate(DownloadPhase.receiving, received: 2048),
    );
  }
  bool cancelled = false;
  @override
  void cancel() {
    cancelled = true;
  }
}

class SignedInSession extends SessionController {
  @override
  SessionState build() => SessionState(
    phase: SessionPhase.signedIn,
    session: AuthSession.fromAuthResponse(authResponse(), DateTime.now()),
  );
}

class EmptyDownloads extends OfflineController {
  EmptyDownloads() : super(null);
}

void main() {
  testWidgets(
    'download without known total stays indeterminate and offers cancel on a small screen',
    (tester) async {
      final auth = AuthHarness();
      final music = MusicRepositoryFake();
      final downloads = ScreenDownloads();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(auth.config),
            sessionRepositoryProvider.overrideWithValue(auth.repository),
            adPolicyProvider.overrideWithValue(TestAdPolicy()),
            catalogRepositoryProvider.overrideWithValue(music),
            offlineUserProvider.overrideWithValue('test-user'),
            offlineControllerProvider.overrideWith((ref) => downloads),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const OfflineScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(secondTrack.name), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
      await tester.ensureVisible(find.text('Hủy tải'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Hủy tải'));
      expect(downloads.cancelled, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await auth.close();
      music.remote.dio.close();
    },
  );
  for (final scenario in ['free', 'error']) {
    testWidgets(
      'access $scenario shows accurate guidance with large text and no fake quota',
      (tester) async {
        final auth = AuthHarness();
        final music = MusicRepositoryFake();
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.8;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWithValue(auth.config),
              sessionControllerProvider.overrideWith(SignedInSession.new),
              adPolicyProvider.overrideWithValue(TestAdPolicy()),
              catalogRepositoryProvider.overrideWithValue(music),
              offlineUserProvider.overrideWithValue('test-user'),
              offlineControllerProvider.overrideWith((ref) => EmptyDownloads()),
              offlineAccessProvider.overrideWith((ref) async {
                if (scenario == 'error') throw const FormatException('Invalid');
                return OfflineAccess(
                  packageName: 'Miễn phí',
                  allowed: false,
                  used: 0,
                  maximum: 0,
                  checkedAt: DateTime.now(),
                );
              }),
            ],
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const OfflineScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final target = scenario == 'free'
            ? find.text('Xem gói có quyền offline')
            : find.text('Thử kiểm tra lại');
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(target, findsOneWidget);
        if (scenario == 'free') {
          expect(
            find.text('Gói hiện tại chưa cho phép tải nhạc offline.'),
            findsOneWidget,
          );
        }
        if (scenario == 'error') {
          expect(find.textContaining('Hạn mức máy chủ'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await auth.close();
        music.remote.dio.close();
      },
    );
  }
}
