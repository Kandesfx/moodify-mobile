import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_failure.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/offline_repository.dart';
import '../data/offline_access_repository.dart';

final offlineControllerProvider =
    StateNotifierProvider<OfflineController, OfflineState>((ref) {
      final online = ref.watch(
        sessionControllerProvider.select((s) => s.session != null),
      );
      return OfflineController(
        ref.watch(offlineRepositoryProvider),
        accessLoader: () async {
          final access = await ref.refresh(offlineAccessProvider.future);
          if (access == null) {
            throw const AppFailure(
              'Đăng nhập lại để kiểm tra quyền tải.',
              code: 'OFFLINE_AUTH',
            );
          }
          return access;
        },
        onChanged: () => ref.invalidate(offlineAccessProvider),
      )..load(verify: online);
    });

class OfflineState {
  const OfflineState({
    this.entries = const [],
    this.busy = false,
    this.progress = 0,
    this.downloading,
    this.failure,
    this.track,
    this.update,
    this.notice,
    this.pendingCleanup = 0,
  });
  final List<OfflineEntry> entries;
  final bool busy;
  final double progress;
  final String? downloading;
  final AppFailure? failure;
  final Track? track;
  final DownloadUpdate? update;
  final String? notice;
  final int pendingCleanup;
}

class OfflineController extends StateNotifier<OfflineState> {
  OfflineController(this.repository, {this.accessLoader, this.onChanged})
    : super(const OfflineState());
  final Future<OfflineAccess> Function()? accessLoader;
  final void Function()? onChanged;
  final OfflineRepository? repository;
  bool _cancelRequested = false;
  Future<void> load({bool verify = false}) async {
    if (repository == null || state.busy) return;
    await _operation(() async {
      if (verify) await repository!.verify();
    });
  }

  Future<bool> _operation(
    Future<void> Function() operation, {
    Track? track,
  }) async {
    if (repository == null || state.busy) return false;
    _cancelRequested = false;
    state = OfflineState(
      entries: state.entries,
      busy: true,
      downloading: track?.id,
      track: track,
      pendingCleanup: state.pendingCleanup,
    );
    try {
      await operation();
      final entries = await repository!.entries();
      if (!mounted) return false;
      final pending = await repository!.pendingCleanup();
      if (!mounted) return false;
      state = OfflineState(
        entries: entries,
        track: track,
        pendingCleanup: pending,
        notice: track != null
            ? 'Đã tải xong. Bài hát sẵn sàng nghe offline.'
            : null,
      );
      onChanged?.call();
      return true;
    } catch (error) {
      if (mounted) {
        // A revocation may already have removed files before the failure notice.
        final entries = await repository!.entries().catchError(
          (Object _) => state.entries,
        );
        if (mounted) {
          state = OfflineState(
            entries: entries,
            failure: _failure(error).code == 'CANCELLED'
                ? null
                : _failure(error),
            notice: _failure(error).code == 'CANCELLED' ? 'Đã hủy tải.' : null,
            track: track,
            pendingCleanup: state.pendingCleanup,
          );
        }
      }
      return false;
    }
  }

  Future<bool> download(Track track) => _operation(() async {
    if (accessLoader != null) {
      if (await repository!.pendingCleanup() > 0) {
        await repository!.synchronizeRemovals();
      }
      final access = await accessLoader!();
      if (!mounted) throw AppFailure.sessionChanged;
      if (_cancelRequested) {
        throw const AppFailure('Đã hủy tải.', code: 'CANCELLED');
      }
      if (!access.allowed) {
        throw const AppFailure(
          'Gói hiện tại chưa có quyền tải nhạc offline trên thiết bị này.',
          code: 'OFFLINE_FORBIDDEN',
        );
      }
      if (access.full) {
        throw const AppFailure(
          'Đã dùng hết hạn mức tải trên thiết bị. Xóa bản không cần dùng rồi đồng bộ để tải tiếp.',
          code: 'DOWNLOAD_LIMIT',
        );
      }
    }
    await repository!.download(
      track,
      (_) {},
      onUpdate: (update) {
        if (mounted) {
          state = OfflineState(
            entries: state.entries,
            busy: true,
            downloading: track.id,
            track: track,
            update: update,
            progress: update.fraction ?? 0,
            pendingCleanup: state.pendingCleanup,
          );
        }
      },
    );
  }, track: track);
  void clearTask() {
    if (state.busy) return;
    state = OfflineState(
      entries: state.entries,
      pendingCleanup: state.pendingCleanup,
    );
  }

  void cancel() {
    _cancelRequested = true;
    repository?.cancelDownload();
  }

  Future<bool> remove(String id) => _operation(() => repository!.remove(id));
  Future<bool> verify({bool renew = false}) =>
      _operation(() => repository!.verify(renew: renew));

  AppFailure _failure(Object error) {
    if (error is FileSystemException) {
      return const AppFailure(
        'Không lưu được bản tải. Kiểm tra dung lượng trống trên thiết bị rồi thử lại.',
        code: 'FILE_STORAGE',
      );
    }
    if (error is DioException &&
        error.response?.statusCode == 403 &&
        error.requestOptions.path.contains('offline/request-download') &&
        AppFailure.from(error).code != 'DEVICE_REVOKED') {
      return const AppFailure(
        'Máy chủ chưa cho phép tải bài này. Kiểm tra quyền offline của gói và trạng thái thiết bị trước khi tải lại.',
        code: 'OFFLINE_FORBIDDEN',
      );
    }
    if (error is DioException &&
        error.response?.statusCode == 429 &&
        error.requestOptions.path.contains('offline/request-download')) {
      // The existing backend uses 429 for the device download quota.
      return const AppFailure(
        'Chưa thể cấp thêm bản tải. Kiểm tra hạn mức gói và đồng bộ các bản đã xóa trước khi thử lại.',
        code: 'DOWNLOAD_LIMIT',
      );
    }
    return AppFailure.from(error);
  }
}
