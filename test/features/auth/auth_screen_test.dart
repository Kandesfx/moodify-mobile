import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/app/app.dart';
import 'package:moodify_flutter/app/bootstrap.dart';
import 'package:moodify_flutter/features/auth/presentation/session_controller.dart';
import 'package:moodify_flutter/features/auth/domain/auth_session.dart';
import 'package:moodify_flutter/app/router/app_router.dart';

import '../../support/auth_harness.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, AuthHarness h) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(h.config),
          sessionRepositoryProvider.overrideWithValue(h.repository),
        ],
        child: const MoodifyApp(),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MoodifyApp)),
    );
    container.read(appRouterProvider).go('/account');
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    if (find.widgetWithText(FilledButton, 'Đăng nhập').evaluate().isNotEmpty) {
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Đăng nhập'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'restore error hides cached profile and retry verifies before showing account',
    (tester) async {
      var unavailable = true;
      final h = AuthHarness(
        handler: (request) => unavailable
            ? jsonResponse(null, status: 503)
            : AuthHarness.defaultResponse(request),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        final closed = h.close();
        await tester.pump();
        await closed;
      });
      await h.storage.write(
        AuthSession.fromAuthResponse(authResponse(), h.now),
      );
      await pumpApp(tester, h);
      expect(find.text('user1@example.test'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Thử lại'), findsOneWidget);
      unavailable = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('user1@example.test'), findsNothing);
      await tester.tap(find.text('Quản lý tài khoản'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'user1@example.test'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'guard opens sign-in and validation does not submit empty input',
    (tester) async {
      final h = AuthHarness();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        final closed = h.close();
        await tester.pump();
        await closed;
      });
      await pumpApp(tester, h);
      expect(
        tester.getSemantics(find.byType(TextFormField).first).label,
        contains('Email hoặc tên đăng nhập'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget);
      expect(h.requests, isEmpty);
    },
  );

  testWidgets('login reaches account using response data and logout removes it', (
    tester,
  ) async {
    final h = AuthHarness();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      final closed = h.close();
      await tester.pump();
      await closed;
    });
    await pumpApp(tester, h);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'testuser1');
    await tester.enterText(fields.at(1), 'test-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MoodifyApp)),
    );
    expect(find.text('user1@example.test'), findsNothing);
    expect(
      find.text('Quản lý tài khoản'),
      findsOneWidget,
      reason:
          'route=${container.read(appRouterProvider).routerDelegate.currentConfiguration.uri}, phase=${h.repository.state.phase}',
    );
    await tester.tap(find.text('Quản lý tài khoản'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextFormField, 'user1@example.test'),
      findsOneWidget,
    );
    container.read(appRouterProvider).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Đăng xuất'));
    await tester.tap(find.widgetWithText(TextButton, 'Đăng xuất'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.text('user1@example.test'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
  });

  testWidgets(
    'small viewport and large text keep registration scrollable without overflow',
    (tester) async {
      final h = AuthHarness();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        final closed = h.close();
        await tester.pump();
        await closed;
      });
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, h);
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Đăng ký'));
      await tester.tap(find.widgetWithText(TextButton, 'Đăng ký'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Tạo tài khoản'),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.byType(TextFormField), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    },
  );
}
