import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_repository.dart';
import '../domain/registration.dart';
import '../domain/session_state.dart';

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => throw StateError('SessionRepository must be wired by app bootstrap'),
);

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  SessionRepository get _repository => ref.read(sessionRepositoryProvider);

  @override
  SessionState build() {
    final repository = ref.watch(sessionRepositoryProvider);
    final subscription = repository.changes.listen((value) => state = value);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return repository.state;
  }

  Future<void> restore() => _repository.restore();
  Future<void> login(String identifier, String password) =>
      _repository.login(identifier, password);
  Future<void> socialLogin(
    String provider,
    Future<String> Function() getToken,
  ) => _repository.socialLogin(provider, getToken);
  Future<void> register(Registration input) => _repository.register(input);
  Future<void> refreshProfile() => _repository.refreshProfile();
  Future<void> logout() => _repository.logout();
}
