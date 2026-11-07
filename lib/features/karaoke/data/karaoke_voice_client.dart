// The package requires RTCIceServer when passing TURN credentials but omits it
// from its public barrel; this import carries the exact server ICE contract.
// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';
import 'package:mediasfu_mediasoup_client/src/handlers/handler_interface.dart'
    show RTCIceCredentialType, RTCIceServer;

import 'karaoke_repository.dart';

final karaokeVoiceFactoryProvider = Provider<KaraokeVoiceClient Function()>((
  ref,
) {
  final repository = ref.watch(karaokeRepositoryProvider);
  return () => KaraokeVoiceClient(repository);
});

/// Moodify's Node mediasoup signaling adapter. The server issues one-use tickets;
/// access tokens are never placed in the voice socket URL.
class KaraokeVoiceClient {
  KaraokeVoiceClient(this.repository);
  final KaraokeRepository repository;
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  final _consumers = <String, Consumer>{};
  final _idsByUser = <String, String>{};
  final _usersByProducer = <String, String>{};
  final _userVolumes = <String, double>{};
  final _consumerWaiters = <String, Completer<Consumer>>{};
  final _announcedProducers = <String, String>{};
  final _closedProducers = <String>{};
  final _consuming = <String>{};
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Device? _device;
  Transport? _send, _receive;
  MediaStream? _microphone;
  Producer? _producer;
  Completer<Producer>? _producerReady;
  bool _micChanging = false;
  bool _disposed = false;
  int _nextId = 0;
  bool connected = false;
  String? error;
  bool get microphoneOn => connected && _producer != null && !_producer!.closed;

  // Nhận âm thanh hai chiều: mobile vừa gửi (mic) vừa nhận. Lỗi trên đường
  // nhận từng bị nuốt lặng lẽ (package FlexQueue nuốt exception, UI chỉ hiện
  // lỗi lúc kết nối), khiến phòng nghe một chiều mà không có cảnh báo nào.
  // Ba lớp dưới giúp phát hiện chính xác lớp nào đang hỏng:
  // - _connectionIssue: ICE/DTLS của transport send hoặc recv.
  // - _consumeIssue: server từ chối/treo khi tạo consumer.
  // - _mediaIssue: consumer đã tạo nhưng RTP không chạm thiết bị (đo qua
  //   thống kê inbound-rtp của receiver khi nền tảng hỗ trợ).
  String? _connectionIssue;
  String? _consumeIssue;
  String? _mediaIssue;
  final _stalledProducers = <String>{};
  String? _sendState;
  String? _recvState;
  bool _audioRoutingApplied = false;

  /// Chẩn đoán đường nhận âm thanh khi đã kết nối; null nghĩa là đang khỏe.
  String? get issue {
    if (!connected) return null;
    return _connectionIssue ?? _consumeIssue ?? _mediaIssue;
  }

  final onChanged = StreamController<void>.broadcast();
  final remoteUserIds = <String>{};

  bool hasRemoteAudio(String userId) =>
      connected &&
      _usersByProducer.entries.any(
        (entry) => entry.value == userId && _consumers.containsKey(entry.key),
      );

  double userVolume(String userId) => _userVolumes[userId] ?? 1.0;

  /// Adjusts only the local playback of this participant's remote audio tracks.
  Future<void> setUserVolume(String userId, double volume) async {
    if (!volume.isFinite || volume < 0 || volume > 1) {
      throw ArgumentError.value(volume, 'volume');
    }
    final tracks = _usersByProducer.entries
        .where((entry) => entry.value == userId)
        .map((entry) => _consumers[entry.key])
        .whereType<Consumer>()
        .where((consumer) => !consumer.closed)
        .map((consumer) => consumer.track)
        .toList();
    if (!connected) throw StateError('Kết nối voice chưa sẵn sàng.');
    for (final track in tracks) {
      await Helper.setVolume(volume, track);
    }
    // Keep the preference while a participant is muted and apply it when their
    // next producer arrives, so volume can be set before they start speaking.
    _userVolumes[userId] = volume;
    _notify();
  }

  void _notify() {
    if (!onChanged.isClosed) onChanged.add(null);
  }

