import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:moodify_flutter/core/config/app_config.dart';
import 'package:moodify_flutter/core/network/authorized_session.dart';
import 'package:moodify_flutter/core/network/dio_factory.dart';
import 'package:moodify_flutter/core/storage/key_value_store.dart';
import 'package:moodify_flutter/features/auth/data/auth_remote_service.dart';
import 'package:moodify_flutter/features/auth/data/device_identity.dart';
import 'package:moodify_flutter/features/auth/data/session_repository.dart';
import 'package:moodify_flutter/features/auth/data/session_storage.dart';

// Test-only data and adapter: never imported by lib or connected to a live API.
Map<String, dynamic> authResponse({
  String access = 'test-access-1',
  String refresh = 'test-refresh-1',
  int userId = 1,
}) => {
  'accessToken': access,
  'refreshToken': refresh,
  'tokenType': 'Bearer',
  'expiresIn': 1200,
  'refreshExpiresIn': 604800,
  'userId': userId,
  'fullName': 'Người kiểm thử $userId',
  'email': 'user$userId@example.test',
  'username': 'testuser$userId',
  'role': 'USER',
  'status': 'ACTIVE',
};

Map<String, dynamic> profileResponse({int userId = 1}) => {
  'id': userId,
  'fullName': 'Người kiểm thử $userId',
  'email': 'user$userId@example.test',
  'username': 'testuser$userId',
  'phone': '0900000000',
  'role': 'USER',
  'status': 'ACTIVE',
};

ResponseBody jsonResponse(Object? value, {int status = 200}) =>
    ResponseBody.fromString(
      value == null ? '' : jsonEncode(value),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

typedef RequestHandler =
    FutureOr<ResponseBody> Function(RequestOptions options);

class TestAdapter implements HttpClientAdapter {
  TestAdapter(this.handler);
  final RequestHandler handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);
  @override
  void close({bool force = false}) {}
}

class MemoryStore implements KeyValueStore {
  final values = <String, String>{};
  Future<void> Function(String key, String value)? beforeWrite;
  bool failWrites = false;
  bool failReads = false;
  bool failDeletes = false;
  void Function(String key)? onDelete;
  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('Simulated secure read failure');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('Simulated secure storage failure');
    await beforeWrite?.call(key, value);
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDeletes) throw StateError('Simulated secure delete failure');
    values.remove(key);
    onDelete?.call(key);
  }
}

class AuthHarness {
  AuthHarness({RequestHandler? handler}) {
    dio = createDio(config);
    dio.httpClientAdapter = TestAdapter((options) {
      requests.add(options);
      if (handler != null) return handler(options);
      return defaultResponse(options);
    });
    storage = SessionStorage(store, namespace: config.apiBaseUri.toString());
    devices = DeviceIdentityStore(store, platform: 'ANDROID');
    repository = SessionRepository(
      remote: AuthRemoteService(dio),
      storage: storage,
      devices: devices,
      clock: () => now,
    );
  }

  final config = AppConfig(apiBaseUrl: 'https://api.example.test/api');
  final store = MemoryStore();
  final requests = <RequestOptions>[];
  DateTime now = DateTime.utc(2026, 11, 4);
  late final Dio dio;
  late final SessionStorage storage;
  late final DeviceIdentityStore devices;
  late final SessionRepository repository;

  static ResponseBody defaultResponse(RequestOptions options) =>
      switch (options.uri.path) {
        '/api/auth/login' ||
        '/api/auth/register' => jsonResponse(authResponse()),
        '/api/auth/me' => jsonResponse(profileResponse()),
        '/api/auth/refresh' => jsonResponse(
          authResponse(access: 'test-access-2', refresh: 'test-refresh-2'),
        ),
        '/api/auth/devices/register' => jsonResponse({'success': true}),
        '/api/auth/logout' => jsonResponse(null, status: 204),
        _ => jsonResponse({'message': 'No test route'}, status: 404),
      };

  Future<void> close() async {
    dio.close(force: true);
    await repository.dispose();
  }
}

class RepositoryAccess implements AuthorizedSession {
  RepositoryAccess(this.repository);
  final SessionRepository repository;
  @override
  int get generation => repository.generation;
  @override
  CancelToken get cancelToken => repository.cancelToken;
  @override
  Future<String> accessToken() => repository.accessToken();
  @override
  Future<String> refreshAccessToken({String? failedToken}) =>
      repository.refreshAccessToken(failedToken: failedToken);
  @override
  Future<String> deviceUuid() async => (await repository.devices.load()).uuid;
  @override
  Future<void> expire(String message) => repository.expire(message);
}
