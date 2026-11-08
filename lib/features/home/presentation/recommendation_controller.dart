import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recommendation_repository.dart';
import '../domain/recommendation_models.dart';

final recommendationHomeProvider = FutureProvider.autoDispose
    .family<RecommendationHome?, String?>((ref, genre) async {
      final cancel = CancelToken();
      ref.onDispose(cancel.cancel);
      final repo = ref.watch(recommendationRepositoryProvider);
      return await repo.fetchHome(genre: genre, cancel: cancel);
    });

class HiddenItemsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void hide(String key) {
    state = {...state, key};
  }

  void unhide(String key) {
    final next = {...state}..remove(key);
    state = next;
  }
}

final hiddenItemsProvider = NotifierProvider<HiddenItemsNotifier, Set<String>>(
  HiddenItemsNotifier.new,
);