  Future<Map<String, dynamic>> _request(
    String type, [
    Map<String, dynamic> payload = const {},
  ]) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      return Future.error(StateError('Kết nối voice chưa sẵn sàng.'));
    }
    final id = '${DateTime.now().millisecondsSinceEpoch}-${++_nextId}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    socket.add(jsonEncode({'id': id, 'type': type, 'payload': payload}));
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('Máy chủ voice không phản hồi.');
      },
    );
  }

  Future<void> connect(int roomId) async {
    if (_disposed) throw StateError('Kết nối voice đã đóng.');
    if (connected) return;
    try {
      final ticket = await repository.voiceTicket(roomId);
      if (_disposed) return;
      final uri = Uri.parse(ticket['websocketUrl'].toString());
      if (!(uri.scheme == 'wss' || uri.scheme == 'ws') ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment) {
        throw const FormatException('Địa chỉ voice không hợp lệ.');
      }
      final socket = await WebSocket.connect(
        uri.toString(),
      ).timeout(const Duration(seconds: 10));
      if (_disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      final authenticated = Completer<Map<String, dynamic>>();
      _subscription = socket.listen(
        (raw) {
          Map<String, dynamic> message;
          try {
            message = Map<String, dynamic>.from(
              jsonDecode(raw.toString()) as Map,
            );
          } catch (_) {
            return;
          }
          final id = message['id']?.toString();
          if (id != null && _pending.containsKey(id)) {
            final pending = _pending.remove(id)!;
            if (message['ok'] == true) {
              pending.complete(
                Map<String, dynamic>.from(
                  message['payload'] as Map? ?? const {},
                ),
              );
            } else {
              pending.completeError(
                StateError(
                  (message['error'] as Map?)?['message']?.toString() ??
                      'Lệnh voice thất bại.',
                ),
              );
            }
            return;
          }
          if (message['type'] == 'authenticated' &&
              !authenticated.isCompleted) {
            authenticated.complete(
              Map<String, dynamic>.from(message['payload'] as Map? ?? const {}),
            );
          } else if (message['type'] == 'new-producer') {
            final p = Map<String, dynamic>.from(
              message['payload'] as Map? ?? const {},
            );
            final producerId = p['producerId'].toString();
            final userId = p['userId'].toString();
            _announcedProducers[producerId] = userId;
            unawaited(_consume(producerId, userId));
          } else if (message['type'] == 'producer-closed') {
            final p = Map<String, dynamic>.from(
              message['payload'] as Map? ?? const {},
            );
            _closeRemote(p['producerId']?.toString() ?? '');
          }
        },
        onDone: () {
          connected = false;
          error ??= 'Mất kết nối âm thanh phòng.';
          unawaited(disconnect());
          _notify();
        },
        onError: (Object e) {
          error = 'Không kết nối được máy chủ voice.';
          _notify();
        },
      );
      socket.add(jsonEncode({'type': 'auth', 'ticket': ticket['ticket']}));
      final auth = await authenticated.future.timeout(
        const Duration(seconds: 10),
      );
      if (_disposed) return;
      final caps = await _request('get-rtp-capabilities');
      final device = Device();
      await device.load(
        routerRtpCapabilities: RtpCapabilities.fromMap(
          caps['routerRtpCapabilities'] as Map,
        ),
      );
      if (_disposed) return;
      _device = device;
      final iceServers = ((caps['iceServers'] as List?) ?? const []).map((
        server,
      ) {
        final item = Map<String, dynamic>.from(server as Map);
        return RTCIceServer(
          urls: (item['urls'] as List? ?? [item['urls']])
              .map((e) => e.toString())
              .toList(),
          username: item['username']?.toString() ?? '',
          credential: item['credential']?.toString(),
          credentialType: RTCIceCredentialType.password,
        );
      }).toList();
      _send = await _createTransport('send', device, iceServers);
      _receive = await _createTransport('recv', device, iceServers);
      if (_disposed) {
        await disconnect();
        return;
      }
      connected = true;
      error = null;
      _applyAudioRouting();
      _notify();
      for (final raw in (auth['existingProducers'] as List? ?? const [])) {
        final p = Map<String, dynamic>.from(raw as Map);
        _announcedProducers[p['producerId'].toString()] = p['userId']
            .toString();
      }
      for (final entry in _announcedProducers.entries.toList()) {
        unawaited(_consume(entry.key, entry.value));
      }
    } catch (e) {
      error = 'Không kết nối được âm thanh phòng. Hãy thử kết nối lại.';
      await disconnect();
      _notify();
      rethrow;
    }
  }

  Future<Transport> _createTransport(
    String direction,
    Device device,
    List<RTCIceServer> iceServers,
  ) async {
    final o = await _request('create-transport', {'direction': direction});
    final id = o['id'].toString();
    final ice = IceParameters.fromMap(o['iceParameters'] as Map);
    final candidates = (o['iceCandidates'] as List)
        .map((x) => IceCandidate.fromMap(x as Map))
        .toList();
    final dtls = DtlsParameters.fromMap(o['dtlsParameters'] as Map);
    void connectHandler(Map data) async {
      final callback = data['callback'] as Function;
      final errback = data['errback'] as Function;
      try {
        await _request('connect-transport', {
          'transportId': id,
          'dtlsParameters': data['dtlsParameters'].toMap(),
        });
        callback(null);
      } catch (e) {
        errback(e);
        final ready = _producerReady;
        if (ready != null && !ready.isCompleted) ready.completeError(e);
      }
    }

    if (direction == 'send') {
      late final Transport transportForProducer;
      final transport = device.createSendTransport(
        id: id,
        iceParameters: ice,
        iceCandidates: candidates,
        dtlsParameters: dtls,
        iceServers: iceServers,
        producerCallback: (Producer producer) {
          if (_disposed || !identical(_send, transportForProducer)) {
            producer.close();
            return;
          }
          if (_producerReady == null || _producerReady!.isCompleted) {
            producer.close();
            unawaited(
              _request('close-producer', {
                'producerId': producer.id,
              }).catchError((_) => <String, dynamic>{}),
            );
            return;
          }
          _producer = producer;
          final ready = _producerReady;
          if (ready != null && !ready.isCompleted) ready.complete(producer);
          _notify();
        },
      );
      transport.on('connect', connectHandler);
      transport.on('connectionstatechange', (state) {
        _noteTransportState('send', state);
      });
      transportForProducer = transport;
      transport.on('produce', (Map data) async {
        final callback = data['callback'] as Function;
        final errback = data['errback'] as Function;
        try {
          final result = await _request('produce', {
            'transportId': id,
            'kind': data['kind'],
            'rtpParameters': data['rtpParameters'].toMap(),
          });
          callback(result['id'].toString());
        } catch (e) {
          errback(e);
          final ready = _producerReady;
          if (ready != null && !ready.isCompleted) ready.completeError(e);
        }
      });
      return transport;
    }
    final transport = device.createRecvTransport(
      id: id,
      iceParameters: ice,
      iceCandidates: candidates,
      dtlsParameters: dtls,
      iceServers: iceServers,
      consumerCallback: (Consumer consumer, Function? accept) {
        final waiter = _consumerWaiters[consumer.producerId];
        if (waiter != null && !waiter.isCompleted) waiter.complete(consumer);
        accept?.call();
      },
    );
    transport.on('connect', connectHandler);
    transport.on('connectionstatechange', (state) {
      _noteTransportState('recv', state);
    });
    return transport;
  }

  /// Ghi lại trạng thái ICE/DTLS của từng transport để UI cảnh báo ngay khi
  /// đường truyền hỏng thay vì im lặng đến khi consumer timeout.
  void _noteTransportState(String direction, Object? state) {
    final value = state is Map
        ? state['connectionState']?.toString()
        : state?.toString();
    if (value == null) return;
    if (direction == 'send') {
      _sendState = value;
    } else {
      _recvState = value;
    }
    const broken = {'failed', 'disconnected', 'closed'};
    if (broken.contains(value)) {
      _connectionIssue = direction == 'send'
          ? 'Mất đường truyền gửi âm thanh (ICE). Mic có thể không tới được máy chủ. Hãy kết nối lại.'
          : 'Mất đường truyền nhận âm thanh (ICE). Kiểm tra mạng rồi kết nối lại.';
    } else if (value == 'connected' || value == 'completed') {
      final other = direction == 'send' ? _recvState : _sendState;
      final otherBroken = other == null || !broken.contains(other);
      if (otherBroken) _connectionIssue = null;
    }
    _notify();
  }

  /// Điều hướng loa: mặc định loa ngoài, ưu tiên tai nghe Bluetooth nếu đang
  /// nối (thói quen của app mediasfu); không đặt lại khi đã áp dụng phiên này.
  Future<void> _applyAudioRouting() async {
    if (_audioRoutingApplied || _disposed) return;
    _audioRoutingApplied = true;
    try {
      await Helper.ensureAudioSession();
      if (Platform.isAndroid) {
        await Helper.setSpeakerphoneOnButPreferBluetooth();
      }
    } catch (_) {
      _audioRoutingApplied = false;
    }
  }

  Future<void> _consume(String producerId, String userId) async {
    final device = _device;
    final transport = _receive;
    if (!connected ||
        device == null ||
        transport == null ||
        _consumers.containsKey(producerId) ||
        _closedProducers.contains(producerId) ||
        !_consuming.add(producerId)) {
      return;
    }
    try {
      final options = await _request('consume', {
        'transportId': transport.id,
        'producerId': producerId,
        'rtpCapabilities': device.rtpCapabilities.toMap(),
      });
      if (_disposed || !connected || _closedProducers.contains(producerId)) {
        return;
      }
      final ready = Completer<Consumer>();
      _consumerWaiters[producerId] = ready;
      _usersByProducer[producerId] = userId;
      transport.consume(
        id: options['id'].toString(),
        producerId: producerId,
        peerId: userId,
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        rtpParameters: RtpParameters.fromMap(options['rtpParameters'] as Map),
        accept: () {},
      );
      final consumer = await ready.future.timeout(const Duration(seconds: 10));
      if (_disposed || !connected || _closedProducers.contains(producerId)) {
        consumer.close();
        return;
      }
      _consumerWaiters.remove(producerId);
      _consumers[producerId] = consumer;
      _idsByUser[userId] = producerId;
      remoteUserIds.add(userId);
      final volume = _userVolumes[userId];
      if (volume != null) await Helper.setVolume(volume, consumer.track);
      await _request('resume-consumer', {'consumerId': consumer.id});
      _consumeIssue = null;
      unawaited(_verifyConsumerMedia(producerId, consumer));
      _notify();
    } catch (e) {
      _consumerWaiters.remove(producerId);
      if (_consumers.containsKey(producerId)) {
        _closeRemote(producerId);
      } else {
        _usersByProducer.remove(producerId);
      }
      if (!_disposed && connected && !_closedProducers.contains(producerId)) {
        final recvBroken =
            _recvState == 'failed' ||
            _recvState == 'disconnected' ||
            _recvState == 'closed';
        _consumeIssue = recvBroken
            ? 'Không nhận được âm thanh thành viên vì đường truyền xuống thiết bị đang hỏng (ICE). Hãy kết nối lại.'
            : 'Không nhận được âm thanh thành viên. Hãy thử kết nối lại.';
      }
      _notify();
    } finally {
      _consumerWaiters.remove(producerId);
      _consuming.remove(producerId);
    }
  }

  /// Sau khi resume, đợi một nhịp rồi kiểm tra RTP đã tới thiết bị chưa qua
  /// thống kê của receiver (`inbound-rtp.bytesReceived`). Trên nền tảng không
  /// đọc được thống kê thì bỏ qua, không báo nhầm.
  Future<void> _verifyConsumerMedia(
    String producerId,
    Consumer consumer,
  ) async {
    await Future<void>.delayed(const Duration(seconds: 5));
    if (_disposed || !connected || consumer.closed) return;
    if (!identical(_consumers[producerId], consumer)) return;
    final flowing = await _consumerMediaFlowing(consumer);
    if (flowing != null && !_disposed && connected && !consumer.closed) {
      noteConsumerMedia(producerId, mediaFlowing: flowing);
    }
  }

  /// null = không xác định được trên nền tảng này (ví dụ Windows desktop).
  Future<bool?> _consumerMediaFlowing(Consumer consumer) async {
    if (consumer.track.muted == true) return false;
    final receiver = consumer.rtpReceiver;
    if (receiver == null) return null;
    try {
      final stats = await receiver.getStats().timeout(
        const Duration(seconds: 5),
        onTimeout: () => const [],
      );
      for (final report in stats) {
        final values = Map<String, dynamic>.from(report.values);
        final type = report.type;
        if (type != 'inbound-rtp' && type != 'inboundrtp') continue;
        final bytes = values['bytesReceived'];
        if (bytes is num) return bytes > 0;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Cập nhật trạng thái có dữ liệu âm thanh của một consumer.
  @visibleForTesting
  void noteConsumerMedia(String producerId, {required bool mediaFlowing}) {
    final changed = mediaFlowing
        ? _stalledProducers.remove(producerId)
        : _stalledProducers.add(producerId);
    if (!changed) return;
    _mediaIssue = _stalledProducers.isEmpty
        ? null
        : 'Đã kết nối voice nhưng chưa nhận được dữ liệu âm thanh từ máy chủ. '
              'Kiểm tra mạng (Wi-Fi/VPN/TURN) rồi kết nối lại.';
    _notify();
  }

  void _closeRemote(String producerId) {
    _closedProducers.add(producerId);
    _announcedProducers.remove(producerId);
    if (_stalledProducers.remove(producerId) && _stalledProducers.isEmpty) {
      _mediaIssue = null;
    }
    final consumer = _consumers.remove(producerId);
    if (consumer != null) {
      final userId = _usersByProducer.remove(producerId);
      if (userId != null) {
        if (!_usersByProducer.containsValue(userId)) {
          _idsByUser.remove(userId);
          remoteUserIds.remove(userId);
        }
      }
      consumer.close();
    }
    _notify();
  }

  Future<void> toggleMicrophone() async {
    if (_micChanging) return;
    _micChanging = true;
    try {
      if (_producer != null) {
        final producer = _producer!;
        _producer = null;
        producer.close();
        await _releaseMicrophone();
        _notify();
        await _request('close-producer', {'producerId': producer.id});
        return;
      }
      if (!connected || _send == null) {
        throw StateError('Đợi voice kết nối xong rồi bật micro.');
      }
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      if (_disposed || !connected || _send == null) {
        for (final track in stream.getTracks()) {
          await track.stop();
        }
        await stream.dispose();
        throw StateError('Kết nối voice đã đóng.');
      }
      final track = stream.getAudioTracks().first;
      _microphone = stream;
      final ready = Completer<Producer>();
      _producerReady = ready;
      _send!.produce(
        track: track,
        stream: stream,
        source: 'microphone',
        stopTracks: false,
      );
      await ready.future.timeout(const Duration(seconds: 12));
    } catch (_) {
      _producer?.close();
      _producer = null;
      await _releaseMicrophone();
      rethrow;
    } finally {
      _producerReady = null;
      _micChanging = false;
      _notify();
    }
  }

  Future<void> _releaseMicrophone() async {
    final stream = _microphone;
    _microphone = null;
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      await track.stop();
    }
    await stream.dispose();
  }

  Future<void> disconnect() async {
    connected = false;
    try {
      if (_socket?.readyState == WebSocket.open) {
        _socket!.add(jsonEncode({'id': 'leave', 'type': 'leave'}));
      }
    } catch (_) {}
    _producer?.close();
    _producer = null;
    await _releaseMicrophone();
    for (final consumer in _consumers.values) {
      consumer.close();
    }
    _consumers.clear();
    _idsByUser.clear();
    _usersByProducer.clear();
    _userVolumes.clear();
    _consumerWaiters.clear();
    _announcedProducers.clear();
    _closedProducers.clear();
    _consuming.clear();
    _stalledProducers.clear();
    _connectionIssue = null;
    _consumeIssue = null;
    _mediaIssue = null;
    _sendState = null;
    _recvState = null;
    _audioRoutingApplied = false;
    remoteUserIds.clear();
    await _send?.close();
    await _receive?.close();
    _send = null;
    _receive = null;
    _device = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
    connected = false;
    _pending.clear();
    _notify();
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await onChanged.close();
  }
}
