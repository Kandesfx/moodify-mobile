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
  Future<void>? _recording;
  int _recordGeneration = 0;
  String? _recordedId;
  String? _recordedQuery;
  bool? _recordedMood;
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

  Future<void> record(
    String text,
    bool mood, {
    String? emotion,
    double? confidence,
  }) {
    final work = _write(text, mood, emotion: emotion, confidence: confidence);
    _recording = work;
    return work;
  }

  Future<void> _write(
    String text,
    bool mood, {
    String? emotion,
    double? confidence,
  }) async {
    if (!authenticated || !mounted || text.trim().isEmpty) return;
    if (text.trim().length > 255 ||
        (mood &&
            (emotion == null ||
                emotion.trim().isEmpty ||
                confidence == null ||
                !confidence.isFinite ||
                confidence < 0 ||
                confidence > 1))) {
      state = AsyncError(
        const AppFailure(
          'Đã tìm được nhạc nhưng chưa đủ dữ liệu hợp lệ để lưu lịch sử.',
        ),
        StackTrace.current,
      );
      return;
    }
    final generation = ++_recordGeneration;
    _recordedId = null;
    _recordedQuery = text.trim();
    _recordedMood = mood;
    try {
      final id = await repository.record(
        text.trim(),
        mood,
        emotion: emotion,
        confidence: confidence,
      );
      if (!mounted || generation != _recordGeneration) return;
      _recordedId = id;
      _recordedQuery = text.trim();
      _recordedMood = mood;
      await load();
    } catch (error, stack) {
      if (mounted) state = AsyncError(AppFailure.from(error), stack);
    }
  }

  Future<void> select(String query, bool mood, String trackId) async {
    if (!authenticated) return;
    if (!mood && (query.trim() != _recordedQuery || _recordedMood != mood)) {
      await record(query, false);
    } else {
      await _recording;
    }
    if (!mounted) return;
    final id = _recordedId;
    if (!authenticated ||
        id == null ||
        query.trim() != _recordedQuery ||
        mood != _recordedMood) {
      return;
    }
    try {
      await repository.select(id, trackId);
    } catch (error, stack) {
      if (mounted) state = AsyncError(AppFailure.from(error), stack);
    }
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
