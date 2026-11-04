import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/core/errors/app_failure.dart';
import 'package:moodify_flutter/core/network/dio_factory.dart';
import 'package:moodify_flutter/core/network/session_interceptor.dart';
import 'package:moodify_flutter/features/auth/domain/session_state.dart';

import '../../support/auth_harness.dart';

void main() {
  Future<Dio> authorizedClient(AuthHarness h, RequestHandler handler) async {
    await h.repository.login('testuser1', 'test-password');
    final client = createDio(h.config)
      ..httpClientAdapter = TestAdapter(handler);
    client.interceptors.add(
      SessionInterceptor(client, RepositoryAccess(h.repository), h.config),
    );
    addTearDown(() => client.close(force: true));
    return client;
  }

  test(
    'concurrent 401 responses share refresh and each request retries with new token',
    () async {
      var refreshes = 0;
      final release = Completer<ResponseBody>();
      final entered = Completer<void>();
      final h = AuthHarness(
        handler: (options) {
          if (options.uri.path == '/api/auth/refresh') {
            refreshes++;
            if (!entered.isCompleted) entered.complete();
            return release.future;
          }
          return AuthHarness.defaultResponse(options);
        },
      );
      addTearDown(h.close);
      var attempts = 0;
      final client = await authorizedClient(h, (options) {
        attempts++;
        return options.headers['Authorization'] == 'Bearer test-access-1'
            ? jsonResponse(null, status: 401)
            : jsonResponse({'ok': true});
      });
      final requests = List.generate(
        6,
        (_) => client.get<dynamic>('protected'),
      );
      await entered.future;
      release.complete(jsonResponse(authResponse(access: 'test-access-2')));
      final results = await Future.wait(requests);
      expect(results.every((r) => r.statusCode == 200), isTrue);
      expect(refreshes, 1);
      expect(attempts, 12);
    },
  );

  test('second 401 expires session after one retry', () async {
    final h = AuthHarness();
    addTearDown(h.close);
    final cleared = Completer<void>();
    h.store.onDelete = (key) {
      if (key == h.storage.key && !cleared.isCompleted) cleared.complete();
    };
    var attempts = 0;
    final client = await authorizedClient(h, (_) {
      attempts++;
      return jsonResponse(null, status: 401);
    });
    await expectLater(
      client.get<dynamic>('protected'),
      throwsA(isA<DioException>()),
    );
    expect(attempts, 2);
    expect(h.repository.state.phase, SessionPhase.signedOut);
    await cleared.future;
    expect(await h.storage.read(), isNull);
  });

  test('ordinary 403 does not refresh or log user out', () async {
    final h = AuthHarness();
    addTearDown(h.close);
    final client = await authorizedClient(
      h,
      (_) => jsonResponse({'error': 'FORBIDDEN'}, status: 403),
    );
    await expectLater(
      client.get<dynamic>('protected'),
      throwsA(isA<DioException>()),
    );
    expect(h.requests.where((r) => r.uri.path.endsWith('/refresh')), isEmpty);
    expect(h.repository.state.phase, SessionPhase.signedIn);
  });

  test('DEVICE_REVOKED closes session without refresh', () async {
    final h = AuthHarness();
    addTearDown(h.close);
    final client = await authorizedClient(
      h,
      (_) => jsonResponse({'error': 'DEVICE_REVOKED'}, status: 403),
    );
    await expectLater(
      client.get<dynamic>('protected'),
      throwsA(isA<DioException>()),
    );
    expect(h.repository.state.phase, SessionPhase.signedOut);
    expect(h.requests.where((r) => r.uri.path.endsWith('/refresh')), isEmpty);
  });

  test(
    'external origin request is rejected before token leaves client',
    () async {
      final h = AuthHarness();
      addTearDown(h.close);
      var calls = 0;
      final client = await authorizedClient(h, (_) {
        calls++;
        return jsonResponse({});
      });
      await expectLater(
        client.get<dynamic>('https://media.example.test/file'),
        throwsA(
          isA<DioException>().having(
            (e) => (e.error as AppFailure).code,
            'code',
            'ORIGIN',
          ),
        ),
      );
      expect(calls, 0);
    },
  );

  test(
    'late response using a caller cancel token is discarded after logout',
    () async {
      final h = AuthHarness();
      addTearDown(h.close);
      final entered = Completer<void>();
      final release = Completer<ResponseBody>();
      final client = await authorizedClient(h, (_) {
        entered.complete();
        return release.future;
      });
      final work = client.get<dynamic>('protected', cancelToken: CancelToken());
      final assertion = expectLater(work, throwsA(isA<DioException>()));
      await entered.future;
      await h.repository.logout();
      release.complete(jsonResponse({'private': 'previous user data'}));
      await assertion;
      expect(h.repository.state.phase, SessionPhase.signedOut);
    },
  );
}
