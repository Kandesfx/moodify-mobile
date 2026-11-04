import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/auth/data/device_identity.dart';
import 'package:moodify_flutter/features/offline/data/offline_repository.dart';
import '../../support/auth_harness.dart';
import '../../support/music_harness.dart';

void main() {
  late Directory root;
  late MemoryStore store;
  late Dio api;
  late MusicRepositoryFake catalog;
  late OfflineRepository repository;
  var revoked = false, confirmationFails = false;
  var removed = 0;
  Completer<void>? pendingConfirmation;
  const raw = <int>[73, 68, 51, 1, 2, 3, 4, 5, 6];
  final key = List.filled(32, 'ab').join();
  OfflineRepository create(String scope) {
    final media = Dio()
      ..httpClientAdapter = TestAdapter(
        (_) => ResponseBody.fromBytes(
          raw,
          200,
          headers: {
            'content-type': ['audio/mpeg'],
          },
        ),
      );
    return OfflineRepository(
      api,
      store,
      DeviceIdentityStore(store, platform: 'ANDROID'),
      catalog,
      scope,
      supportDirectory: () async => root,
      temporaryDirectory: () async => root,
      media: media,
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('moodify-offline-test-');
    store = MemoryStore();
    catalog = MusicRepositoryFake();
    revoked = false;
    confirmationFails = false;
    pendingConfirmation = null;
    removed = 0;
    api = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/'));
    api.httpClientAdapter = TestAdapter((options) async {
      if (options.path.endsWith('offline/remove')) removed++;
      if (options.path.endsWith('request-download')) {
        return jsonResponse({
          'success': true,
          'downloadToken': 'test-only-ticket',
          'downloadUrl': 'https://media.example.test/song.mp3',
          'encryptionKey': key,
          'expiresAt': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        });
      }
      if (options.path.endsWith('confirm-download')) {
        await pendingConfirmation?.future;
        return jsonResponse({'success': !confirmationFails});
      }
      if (options.path.endsWith('verify-license')) {
        return jsonResponse({
          'deviceActive': !revoked,
          'isPremium': !revoked,
          'validTrackIds': revoked ? [] : [firstTrack.id],
          'serverTime': DateTime.now().toIso8601String(),
        });
      }
      return jsonResponse({'success': true});
    });
    repository = create('api|user-one');
  });
  tearDown(() async {
    await repository.close(purge: true);
    api.close();
    catalog.remote.dio.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('cipher uses random nonces and rejects tampered ciphertext', () async {
    final first = await OfflineCipher.encrypt(raw, key);
    final second = await OfflineCipher.encrypt(raw, key);
    expect(first, isNot(orderedEquals(second)));
    expect(await OfflineCipher.decrypt(first, key), raw);
    first[first.length - 1] ^= 1;
    await expectLater(OfflineCipher.decrypt(first, key), throwsA(anything));
  });
  test(
    'encrypted files survive a normal close; plaintext is removed; user scopes stay isolated',
    () async {
      await repository.download(firstTrack, (_) {});
      final files = await root
          .list(recursive: true)
          .where((e) => e.path.endsWith('.mfy'))
          .toList();
      expect(files, hasLength(1));
      expect(
        await File(files.single.path).readAsBytes(),
        isNot(orderedEquals(raw)),
      );
      final source = await repository.playback(firstTrack, required: true);
      final decrypted = File.fromUri(source!.uri);
      expect(await decrypted.readAsBytes(), raw);
      await repository.close();
      expect(await decrypted.exists(), false);
      repository = create('api|user-one');
      expect(await repository.entries(), hasLength(1));
      final other = create('api|user-two');
      expect(await other.entries(), isEmpty);
      await other.close(purge: true);
    },
  );
  test(
    'failed server confirmation never becomes a completed download',
    () async {
      confirmationFails = true;
      await expectLater(
        repository.download(firstTrack, (_) {}),
        throwsA(anything),
      );
      expect(await repository.entries(), isEmpty);
      expect(
        await root
            .list(recursive: true)
            .where((e) => e.path.endsWith('.mfy'))
            .length,
        0,
      );
    },
  );
  test('revoked device deletes encrypted files, keys and plaintext', () async {
    await repository.download(firstTrack, (_) {});
    final source = await repository.playback(firstTrack, required: true);
    revoked = true;
    await expectLater(repository.verify(), throwsA(anything));
    expect(await repository.entries(), isEmpty);
    expect(await File.fromUri(source!.uri).exists(), false);
    expect(
      store.values.keys.where((key) => key.startsWith('moodify.offline')),
      isEmpty,
    );
  });
  test(
    'a failed download is reconciled after restart before the next request',
    () async {
      confirmationFails = true;
      await expectLater(
        repository.download(firstTrack, (_) {}),
        throwsA(anything),
      );
      await repository.close();
      repository = create('api|user-one');
      confirmationFails = false;
      await repository.download(firstTrack, (_) {});
      expect(removed, 1);
      expect(await repository.entries(), hasLength(1));
      expect(
        await root
            .list(recursive: true)
            .where((e) => e.path.endsWith('.part'))
            .length,
        0,
      );
    },
  );
  test(
    'logout purges files even after normal close or without opening the manifest',
    () async {
      await repository.download(firstTrack, (_) {});
      await repository.close();
      await repository.close(purge: true);
      repository = create('api|user-one');
      expect(await repository.entries(), isEmpty);
      await repository.download(firstTrack, (_) {});
      await repository.close();
      repository = create('api|user-one');
      await repository.close(purge: true);
      expect(
        store.values.keys.where((key) => key.startsWith('moodify.offline')),
        isEmpty,
      );
      expect(
        await root
            .list(recursive: true)
            .where((e) => e.path.endsWith('.mfy'))
            .length,
        0,
      );
    },
  );
  test(
    'logout during confirmation cannot recreate private files or keys',
    () async {
      pendingConfirmation = Completer<void>();
      final download = repository.download(firstTrack, (_) {});
      final failed = expectLater(download, throwsA(anything));
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      final closed = repository.close(purge: true);
      pendingConfirmation!.complete();
      await failed;
      await closed;
      expect(
        store.values.keys.where((key) => key.startsWith('moodify.offline')),
        isEmpty,
      );
      expect(
        await root
            .list(recursive: true)
            .where((e) => e.path.endsWith('.mfy') || e.path.endsWith('.mp3'))
            .length,
        0,
      );
    },
  );
}
