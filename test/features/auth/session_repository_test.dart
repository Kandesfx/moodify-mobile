import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:moodify_flutter/core/errors/app_failure.dart';
import 'package:moodify_flutter/features/auth/domain/auth_session.dart';
import 'package:moodify_flutter/features/auth/domain/registration.dart';
import 'package:moodify_flutter/features/auth/domain/session_state.dart';

import '../../support/auth_harness.dart';

void main() {
  test('Google verification cancellation produces a clear message', () {
    final failure = AppFailure.from(
      const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
    );
    expect(failure.code, 'GOOGLE_canceled');
    expect(failure.message, contains('Xác minh'));
  });

  test('Google login sends ID token and establishes a session', () async {
    final h = AuthHarness(
      handler: (request) {
        if (request.uri.path == '/api/auth/google') {
          return jsonResponse(authResponse());
        }
        return AuthHarness.defaultResponse(request);
      },
    );
    addTearDown(h.close);
    await h.repository.restore();
    await h.repository.googleLogin(() async => 'provider-token');
    final request = h.requests.first;
    expect(request.uri.path, '/api/auth/google');
    expect(request.data['idToken'], 'provider-token');
    expect(request.data['deviceUuid'], isNotEmpty);
    expect(h.repository.state.phase, SessionPhase.signedIn);
    expect(await h.storage.read(), isNotNull);
  });

  test(
    'canceling while provider login is open does not send a token',
    () async {
      final h = AuthHarness();
      addTearDown(h.close);
      await h.repository.restore();
      final pending = Completer<String>();
      final login = h.repository.googleLogin(() => pending.future);
      await Future<void>.delayed(Duration.zero);
      await h.repository.logout();
      pending.complete('provider-token');
      await login;
      expect(h.requests, isEmpty);
      expect(h.repository.state.phase, SessionPhase.signedOut);
    },
  );

  test('flat auth response uses seconds and preserves opaque user ID', () {
    final now = DateTime.utc(2026, 11, 4);
    final session = AuthSession.fromAuthResponse(authResponse(), now);
    expect(
      session.accessExpiresAt.difference(now),
      const Duration(seconds: 1200),
    );
    expect(
      session.refreshExpiresAt.difference(now),
      const Duration(seconds: 604800),
    );
    expect(session.user.id, '1');
  });

  test(
    'missing tokens or invalid expiry never become an authenticated session',
    () {
      expect(
        () => AuthSession.fromAuthResponse({
          ...authResponse(),
          'expiresIn': 0,
        }, DateTime.now()),
        throwsFormatException,
      );
      expect(
        () => AuthSession.fromAuthResponse({
          ...authResponse(),
          'accessToken': '',
        }, DateTime.now()),
        throwsFormatException,
      );
    },
  );

  test('empty storage restores signed out without network requests', () async {
    final h = AuthHarness();
    addTearDown(h.close);
    await h.repository.restore();
    expect(h.repository.state.phase, SessionPhase.signedOut);
    expect(h.requests, isEmpty);
  });

  test('malformed stored profile is rejected as corrupt data', () {
    final stored = AuthSession.fromAuthResponse(
      authResponse(),
      DateTime.now(),
    ).toStored();
    expect(
      () => AuthSession.fromStored({...stored, 'user': null}),
      throwsFormatException,
    );
    expect(
      () => AuthSession.fromStored({
        ...stored,
        'user': {...profileResponse(), 'phone': 123},
      }),
      throwsFormatException,
    );
  });

  test(
    'temporary restore failure retains credentials and retries verification',
    () async {
      var unavailable = true;
      final h = AuthHarness(
        handler: (request) => unavailable
            ? jsonResponse(null, status: 503)
            : AuthHarness.defaultResponse(request),
      );
      addTearDown(h.close);
      await h.storage.write(
        AuthSession.fromAuthResponse(authResponse(), h.now),
      );
      await h.repository.restore();
      expect(h.repository.state.phase, SessionPhase.restoreFailed);
      expect(h.repository.state.session, isNull);
      expect(await h.storage.read(), isNotNull);
      unavailable = false;
      await h.repository.restore();
      expect(h.repository.state.phase, SessionPhase.signedIn);
    },
  );

  test(
    'secure read unavailable retains stored credentials for retry',
    () async {
      final h = AuthHarness();
      addTearDown(h.close);
      await h.storage.write(
        AuthSession.fromAuthResponse(authResponse(), h.now),
      );
      h.store.failReads = true;
      await h.repository.restore();
      expect(h.repository.state.phase, SessionPhase.restoreFailed);
      expect(h.store.values[h.storage.key], isNotNull);
      h.store.failReads = false;
      await h.repository.restore();
      expect(h.repository.state.phase, SessionPhase.signedIn);
    },
  );

  test('expired refresh token is removed without calling API', () async {
    final h = AuthHarness();
    addTearDown(h.close);
    await h.storage.write(
      AuthSession.fromAuthResponse(
        authResponse(),
        h.now.subtract(const Duration(days: 8)),
      ),
    );
    await h.repository.restore();
    expect(h.repository.state.phase, SessionPhase.signedOut);
    expect(await h.storage.read(), isNull);
    expect(h.requests, isEmpty);
  });

  test(
    'temporary refresh failure retains session while rejected refresh closes it',
    () async {
      var status = 503;
      final h = AuthHarness(
        handler: (request) => request.uri.path.endsWith('/refresh')
            ? jsonResponse(null, status: status)
            : AuthHarness.defaultResponse(request),
      );
      addTearDown(h.close);
      await h.repository.login('testuser1', 'test-password');
      await expectLater(
        h.repository.refreshAccessToken(),
        throwsA(isA<AppFailure>()),
      );
      expect(h.repository.state.phase, SessionPhase.signedIn);
      expect(await h.storage.read(), isNotNull);
      status = 401;
      await expectLater(
        h.repository.refreshAccessToken(),
        throwsA(isA<AppFailure>()),
      );
      expect(h.repository.state.phase, SessionPhase.signedOut);
      expect(await h.storage.read(), isNull);
    },
  );

  test(
    'failed local cleanup offers retry and a retry removes credentials',
    () async {
      final h = AuthHarness();
      addTearDown(h.close);
      await h.repository.login('testuser1', 'test-password');
      h.store.failDeletes = true;
      await h.repository.logout();
      expect(h.repository.state.phase, SessionPhase.signedOut);
      expect(h.repository.state.failure!.code, 'STORAGE_CLEAR');
      h.store.failDeletes = false;
      await h.repository.logout();
      expect(await h.storage.read(), isNull);
    },
  );

  test('corrupt or expired persisted session is removed', () async {
    final h = AuthHarness();
    addTearDown(h.close);
    h.store.values[h.storage.key] = '{invalid';
    await h.repository.restore();
    expect(h.repository.state.phase, SessionPhase.signedOut);
    expect(h.store.values[h.storage.key], isNull);
  });

  test(
    'restore validates profile using auth/me before exposing account',
    () async {
      final h = AuthHarness();
      addTearDown(h.close);
      await h.storage.write(
        AuthSession.fromAuthResponse(authResponse(), h.now),
      );
      await h.repository.restore();
      expect(h.repository.state.phase, SessionPhase.signedIn);
      expect(h.repository.state.session!.user.phone, '0900000000');
      expect(h.requests.single.uri.path, '/api/auth/me');
      expect(h.requests.single.headers['X-Device-Uuid'], isNotEmpty);
    },
  );

  test(
    'simultaneous expired access requests share exactly one refresh',
    () async {
      final entered = Completer<void>();
      final release = Completer<ResponseBody>();
      var refreshes = 0;
      final h = AuthHarness(
        handler: (request) {
          if (request.uri.path == '/api/auth/refresh') {
            refreshes++;
            if (!entered.isCompleted) entered.complete();
            return release.future;
          }
          return AuthHarness.defaultResponse(request);
        },
      );
      addTearDown(h.close);
      await h.repository.login('testuser1', 'test-password');
      h.now = h.now.add(const Duration(minutes: 21));
      final work = List.generate(8, (_) => h.repository.accessToken());
      await entered.future;
      release.complete(
        jsonResponse(
          authResponse(access: 'test-access-2', refresh: 'test-refresh-2'),
        ),
      );
      expect(await Future.wait(work), everyElement('test-access-2'));
      expect(refreshes, 1);
      expect((await h.storage.read())!.refreshToken, 'test-refresh-2');
      expect(
        await h.repository.refreshAccessToken(failedToken: 'test-access-1'),
        'test-access-2',
      );
      expect(refreshes, 1);
    },
  );

  test(
    'logout cancels refresh and stale result cannot restore session',
    () async {
      final entered = Completer<void>();
      final release = Completer<ResponseBody>();
      final h = AuthHarness(
        handler: (request) {
          if (request.uri.path == '/api/auth/refresh') {
            entered.complete();
            return release.future;
          }
          return AuthHarness.defaultResponse(request);
        },
      );
      addTearDown(h.close);
      await h.repository.login('testuser1', 'test-password');
      final refresh = h.repository.refreshAccessToken();
      final assertion = expectLater(refresh, throwsA(isA<AppFailure>()));
      await entered.future;
      await h.repository.logout();
      release.complete(jsonResponse(authResponse(access: 'test-stale-access')));
      await assertion;
      expect(h.repository.state.phase, SessionPhase.signedOut);
      expect(await h.storage.read(), isNull);
    },
  );

  test(
    'logout after an in-flight secure write eventually clears persisted credentials',
    () async {
      final h = AuthHarness();
      addTearDown(h.close);
      final entered = Completer<void>();
      final release = Completer<void>();
      h.store.beforeWrite = (key, value) async {
        if (key == h.storage.key) {
          entered.complete();
          await release.future;
        }
      };
      final login = h.repository.login('testuser1', 'test-password');
      await entered.future;
      final logout = h.repository.logout();
      release.complete();
      await Future.wait([login, logout]);
      expect(h.repository.state.phase, SessionPhase.signedOut);
      expect(await h.storage.read(), isNull);
    },
  );

  test(
    'invalid login does not trigger refresh or persist credentials',
    () async {
      final h = AuthHarness(
        handler: (request) =>
            jsonResponse({'message': 'Invalid credentials'}, status: 401),
      );
      addTearDown(h.close);
      await h.repository.login('testuser1', 'wrong-test-password');
      expect(h.repository.state.phase, SessionPhase.signedOut);
      expect(h.repository.state.failure!.message, contains('chưa đúng'));
      expect(h.requests.length, 1);
      expect(await h.storage.read(), isNull);
    },
  );

  test(
    'register sends USER DTO then syncs installation; password is never persisted',
    () async {
      final h = AuthHarness();
      addTearDown(h.close);
      await h.repository.register(
        const Registration(
          fullName: ' Test User ',
          phone: '0900000000',
          email: 'test@example.test',
          username: 'testuser',
          password: 'test-password',
          confirmPassword: 'test-password',
        ),
      );
      final body = h.requests.first.data as Map;
      expect(body['role'], 'USER');
      expect(body['fullName'], 'Test User');
      expect(body.containsKey('genres'), isFalse);
      expect(
        h.requests.map((r) => r.uri.path),
        contains('/api/auth/devices/register'),
      );
      expect(h.repository.state.phase, SessionPhase.signedIn);
      expect(
        h.store.values.values.any((value) => value.contains('test-password')),
        isFalse,
      );
    },
  );

  test(
    'device sync failure after registration preserves created account and shows recovery',
    () async {
      var unavailable = true;
      final h = AuthHarness(
        handler: (request) =>
            unavailable && request.uri.path == '/api/auth/devices/register'
            ? jsonResponse({'message': 'Server unavailable'}, status: 503)
            : AuthHarness.defaultResponse(request),
      );
      addTearDown(h.close);
      await h.repository.register(
        const Registration(
          fullName: 'Test',
          phone: '0900000000',
          email: 'test@example.test',
          username: 'testuser',
          password: 'test-password',
          confirmPassword: 'test-password',
        ),
      );
      expect(h.repository.state.phase, SessionPhase.signedIn);
      expect(h.repository.state.notice, contains('đã được tạo'));
      expect(await h.storage.read(), isNotNull);
      unavailable = false;
      await h.repository.refreshProfile();
      expect(
        h.requests
            .where((r) => r.uri.path.endsWith('/devices/register'))
            .length,
        2,
      );
      expect(h.repository.state.failure, isNull);
    },
  );

  test(
    'secure storage write failure never shows authenticated success',
    () async {
      final h = AuthHarness();
      addTearDown(h.close);
      await h.devices.load();
      h.store.failWrites = true;
      await h.repository.login('testuser1', 'test-password');
      expect(h.repository.state.phase, SessionPhase.signedOut);
      expect(h.repository.state.failure!.code, 'STORAGE');
    },
  );

  test(
    'logout clears local credentials even when remote logout fails',
    () async {
      final h = AuthHarness(
        handler: (request) => request.uri.path == '/api/auth/logout'
            ? jsonResponse({'message': 'Unavailable'}, status: 503)
            : AuthHarness.defaultResponse(request),
      );
      addTearDown(h.close);
      await h.repository.login('testuser1', 'test-password');
      await h.repository.logout();
      expect(await h.storage.read(), isNull);
      expect(h.repository.state.phase, SessionPhase.signedOut);
      expect(h.repository.state.notice, isNull);
      expect(
        h.store.values.length,
        1,
      ); // Installation identity is intentionally retained.
    },
  );
}
