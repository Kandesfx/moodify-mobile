import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_failure.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/offline_repository.dart';

final offlineControllerProvider =
    StateNotifierProvider<OfflineController, OfflineState>((ref) {
      final online = ref.watch(
        sessionControllerProvider.select((s) => s.session != null),
      );
      return OfflineController(ref.watch(offlineRepositoryProvider))
        ..load(verify: online);
    });

class OfflineState {
  const OfflineState({
    this.entries = const [],
    this.busy = false,
    this.progress = 0,
    this.downloading,
    this.failure,
  });
  final List<OfflineEntry> entries;
  final bool busy;
  final double progress;
  final String? downloading;
  final AppFailure? failure;
}

class OfflineController extends StateNotifier<OfflineState> {
  OfflineController(this.repository) : super(const OfflineState());
  final OfflineRepository? repository;
  Future<void> load({bool verify = false}) async {
    if (repository == null || state.busy) return;
    await _operation(() async {
      if (verify) await repository!.verify();
    });
  }

  Future<bool> _operation(
    Future<void> Function() operation, {
    String? downloading,
  }) async {
    if (repository == null || state.busy) return false;
    state = OfflineState(
      entries: state.entries,
      busy: true,
      downloading: downloading,
    );
    try {
      await operation();
      final entries = await repository!.entries();
      if (!mounted) return false;
      state = OfflineState(entries: entries);
      return true;
    } catch (error) {
      if (mounted) {
        // A revocation may already have removed files before the failure notice.
        final entries = await repository!.entries().catchError(
          (Object _) => <OfflineEntry>[],
        );
        if (mounted) {
          state = OfflineState(
            entries: entries,
            failure: AppFailure.from(error),
          );
        }
      }
      return false;
    }
  }

  Future<bool> download(Track track) => _operation(
    () => repository!.download(track, (value) {
      if (mounted) {
        state = OfflineState(
          entries: state.entries,
          busy: true,
          downloading: track.id,
          progress: value,
        );
      }
    }),
    downloading: track.id,
  );
  Future<bool> remove(String id) => _operation(() => repository!.remove(id));
  Future<bool> verify({bool renew = false}) =>
      _operation(() => repository!.verify(renew: renew));
}
