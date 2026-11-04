import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/core/errors/app_failure.dart';
import 'package:moodify_flutter/features/catalog/domain/catalog_models.dart';
import 'package:moodify_flutter/features/library/data/library_repository.dart';
import 'package:moodify_flutter/features/library/presentation/library_controller.dart';

import '../../support/music_harness.dart';

class _LibraryFake extends LibraryRepository {
  _LibraryFake() : super(LibraryRemoteService(Dio()));
  final ids = <String>{};
  Future<void> Function()? pending;
  bool unavailable = false;
  int requests = 0;
  @override
  Future<TrackPage> tracks(int page) async {
    requests++;
    return TrackPage(ids.isEmpty ? [] : [firstTrack], 0, 1, ids.length);
  }

  @override
  Future<Set<String>> likedIds() async => {...ids};
  @override
  Future<List<MusicCollection>> playlists() async => [];
  @override
  Future<void> like(String id, bool liked) async {
    await pending?.call();
    if (unavailable) throw const AppFailure('Unavailable');
    if (liked) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
  }
}

void main() {
  test('guest library makes no protected request', () async {
    final repository = _LibraryFake();
    final controller = LibraryController(repository, false);
    await controller.load();
    expect(repository.requests, 0);
    expect(await controller.toggleLike(firstTrack), false);
    controller.dispose();
    repository.remote.dio.close();
  });
  test(
    'like waits for server and failed mutation retains previous state',
    () async {
      final repository = _LibraryFake();
      final controller = LibraryController(repository, true);
      await controller.load();
      final pending = Completer<void>();
      repository.pending = () => pending.future;
      final operation = controller.toggleLike(firstTrack);
      expect(controller.state.likedIds, isEmpty);
      expect(controller.state.busy, true);
      pending.complete();
      expect(await operation, true);
      expect(controller.state.likedIds, {firstTrack.spotifyId});
      repository.unavailable = true;
      expect(await controller.toggleLike(firstTrack), false);
      expect(controller.state.likedIds, {firstTrack.spotifyId});
      expect(controller.state.failure, isNotNull);
      controller.dispose();
      repository.remote.dio.close();
    },
  );
  test(
    'old controller completion cannot restore private state after disposal',
    () async {
      final repository = _LibraryFake();
      final controller = LibraryController(repository, true);
      await controller.load();
      final pending = Completer<void>();
      repository.pending = () => pending.future;
      final operation = controller.toggleLike(firstTrack);
      controller.dispose();
      pending.complete();
      expect(await operation, false);
      repository.remote.dio.close();
    },
  );
}
