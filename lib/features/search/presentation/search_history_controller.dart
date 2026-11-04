import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/search_history_repository.dart';

final searchHistoryProvider =
    StateNotifierProvider.autoDispose<
      SearchHistoryController,
      AsyncValue<List<SearchHistoryEntry>>
    >((ref) {
      final user = ref.watch(
        sessionControllerProvider.select((s) => s.session?.user.id),
      );
      return SearchHistoryController(
        ref.watch(searchHistoryRepositoryProvider),
        user != null,
      )..load();
    });

class SearchHistoryController
    extends StateNotifier<AsyncValue<List<SearchHistoryEntry>>> {
  SearchHistoryController(this.repository, this.authenticated)
    : super(const AsyncData([]));
  final SearchHistoryRepository repository;
  final bool authenticated;
  bool _busy = false;
  Future<void> load() async {
    if (!authenticated || _busy) return;
    _busy = true;
    state = const AsyncLoading();
    try {
      final items = await repository.load();
      if (mounted) state = AsyncData(items);
    } catch (error, stack) {
      if (mounted) state = AsyncError(AppFailure.from(error), stack);
    } finally {
      _busy = false;
    }
  }

  Future<void> record(String text, bool mood) async {
    if (!authenticated ||
        _busy ||
        text.trim().isEmpty ||
        text.trim().length > 255) {
      return;
    }
    _busy = true;
    try {
      await repository.record(text.trim(), mood);
    } catch (_) {
      // Search results remain usable if the optional history write fails.
    } finally {
      _busy = false;
    }
    if (mounted) await load();
  }

  Future<void> remove(String? id) async {
    if (!authenticated || _busy) return;
    _busy = true;
    try {
      await repository.remove(id);
      if (mounted) {
        state = AsyncData(
          id == null
              ? []
              : (state.valueOrNull ?? []).where((e) => e.id != id).toList(),
        );
      }
    } catch (error, stack) {
      if (mounted) state = AsyncError(AppFailure.from(error), stack);
    } finally {
      _busy = false;
    }
  }
}
