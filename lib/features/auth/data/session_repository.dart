import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/auth_session.dart';
import '../domain/registration.dart';
import '../domain/session_state.dart';
import 'auth_remote_service.dart';
import 'device_identity.dart';
import 'session_storage.dart';

/// Owns the session lifecycle. UI observes this through the Riverpod controller.
/// Network refresh and secure writes share the same generation and serialization.
class SessionRepository {
  SessionRepository({
    required AuthRemoteService remote,
    required SessionStorage storage,
    required this.devices,
    DateTime Function()? clock,
  }) : _remote = remote,
       _storage = storage,
       _clock = clock ?? DateTime.now;

  final AuthRemoteService _remote;
  final SessionStorage _storage;
  final DeviceIdentityStore devices;
  final DateTime Function() _clock;
  final _events = StreamController<SessionState>.broadcast(sync: true);
  SessionState _state = const SessionState();
  AuthSession? _session;
  int _generation = 0;
  bool _disposed = false;
  bool _deviceNeedsSync = false;
  CancelToken _cancel = CancelToken();
  Future<void> _storageTail = Future.value();
  Future<void>? _restoreWork;
  Future<void>? _profileWork;
  Future<String>? _refreshWork;

  SessionState get state => _state;
  Stream<SessionState> get changes => _events.stream;
  int get generation => _generation;
  CancelToken get cancelToken => _cancel;

  void _emit(SessionState value) {
    if (_disposed) return;
    _state = value;
    _events.add(value);
  }

  int _newScope() {
    _generation++;
    _cancel.cancel('Session changed');
    _cancel = CancelToken();
    _refreshWork = null;
    _profileWork = null;
    _deviceNeedsSync = false;
    return _generation;
  }

  void _check(int scope) {
    if (_disposed || scope != _generation) throw AppFailure.sessionChanged;
  }

  Future<void> _serialize(Future<void> Function() action) {
    final work = _storageTail.then((_) => action());
    // A failed write must not poison later logout/cleanup operations.
    _storageTail = work.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return work;
  }

  Future<void> _commit(
    int scope,
    AuthSession Function(AuthSession?) update, {
    bool authenticate = false,
  }) => _serialize(() async {
    _check(scope);
    final next = update(_session);
    try {
      await _storage.write(next);
    } catch (_) {
      throw AppFailure.storage;
    }
    _check(scope);
    _session = next;
    _emit(
      SessionState(
        phase: authenticate ? SessionPhase.signedIn : _state.phase,
        session: next,
        isBusy: _state.isBusy,
      ),
    );
  });

  Future<void> restore() async {
    final pending = _restoreWork;
    if (pending != null) return pending;
    if (_state.phase != SessionPhase.restoring &&
        _state.phase != SessionPhase.restoreFailed) {
      return;
    }
    final work = _restore();
    _restoreWork = work;
    try {
      await work;
    } finally {
      if (identical(_restoreWork, work)) _restoreWork = null;
    }
  }

