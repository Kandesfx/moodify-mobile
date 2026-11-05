import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config/app_config.dart';
import '../core/network/authorized_session.dart';
import '../core/network/dio_factory.dart';
import '../core/network/session_interceptor.dart';
import '../core/storage/key_value_store.dart';
import '../features/auth/data/auth_remote_service.dart';
import '../features/auth/data/device_identity.dart';
import '../features/auth/data/session_repository.dart';
import '../features/auth/data/session_storage.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/offline/data/offline_repository.dart';
import '../features/player/domain/offline_playback.dart';

final wiredOfflinePlaybackProvider = Provider<OfflinePlaybackAccess?>(
  (ref) => ref.watch(offlineRepositoryProvider),
);

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError('AppConfig is required'),
);

final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => const SecureKeyValueStore(
    FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  ),
);

final authDioProvider = Provider<Dio>((ref) {
  final dio = createDio(ref.watch(appConfigProvider));
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final deviceIdentityProvider = Provider<DeviceIdentityStore>(
  (ref) => DeviceIdentityStore(
    ref.watch(keyValueStoreProvider),
    platform: kIsWeb
        ? 'OTHER'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'ANDROID',
            TargetPlatform.iOS => 'IOS',
            _ => 'OTHER',
          },
  ),
);

/// Override the feature's dependency at the app composition boundary, avoiding a data/UI cycle.
final wiredSessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final repository = SessionRepository(
    remote: AuthRemoteService(ref.watch(authDioProvider)),
    storage: SessionStorage(
      ref.watch(keyValueStoreProvider),
      namespace: ref.watch(appConfigProvider).apiBaseUri.toString(),
    ),
    devices: ref.watch(deviceIdentityProvider),
  );
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

final apiDioProvider = Provider<Dio>((ref) {
  final dio = createDio(ref.watch(appConfigProvider));
  dio.interceptors.add(
    SessionInterceptor(
      dio,
      _SessionAccess(ref.watch(sessionRepositoryProvider)),
      ref.watch(appConfigProvider),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

class _SessionAccess implements AuthorizedSession {
  const _SessionAccess(this.repository);
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
