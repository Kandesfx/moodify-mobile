import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../auth/presentation/session_controller.dart';

/// Tạo client WS cho một phòng, dùng chung cấu hình API và phiên đăng nhập
/// hiện tại — cùng kiểu với `karaokeVoiceFactoryProvider`.
final karaokeRoomLiveFactoryProvider =
    Provider<KaraokeRoomLiveClient Function(int roomId)>((ref) {
      final base = ref.watch(appConfigProvider).apiBaseUri;
      final uri = base
          .replace(scheme: base.scheme == 'https' ? 'wss' : 'ws')
          .resolve('ws/karaoke');
      final session = ref.watch(sessionRepositoryProvider);
      return (roomId) => KaraokeRoomLiveClient(
        uri: uri,
        accessToken: session.accessToken,
        deviceUuid: () async => (await session.devices.load()).uuid,
      );
    });

/// Sự kiện thời gian thực của phòng karaoke nhận từ kênh `/api/ws/karaoke` —
/// cùng giao thức với web (`use-karaoke-room-live.ts`): frame JSON thô,
/// không STOMP.
class KaraokeRoomLiveEvent {
  const KaraokeRoomLiveEvent({
    required this.type,
    this.roomId,
    this.sessionId,
    this.status,
    this.score,
    this.code,
  });

  factory KaraokeRoomLiveEvent.fromMap(Map<String, dynamic> map) {
    final score = map['score'];
    final roomId = map['roomId'];
    return KaraokeRoomLiveEvent(
      type: map['type']?.toString() ?? '',
      roomId: roomId is num ? roomId.toInt() : null,
      sessionId: map['sessionId']?.toString(),
      status: map['status']?.toString(),
      score: score is Map<String, dynamic> ? score : null,
      code: map['code']?.toString(),
    );
  }

  /// `score.updated`, `room.closed`, `playback.updated`, `member.joined`...
  final String type;
  final int? roomId;
  final String? sessionId;
  final String? status;
  final Map<String, dynamic>? score;
  final String? code;
}

/// Đường truyền của [KaraokeRoomLiveClient], tách interface để test thay được
/// socket thật.
abstract interface class KaraokeLiveSocket {
  Stream<dynamic> get events;
  void send(Object? data);
  Future<void> close();
}

class _IoLiveSocket implements KaraokeLiveSocket {
  _IoLiveSocket(this._socket);
  final WebSocket _socket;

  @override
  Stream<dynamic> get events => _socket;

  @override
  void send(Object? data) {
    if (data is String || data is List<int>) {
      _socket.add(data);
    }
  }

  @override
  Future<void> close() => _socket.close();
}

/// Kênh WebSocket thời gian thực của phòng karaoke. Xác thực bằng frame đầu
/// tiên (access token không bao giờ nằm trên URL), heartbeat 20 giây và tự
/// nối lại với backoff khi đứt kết nối bất thường — polling REST vẫn là lưới
/// dự phòng phía màn hình.
class KaraokeRoomLiveClient {
  KaraokeRoomLiveClient({
    required this.uri,
    required Future<String> Function() accessToken,
    required Future<String> Function() deviceUuid,
    @visibleForTesting
    Future<KaraokeLiveSocket> Function(Uri uri)? socketFactory,
    this.heartbeatInterval = const Duration(seconds: 20),
    this.maxBackoff = const Duration(seconds: 10),
    this.backoffStep = const Duration(milliseconds: 700),
  }) : _accessToken = accessToken,
       _deviceUuid = deviceUuid,
       _socketFactory = socketFactory ?? _openSocket;

  static Future<KaraokeLiveSocket> _openSocket(Uri uri) async =>
      _IoLiveSocket(await WebSocket.connect(uri.toString()));

  final Uri uri;
  final Future<String> Function() _accessToken;
  final Future<String> Function() _deviceUuid;
  final Future<KaraokeLiveSocket> Function(Uri uri) _socketFactory;
  final Duration heartbeatInterval;
  final Duration maxBackoff;

  /// Bước nhân đôi của backoff khi nối lại: `min(maxBackoff, step * 2^lần)`.
  final Duration backoffStep;

  final _events = StreamController<KaraokeRoomLiveEvent>.broadcast();
  KaraokeLiveSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  Timer? _reconnect;
  int _attempts = 0;
  int? _roomId;
  bool _disposed = false;

  Stream<KaraokeRoomLiveEvent> get events => _events.stream;

  /// Kết nối và đăng ký theo dõi một phòng. Gọi lại với phòng khác sẽ đóng
  /// kết nối cũ trước khi mở kết nối mới.
  Future<void> enter(int roomId) async {
    if (_disposed) return;
    if (_roomId == roomId && _socket != null) return;
    await exit();
    _roomId = roomId;
    await _open();
  }

  /// Ngừng theo dõi và đóng kết nối; hủy cả lịch nối lại đang chờ.
  Future<void> exit() async {
    _roomId = null;
    _reconnect?.cancel();
    _reconnect = null;
    await _closeSocket();
  }

  Future<void> dispose() async {
    _disposed = true;
    await exit();
    await _events.close();
  }

  Future<void> _open() async {
    final roomId = _roomId;
    if (roomId == null || _disposed) return;
    try {
      final socket = await _socketFactory(uri);
      if (_disposed || _roomId != roomId) {
        await socket.close();
        return;
      }
      _socket = socket;
      _attempts = 0;
      _subscription = socket.events.listen(
        _onFrame,
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: true,
      );
      // Frame đầu tiên vừa xác thực vừa đăng ký phòng, như web.
      socket.send(
        jsonEncode({
          'type': 'subscribeRoom',
          'roomId': roomId,
          'accessToken': await _accessToken(),
          'deviceUuid': await _deviceUuid(),
        }),
      );
      _heartbeat = Timer.periodic(heartbeatInterval, (_) {
        _socket?.send(jsonEncode({'type': 'heartbeat'}));
      });
    } catch (_) {
      _onDisconnected();
    }
  }

  void _onFrame(dynamic frame) {
    Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(frame as String);
      if (decoded is! Map<String, dynamic>) return;
      message = decoded;
    } catch (_) {
      return;
    }
    final type = message['type']?.toString() ?? '';
    if (type == 'subscribed') {
      _attempts = 0;
      return;
    }
    if (type == 'heartbeat.ack') return;
    _events.add(KaraokeRoomLiveEvent.fromMap(message));
    if (type == 'error') {
      // Máy chủ chủ động từ chối (hết phiên, không phải thành viên...):
      // ngừng nối lại để tránh vòng lặp — web cũng đóng socket 1008.
      _roomId = null;
      _reconnect?.cancel();
      _reconnect = null;
      unawaited(_closeSocket());
    }
  }

  void _onDisconnected() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _socket = null;
    final roomId = _roomId;
    if (_disposed || roomId == null || _reconnect != null) return;
    final delay = Duration(
      milliseconds: math.min(
        maxBackoff.inMilliseconds,
        backoffStep.inMilliseconds * (1 << _attempts.clamp(0, 8)),
      ),
    );
    _attempts += 1;
    _reconnect = Timer(delay, () {
      _reconnect = null;
      unawaited(_open());
    });
  }

  Future<void> _closeSocket() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;
    try {
      await socket?.close();
    } catch (_) {
      // Đóng hai lần hoặc socket đã chết đều vô hại.
    }
  }
}
