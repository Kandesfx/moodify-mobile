import 'dart:convert';

import '../../../core/storage/key_value_store.dart';
import '../domain/auth_session.dart';

class SessionStorage {
  const SessionStorage(this._store, {required this.namespace});
  final KeyValueStore _store;
  // Scope credentials to API origin/base so a dev build cannot send production tokens to another host.
  final String namespace;
  String get key => 'moodify.session.v1.${Uri.encodeComponent(namespace)}';

  Future<AuthSession?> read() async {
    final value = await _store.read(key);
    if (value == null) return null;
    final json = jsonDecode(value);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid stored session');
    }
    return AuthSession.fromStored(json);
  }

  Future<void> write(AuthSession value) =>
      _store.write(key, jsonEncode(value.toStored()));
  Future<void> clear() => _store.delete(key);
}
