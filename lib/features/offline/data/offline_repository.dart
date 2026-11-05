import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/bootstrap.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/storage/key_value_store.dart';
import '../../auth/data/device_identity.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../player/domain/offline_playback.dart';

final offlineUserProvider = Provider<String?>(
  (ref) => ref.watch(
    sessionControllerProvider.select(
      (s) => s.session?.user.id ?? s.offlineUserId,
    ),
  ),
);
final offlineRepositoryProvider = Provider<OfflineRepository?>((ref) {
  final user = ref.read(offlineUserProvider);
  OfflineRepository? repository;
  ref.listen(offlineUserProvider, (_, next) {
    if (next != user) {
      unawaited(repository?.close(purge: true));
      ref.invalidateSelf();
    }
  });
  if (user == null) return null;
  repository = OfflineRepository(
    ref.watch(apiDioProvider),
    ref.watch(keyValueStoreProvider),
    ref.watch(deviceIdentityProvider),
    ref.watch(catalogRepositoryProvider),
    '${ref.watch(appConfigProvider).apiBaseUri}|$user',
  );
  final active = repository;
  ref.onDispose(() => unawaited(active.close()));
  return repository;
});

enum DownloadPhase { preparing, receiving, encrypting, confirming, verifying }

class DownloadUpdate {
  const DownloadUpdate(this.phase, {this.received = 0, this.total});
  final DownloadPhase phase;
  final int received;
  final int? total;
  double? get fraction =>
      total != null && total! > 0 ? (received / total!).clamp(0, 1) : null;
}

class OfflineEntry {
  const OfflineEntry(this.track, this.expiresAt, this.fileSize);
  final Track track;
  final DateTime expiresAt;
  final int fileSize;
  bool get expired => !expiresAt.isAfter(DateTime.now().toUtc());
}

class OfflineCipher {
  static final algorithm = AesGcm.with256bits();
  static SecretKey key(String hex) {
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hex)) {
      throw const FormatException('Invalid offline key');
    }
    return SecretKey([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
  }

  static Future<List<int>> encrypt(List<int> bytes, String hex) async =>
      (await algorithm.encrypt(bytes, secretKey: key(hex))).concatenation();
  static Future<List<int>> decrypt(List<int> bytes, String hex) async =>
      algorithm.decrypt(
        SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16),
        secretKey: key(hex),
      );
}