  Future<void> _restore() async {
    final scope = _generation;
    var readComplete = false;
    _emit(const SessionState());
    try {
      final stored = await _storage.read();
      readComplete = true;
      _check(scope);
      if (stored == null) {
        _emit(const SessionState(phase: SessionPhase.signedOut));
        return;
      }
      if (!stored.refreshExpiresAt.isAfter(_clock().toUtc())) {
        await expire('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
        return;
      }
      _session = stored;
      // Validate the account/device with the server before revealing stored profile data.
      await _loadProfile(scope);
      _check(scope);
      _emit(SessionState(phase: SessionPhase.signedIn, session: _session));
    } catch (error) {
      if (scope == _generation && !_disposed) {
        final failure = AppFailure.from(error);
        if ((!readComplete && error is FormatException) ||
            failure.statusCode == 401 ||
            failure.statusCode == 403) {
          await expire(failure.message);
        } else {
          _emit(
            SessionState(phase: SessionPhase.restoreFailed, failure: failure),
          );
        }
      }
    }
  }

  Future<void> login(String identifier, String password) => _authenticate(
    (device, cancel) => _remote.login(identifier, password, device, cancel),
  );

  Future<void> register(Registration input) => _authenticate(
    (_, cancel) => _remote.register(input, cancel),
    registration: true,
  );

  Future<void> _authenticate(
    Future<Map<String, dynamic>> Function(DeviceIdentity, CancelToken)
    request, {
    bool registration = false,
  }) async {
    if (_state.isBusy || _disposed) return;
    final scope = _newScope();
    _session = null;
    _emit(const SessionState(phase: SessionPhase.signedOut, isBusy: true));
    var accountCreated = false;
    try {
      final device = await devices.load();
      _check(scope);
      final response = await request(device, _cancel);
      accountCreated = registration;
      _check(scope);
      final session = AuthSession.fromAuthResponse(response, _clock());
      await _commit(scope, (_) => session, authenticate: true);
      _check(scope);
      _emit(SessionState(phase: SessionPhase.signedIn, session: _session));
      // Registration does not carry device metadata in the backend DTO.
      // A device-sync failure must not tell the user to create an already-created account again.
      _deviceNeedsSync = registration;
      await refreshProfile(syncDevice: registration);
    } catch (error) {
      if (scope != _generation || _disposed) return;
      final failure = AppFailure.from(error);
      _session = null;
      var cleanupFailed = false;
      try {
        await _serialize(() => _storage.clear());
      } catch (_) {
        cleanupFailed = true;
      }
      if (scope != _generation || _disposed) return;
      _emit(
        SessionState(
          phase: SessionPhase.signedOut,
          failure: cleanupFailed
              ? AppFailure.storage
              : accountCreated
              ? const AppFailure(
                  'Tài khoản đã được tạo nhưng chưa thể lưu phiên. Vui lòng đăng nhập lại.',
                )
              : failure,
        ),
      );
    }
  }

  Future<String> accessToken() async {
    final session = _session;
    if (session == null) {
      throw const AppFailure(
        'Vui lòng đăng nhập để tiếp tục.',
        statusCode: 401,
      );
    }
    if (session.accessExpiresAt.isAfter(
      _clock().toUtc().add(const Duration(seconds: 15)),
    )) {
      return session.accessToken;
    }
    return refreshAccessToken();
  }

  Future<String> refreshAccessToken({String? failedToken}) async {
    final current = _session;
    if (current == null) throw AppFailure.sessionChanged;
    // A late 401 using the old token must reuse the refresh that already succeeded.
    if (failedToken != null && failedToken != current.accessToken) {
      return current.accessToken;
    }
    final pending = _refreshWork;
    if (pending != null) return pending;
    final scope = _generation;
    final work = _refresh(scope, current);
    _refreshWork = work;
    try {
      return await work;
    } finally {
      if (identical(_refreshWork, work)) _refreshWork = null;
    }
  }

  Future<String> _refresh(int scope, AuthSession previous) async {
    try {
      if (!previous.refreshExpiresAt.isAfter(_clock().toUtc())) {
        throw const AppFailure(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          statusCode: 401,
        );
      }
      final response = await _remote.refresh(previous.refreshToken, _cancel);
      _check(scope);
      final next = AuthSession.fromAuthResponse(response, _clock());
      if (next.user.id != previous.user.id) {
        throw const FormatException('Refresh changed account');
      }
      await _commit(
        scope,
        (current) => next.withUser(current?.user ?? next.user),
      );
      _check(scope);
      return _session!.accessToken;
    } catch (error) {
      final failure = AppFailure.from(error);
      if (scope == _generation &&
          !_disposed &&
          (failure.statusCode == 400 ||
              failure.statusCode == 401 ||
              failure.statusCode == 403 ||
              error is FormatException)) {
        await expire(
          'Phiên đăng nhập không thể làm mới. Vui lòng đăng nhập lại.',
        );
      }
      throw failure;
    }
  }

  Future<void> refreshProfile({bool syncDevice = false}) async {
    if (_session == null || _disposed) return;
    final pending = _profileWork;
    if (pending != null) return pending;
    final scope = _generation;
    _emit(_state.withFeedback(busy: true));
    final work = _refreshProfile(
      scope,
      syncDevice: syncDevice || _deviceNeedsSync,
    );
    _profileWork = work;
    try {
      await work;
    } finally {
      if (identical(_profileWork, work)) _profileWork = null;
    }
  }

  Future<void> _refreshProfile(int scope, {required bool syncDevice}) async {
    try {
      if (syncDevice) {
        final token = await accessToken();
        final device = await devices.load();
        _check(scope);
        await _remote.registerDevice(token, device, _cancel);
        _check(scope);
        _deviceNeedsSync = false;
      }
      await _loadProfile(scope);
      _check(scope);
      _emit(SessionState(phase: SessionPhase.signedIn, session: _session));
    } catch (error) {
      if (scope != _generation || _disposed) return;
      final failure = AppFailure.from(error);
      if (failure.statusCode == 403 || failure.statusCode == 401) {
        await expire(failure.message);
      } else {
        _emit(
          _state.withFeedback(
            busy: false,
            failure: failure,
            notice: syncDevice
                ? 'Tài khoản đã được tạo. Chưa thể đồng bộ thiết bị; hãy thử lại.'
                : null,
          ),
        );
      }
    }
  }

  Future<void> _loadProfile(int scope) async {
    final device = await devices.load();
    final token = await accessToken();
    _check(scope);
    UserProfile profile;
    try {
      profile = await _remote.profile(token, device, _cancel);
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;
      _check(scope);
      final refreshed = await refreshAccessToken(failedToken: token);
      _check(scope);
      profile = await _remote.profile(refreshed, device, _cancel);
    }
    _check(scope);
    if (profile.id != _session?.user.id) {
      throw const FormatException('Profile changed account');
    }
    if (profile.status != 'ACTIVE') {
      throw const AppFailure(
        'Tài khoản hiện không hoạt động.',
        statusCode: 403,
      );
    }
    await _commit(scope, (current) => current!.withUser(profile));
  }

  Future<void> expire(String message) async {
    final scope = _newScope();
    _session = null;
    _emit(SessionState(phase: SessionPhase.signedOut, notice: message));
    try {
      await _serialize(() async {
        if (scope == _generation) await _storage.clear();
      });
    } catch (_) {
      if (scope == _generation && !_disposed) {
        _emit(
          SessionState(
            phase: SessionPhase.signedOut,
            notice: message,
            failure: const AppFailure(
              'Phiên đã đóng trên ứng dụng nhưng chưa thể xóa dữ liệu đăng nhập trên thiết bị. Vui lòng thử đăng xuất lại.',
              code: 'STORAGE_CLEAR',
            ),
          ),
        );
      }
    }
  }

  Future<void> logout() async {
    final token = _session?.accessToken;
    await expire('Bạn đã đăng xuất.');
    if (token != null) {
      // Local cleanup is authoritative; backend logout currently does not revoke issued JWTs.
      try {
        await _remote.logout(token);
      } catch (_) {
        /* local session remains closed */
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _cancel.cancel('Disposed');
    await _storageTail;
    await _events.close();
  }
}
