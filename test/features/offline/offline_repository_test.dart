import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/auth/data/device_identity.dart';
import 'package:moodify_flutter/features/offline/data/offline_repository.dart';
import 'package:moodify_flutter/features/offline/data/offline_access_repository.dart';
import 'package:moodify_flutter/core/errors/app_failure.dart';
import 'package:moodify_flutter/features/offline/presentation/offline_controller.dart';
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
  var ambiguousConfirmation = false;
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
    ambiguousConfirmation = false;
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
        if (ambiguousConfirmation) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          );
        }
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
  test(
    'download phases reflect work and completion follows license verification',
    () async {
      final phases = <DownloadPhase>[];
      await repository.download(
        firstTrack,
        (_) {},
        onUpdate: (update) => phases.add(update.phase),
      );
      expect(phases.first, DownloadPhase.preparing);
      expect(
        phases,
        containsAllInOrder([
          DownloadPhase.encrypting,
          DownloadPhase.confirming,
          DownloadPhase.verifying,
        ]),
      );
      expect(await repository.entries(), hasLength(1));
    },
  );

  test(
    'cancel during confirmation cleans private file and retry reconciles reservation',
    () async {
      pendingConfirmation = Completer<void>();
      final reached = Completer<void>();
      final operation = repository.download(
        firstTrack,
        (_) {},
        onUpdate: (update) {
          if (update.phase == DownloadPhase.confirming &&
              !reached.isCompleted) {
            reached.complete();
          }
        },
      );
      final expectation = expectLater(
        operation,
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'CANCELLED')),
      );
      await reached.future;
      repository.cancelDownload();
      pendingConfirmation!.complete();
      await expectation;
      expect(await repository.entries(), isEmpty);
      expect(await repository.pendingCleanup(), 1);
      pendingConfirmation = null;
      await repository.download(firstTrack, (_) {});
      expect(removed, 1);
      expect(await repository.entries(), hasLength(1));
    },
  );

  test(
    'local removal requires no network and reconciles on explicit verify',
    () async {
      await repository.download(firstTrack, (_) {});
      await repository.remove(firstTrack.id);
      expect(removed, 0);
      expect(await repository.entries(), isEmpty);
      expect(await repository.pendingCleanup(), 1);
      await repository.close();
      repository = create('api|user-one');
      expect(await repository.pendingCleanup(), 1);
      await repository.verify();
      expect(removed, 1);
      expect(await repository.pendingCleanup(), 0);
    },
  );

  test('controller preserves downloaded library when a retry fails', () async {
    await repository.download(firstTrack, (_) {});
    final controller = OfflineController(repository);
    await controller.load();
    final success = await controller.download(firstTrack);
    expect(success, false);
    expect(controller.state.entries, hasLength(1));
    expect(controller.state.track?.id, firstTrack.id);
    expect(controller.state.failure, isNotNull);
    expect(controller.state.busy, false);
    controller.dispose();
  });
  test(
    'existing offline playback does not wait for another download confirmation',
    () async {
      await repository.download(firstTrack, (_) {});
      pendingConfirmation = Completer<void>();
      final reached = Completer<void>();
      final transfer = repository.download(
        secondTrack,
        (_) {},
        onUpdate: (update) {
          if (update.phase == DownloadPhase.confirming &&
              !reached.isCompleted) {
            reached.complete();
          }
        },
      );
      final cancelled = expectLater(transfer, throwsA(isA<AppFailure>()));
      await reached.future;
      final source = await repository
          .playback(firstTrack, required: true)
          .timeout(const Duration(seconds: 2));
      expect(await File.fromUri(source!.uri).readAsBytes(), raw);
      await repository.releasePlayback();
      repository.cancelDownload();
      pendingConfirmation!.complete();
      await cancelled;
      expect((await repository.entries()).single.track.id, firstTrack.id);
    },
  );
  test(
    'ambiguous confirmation reconciles a server-verified download without requesting another ticket',
    () async {
      ambiguousConfirmation = true;
      await repository.download(firstTrack, (_) {});
      expect(await repository.entries(), hasLength(1));
      expect(await repository.pendingCleanup(), 0);
      expect(removed, 0);
    },
  );
  test(
    'offline request refusal has a permission state and never completes a download',
    () async {
      api.httpClientAdapter = TestAdapter(
        (options) => jsonResponse({'message': 'forbidden'}, status: 403),
      );
      final controller = OfflineController(repository);
      expect(await controller.download(firstTrack), false);
      expect(controller.state.failure?.code, 'OFFLINE_FORBIDDEN');
      expect(controller.state.entries, isEmpty);
      expect(controller.state.busy, false);
      controller.dispose();
    },
  );
  test(
    'preflight denies free and full quota without requesting media or reservation',
    () async {
      var requests = 0;
      api.httpClientAdapter = TestAdapter((r) {
        requests++;
        return jsonResponse({});
      });
      for (final allowed in [false, true]) {
        final controller = OfflineController(
          repository,
          accessLoader: () async => OfflineAccess(
            packageName: 'Test',
            allowed: allowed,
            used: 2,
            maximum: 2,
            checkedAt: DateTime.now(),
          ),
        );
        expect(await controller.download(firstTrack), false);
        expect(
          controller.state.failure?.code,
          allowed ? 'DOWNLOAD_LIMIT' : 'OFFLINE_FORBIDDEN',
        );
        expect(requests, 0);
        expect(await repository.entries(), isEmpty);
        controller.dispose();
      }
    },
  );
  test('cancel while access check pending never starts the download', () async {
    final access = Completer<OfflineAccess>();
    final reached = Completer<void>();
    final controller = OfflineController(
      repository,
      accessLoader: () {
        reached.complete();
        return access.future;
      },
    );
    final work = controller.download(firstTrack);
    await reached.future;
    controller.cancel();
    access.complete(
      OfflineAccess(
        packageName: 'Test',
        allowed: true,
        used: 0,
        maximum: 2,
        checkedAt: DateTime.now(),
      ),
    );
    expect(await work, false);
    expect(controller.state.failure, isNull);
    expect(controller.state.notice, 'Đã hủy tải.');
    expect(await repository.entries(), isEmpty);
    controller.dispose();
  });

  test(
    'download saves local cover artwork for offline display and cleans artwork on remove',
    () async {
      final trackWithArt = firstTrack.withImage(
        'https://media.example.test/cover.jpg',
      );
      catalog.onTrack = (_) async => trackWithArt;
      await repository.download(trackWithArt, (_) {});
      final entries = await repository.entries();
      expect(entries, hasLength(1));
      final entry = entries.single;
      expect(entry.track.image, isNotNull);
      expect(entry.track.image, startsWith('file://'));
      final artFile = File.fromUri(Uri.parse(entry.track.image!));
      expect(await artFile.exists(), true);
      expect(await artFile.readAsBytes(), raw);
      await repository.remove(trackWithArt.id);
      expect(await artFile.exists(), false);
    },
  );
}