/// App-private files only. No database, plaintext key file, or media bearer token.
class OfflineRepository implements OfflinePlaybackAccess {
  OfflineRepository(
    this.api,
    this.store,
    this.devices,
    this.catalog,
    this.scope, {
    Future<Directory> Function()? supportDirectory,
    Future<Directory> Function()? temporaryDirectory,
    Dio? media,
  }) : supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _media =
           media ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(seconds: 45),
               followRedirects: false,
             ),
           );
  final Dio api;
  final KeyValueStore store;
  final DeviceIdentityStore devices;
  final CatalogRepository catalog;
  final String scope;
  final Future<Directory> Function() supportDirectory, temporaryDirectory;
  CancelToken _downloadCancel = CancelToken();
  final Dio _media;
  Directory? _directory, _temp;
  String? _manifestKey;
  Map<String, dynamic> _manifest = {};
  final Set<String> _cleanupIds = {};
  DateTime? _highWater;
  bool _closed = false;
  Future<void>? _initializing;
  Future<void>? _closing;
  Future<void> _serial = Future.value();
  Future<void> _saving = Future.value();
  Future<void>? _downloadFuture;

  Future<T> _run<T>(Future<T> Function() action) {
    final result = _serial.then((_) async {
      await _init();
      _guard();
      return action();
    });
    _serial = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _guard() {
    if (_closed) throw AppFailure.sessionChanged;
  }

  Future<String> _hash(String text) async => (await Sha256().hash(
    utf8.encode(text),
  )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  Future<void> _init() => _initializing ??= () async {
    final device = await devices.load();
    final name = await _hash('$scope|${device.uuid}');
    _manifestKey = 'moodify.offline.v1.$name';
    _directory = Directory(
      '${(await supportDirectory()).path}/moodify-offline-v1/$name',
    );
    _temp = Directory(
      '${(await temporaryDirectory()).path}/moodify-playback-v1/$name',
    );
    await _directory!.create(recursive: true);
    if (await _temp!.exists()) await _temp!.delete(recursive: true);
    await _temp!.create(recursive: true);
    final raw = await store.read(_manifestKey!);
    if (raw != null) {
      final json = objectJson(jsonDecode(raw));
      _manifest = objectJson(json['entries']);
      final cleanup = json['cleanup'];
      if (cleanup is List) _cleanupIds.addAll(cleanup.cast<String>());
      _highWater = DateTime.tryParse(
        json['lastSeen']?.toString() ?? '',
      )?.toUtc();
    }
    for (final id in _cleanupIds) {
      if (!_manifest.containsKey(id)) {
        final file = await _file(id);
        if (await file.exists()) await file.delete();
        final partial = File('${file.path}.part');
        if (await partial.exists()) await partial.delete();
      }
    }
  }();
  Future<void> _save() {
    final work = _saving.then((_) async {
      _guard();
      final now = DateTime.now().toUtc();
      if (_highWater == null || now.isAfter(_highWater!)) _highWater = now;
      await store.write(
        _manifestKey!,
        jsonEncode({
          'lastSeen': _highWater?.toIso8601String(),
          'entries': _manifest,
          'cleanup': _cleanupIds.toList(),
        }),
      );
    });
    _saving = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  Future<File> _file(String id) async =>
      File('${_directory!.path}/${await _hash(id)}.mfy');
  OfflineEntry _entry(Map<String, dynamic> json) => OfflineEntry(
    Track.fromJson(objectJson(json['track'])),
    DateTime.parse(requiredText(json, 'expiresAt')).toUtc(),
    (json['fileSize'] as num).toInt(),
  );
  Future<List<OfflineEntry>> entries() => _run(
    () async => _manifest.values.map((e) => _entry(objectJson(e))).toList(),
  );

  void cancelDownload() => _downloadCancel.cancel('USER_CANCELLED');
  void _checkDownload() {
    _guard();
    if (_downloadCancel.isCancelled) {
      throw const AppFailure('Đã hủy tải.', code: 'CANCELLED');
    }
  }

  Future<void> download(
    Track summary,
    void Function(double) progress, {
    void Function(DownloadUpdate)? onUpdate,
  }) {
    if (_downloadFuture != null) {
      return Future.error(
        const AppFailure(
          'Đang có một bài được tải. Hãy chờ hoặc hủy bài đang tải.',
          code: 'DOWNLOAD_BUSY',
        ),
      );
    }
    final work = _transfer(summary, progress, onUpdate: onUpdate);
    _downloadFuture = work;
    return work.whenComplete(() {
      _downloadFuture = null;
    });
  }

  Future<void> _transfer(
    Track summary,
    void Function(double) progress, {
    void Function(DownloadUpdate)? onUpdate,
  }) async {
    await _init();
    _guard();
    _downloadCancel = CancelToken();
    onUpdate?.call(const DownloadUpdate(DownloadPhase.preparing));
    await _flushCleanup();
    _checkDownload();
    if (_manifest.containsKey(summary.id)) {
      throw const AppFailure(
        'Bài hát đã có trên thiết bị. Xóa bản cũ trước khi tải lại.',
      );
    }
    final track = await catalog.track(summary.id);
    if (!track.hasAudio) {
      throw const AppFailure('Bài hát chưa có nguồn âm thanh để tải.');
    }
    _checkDownload();
    final device = await devices.load();
    // A bounded cleanup intent survives an app kill without keeping tickets.
    _cleanupIds.add(track.id);
    await _save();
    final ticket = objectJson(
      (await api.post<Object?>(
        'offline/request-download',
        data: {'trackId': track.id, ...device.toJson()},
      )).data,
    );
    _checkDownload();
    if (ticket['success'] != true) {
      throw const FormatException('Download refused');
    }
    final uri = Uri.parse(requiredText(ticket, 'downloadUrl'));
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid download URL');
    }
    final key = requiredText(ticket, 'encryptionKey');
    OfflineCipher.key(key);
    final file = await _file(track.id);
    final partial = File('${file.path}.part');
    try {
      var target = uri;
      Response<List<int>>? response;
      for (var redirects = 0; redirects < 5; redirects++) {
        response = await _media.get<List<int>>(
          target.toString(),
          options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (s) =>
                s == 200 || s == 302 || s == 301 || s == 307 || s == 308,
          ),
          cancelToken: _downloadCancel,
          onReceiveProgress: (received, total) {
            if (received > 40 * 1024 * 1024) {
              _downloadCancel.cancel('FILE_TOO_LARGE');
            }
            onUpdate?.call(
              DownloadUpdate(
                DownloadPhase.receiving,
                received: received,
                total: total > 0 ? total : null,
              ),
            );
            if (total > 0) progress((received / total).clamp(0, 1) * .8);
          },
        );
        if (response.statusCode == 200) break;
        final location = response.headers.value('location');
        if (location == null) {
          throw const FormatException('Invalid media redirect');
        }
        target = target.resolve(location);
        if (target.scheme != 'https' ||
            target.host.isEmpty ||
            target.userInfo.isNotEmpty) {
          throw const FormatException('Unsafe media redirect');
        }
      }
      _guard();
      final bytes = response?.data;
      final type = response?.headers.value('content-type') ?? '';
      if (response?.statusCode != 200 ||
          bytes == null ||
          bytes.isEmpty ||
          bytes.length > 40 * 1024 * 1024 ||
          !(type.startsWith('audio/') ||
              type.startsWith('application/octet-stream'))) {
        throw const AppFailure(
          'Nguồn tải không hợp lệ hoặc file vượt quá 40 MB.',
        );
      }
      _checkDownload();
      onUpdate?.call(const DownloadUpdate(DownloadPhase.encrypting));
      final encrypted = await OfflineCipher.encrypt(bytes, key);
      _checkDownload();
      _guard();
      await partial.writeAsBytes(encrypted, flush: true);
      _guard();
      await partial.rename(file.path);
      progress(.9);
      final hash = (await Sha256().hash(
        encrypted,
      )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      _checkDownload();
      onUpdate?.call(const DownloadUpdate(DownloadPhase.confirming));
      Map<String, dynamic>? recoveredVerification;
      try {
        final confirmation = objectJson(
          (await api.post<Object?>(
            'offline/confirm-download',
            data: {
              'downloadToken': requiredText(ticket, 'downloadToken'),
              'fileHash': hash,
              'fileSize': encrypted.length,
              'localPath': file.uri.toString(),
            },
          )).data,
        );
        if (confirmation['success'] != true) {
          throw const FormatException('Unconfirmed download');
        }
      } on DioException catch (error) {
        _checkDownload();
        final ambiguous =
            error.response == null || (error.response?.statusCode ?? 0) >= 500;
        if (!ambiguous) rethrow;
        final checked = await _verify([track.id]);
        if (checked['deviceActive'] != true ||
            checked['isPremium'] != true ||
            !(checked['validTrackIds'] is List &&
                (checked['validTrackIds'] as List).contains(track.id))) {
          rethrow;
        }
        recoveredVerification = checked;
      }
      _checkDownload();
      onUpdate?.call(const DownloadUpdate(DownloadPhase.verifying));
      final verification = recoveredVerification ?? await _verify([track.id]);
      _checkDownload();
      final valid = verification['validTrackIds'] as List? ?? [];
      if (verification['deviceActive'] != true ||
          verification['isPremium'] != true ||
          !valid.contains(track.id)) {
        throw const AppFailure(
          'Chưa xác minh được quyền nghe offline cho bài hát.',
        );
      }
      final expiry = _serverExpiry(
        requiredText(ticket, 'expiresAt'),
        requiredText(verification, 'serverTime'),
      );
      if (!expiry.isAfter(DateTime.now().toUtc())) {
        throw const AppFailure('Bản quyền offline đã hết hạn.');
      }
      _guard();
      _manifest[track.id] = {
        'track': track.toJson(),
        'expiresAt': expiry.toIso8601String(),
        'key': key,
        'fileSize': encrypted.length,
      };
      _cleanupIds.remove(track.id);
      await _save();
      progress(1);
    } catch (error) {
      _manifest.remove(track.id);
      _cleanupIds.add(track.id);
      if (await file.exists()) await file.delete();
      if (await partial.exists()) await partial.delete();
      if (!_closed) await _save();
      if (_closed) throw AppFailure.sessionChanged;
      if (_downloadCancel.cancelError?.error == 'FILE_TOO_LARGE') {
        throw const AppFailure(
          'Bản tải vượt giới hạn 40 MiB của ứng dụng.',
          code: 'FILE_TOO_LARGE',
        );
      }
      if (_downloadCancel.isCancelled) {
        throw const AppFailure('Đã hủy tải.', code: 'CANCELLED');
      }
      rethrow;
    }
  }

  DateTime _serverExpiry(String expires, String serverTime) {
    // Both backend values are timezone-less LocalDateTime; compare their delta.
    final remaining = DateTime.parse(
      expires,
    ).difference(DateTime.parse(serverTime));
    return DateTime.now().toUtc().add(remaining);
  }

  Future<Map<String, dynamic>> _verify(List<String> ids) async => objectJson(
    (await api.post<Object?>(
      'offline/verify-license',
      data: {'deviceUuid': (await devices.load()).uuid, 'trackIds': ids},
    )).data,
  );
  Future<void> verify({bool renew = false}) => _run(() async {
    if (_downloadFuture != null) {
      throw const AppFailure(
        'Chờ tải xong hoặc hủy trước khi xác minh.',
        code: 'DOWNLOAD_BUSY',
      );
    }
    await _flushCleanup();
    if (_manifest.isEmpty) return;
    String? newExpiry;
    if (renew) {
      final result = objectJson(
        (await api.post<Object?>(
          'offline/renew-all',
          queryParameters: {'deviceUuid': (await devices.load()).uuid},
        )).data,
      );
      if (result['success'] != true) {
        throw const FormatException('Renew refused');
      }
      newExpiry = requiredText(result, 'newExpiresAt');
    }
    final result = await _verify(_manifest.keys.toList());
    _guard();
    if (result['deviceActive'] != true || result['isPremium'] != true) {
      await _purgeEntries();
      throw const AppFailure(
        'Thiết bị hoặc tài khoản không còn quyền nghe offline.',
      );
    }
    final valid = result['validTrackIds'];
    if (valid is! List) throw const FormatException('Invalid licenses');
    for (final id in _manifest.keys.toList()) {
      if (!valid.contains(id)) {
        _manifest.remove(id);
        final file = await _file(id);
        if (await file.exists()) await file.delete();
      } else if (newExpiry != null) {
        objectJson(_manifest[id])['expiresAt'] = _serverExpiry(
          newExpiry,
          requiredText(result, 'serverTime'),
        ).toIso8601String();
      }
    }
    // A real server response may reset a clock rollback lock.
    _highWater = DateTime.now().toUtc();
    await _save();
  });
  @override
  Future<OfflineSource?> playback(
    Track track, {
    bool required = false,
  }) => _run(() async {
    final raw = _manifest[track.id];
    if (raw == null) {
      if (required) {
        throw const AppFailure('Bài hát chưa được tải trên thiết bị.');
      }
      return null;
    }
    final json = objectJson(raw);
    final entry = _entry(json);
    final now = DateTime.now().toUtc();
    if (_highWater != null &&
        now.isBefore(_highWater!.subtract(const Duration(minutes: 2)))) {
      throw const AppFailure(
        'Giờ thiết bị đã thay đổi. Kết nối mạng để xác minh lại bản quyền.',
      );
    }
    if (entry.expired) {
      throw const AppFailure(
        'Bản quyền offline đã hết hạn. Kết nối mạng để gia hạn.',
      );
    }
    final file = await _file(track.id);
    if (!await file.exists()) {
      throw const AppFailure(
        'File đã tải không còn trên thiết bị. Vui lòng tải lại.',
      );
    }
    final encrypted = await file.readAsBytes();
    late final List<int> bytes;
    try {
      bytes = await OfflineCipher.decrypt(encrypted, requiredText(json, 'key'));
    } catch (_) {
      throw const AppFailure(
        'Không mở được bản tải này. File hoặc khóa lưu trên máy không hợp lệ. Xóa bản tải và tải lại khi có mạng.',
        code: 'OFFLINE_CORRUPT',
      );
    }
    _guard();
    await _cleanPlayback();
    final playback = File('${_temp!.path}/current.mp3');
    await playback.writeAsBytes(bytes, flush: true);
    await _save();
    return (uri: playback.uri, expiresAt: entry.expiresAt);
  });
  @override
  Future<void> releasePlayback() => _run(_cleanPlayback);
  Future<void> _cleanPlayback() async {
    final file = File('${_temp!.path}/current.mp3');
    if (await file.exists()) await file.delete();
  }

  Future<void> remove(String id) => _run(() async {
    if (_downloadFuture != null) {
      throw const AppFailure(
        'Chờ tải xong hoặc hủy trước khi xóa.',
        code: 'DOWNLOAD_BUSY',
      );
    }
    if (!_manifest.containsKey(id)) return;
    _cleanupIds.add(id);
    await _save();
    final file = await _file(id);
    if (await file.exists()) await file.delete();
    _manifest.remove(id);
    await _save();
  });
  Future<void> synchronizeRemovals() => _run(_flushCleanup);
  Future<int> pendingCleanup() => _run(() async => _cleanupIds.length);
  Future<void> _purgeEntries() async {
    _manifest.clear();
    _cleanupIds.clear();
    await store.delete(_manifestKey!);
    if (await _directory!.exists()) await _directory!.delete(recursive: true);
    await _directory!.create(recursive: true);
    await _cleanPlayback();
  }

  Future<void> _flushCleanup() async {
    for (final id in _cleanupIds.toList()) {
      try {
        final result = objectJson(
          (await api.delete<Object?>(
            'offline/remove',
            queryParameters: {
              'deviceUuid': (await devices.load()).uuid,
              'trackId': id,
            },
          )).data,
        );
        if (result['success'] != true) {
          throw const FormatException('Cleanup refused');
        }
      } on DioException catch (error) {
        if (error.response?.statusCode != 404) rethrow;
      }
      _guard();
      _cleanupIds.remove(id);
      final file = await _file(id);
      if (await file.exists()) await file.delete();
      await _save();
    }
  }

  Future<void> close({bool purge = false}) {
    if (!_closed) {
      _closed = true;
      _downloadCancel.cancel();
      _media.close(force: true);
      _closing = Future.wait<void>([
        _serial,
        if (_downloadFuture != null)
          _downloadFuture!.then<void>(
            (_) {},
            onError: (Object _, StackTrace _) {},
          ),
      ]).then((_) {});
    }
    // Logout can request a purge after a normal provider disposal has begun.
    return _closing = _closing!.then((_) async {
      if (purge && _manifestKey == null) await _init();
      if (_manifestKey != null) {
        if (purge) {
          await _purgeEntries();
        } else {
          await _cleanPlayback();
        }
      }
    });
  }
}
