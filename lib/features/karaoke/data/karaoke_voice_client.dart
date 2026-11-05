// The package requires RTCIceServer when passing TURN credentials but omits it
// from its public barrel; this import carries the exact server ICE contract.
// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';
import 'package:mediasfu_mediasoup_client/src/handlers/handler_interface.dart'
    show RTCIceCredentialType, RTCIceServer;

import 'karaoke_repository.dart';

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
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Device? _device;
  Transport? _send, _receive;
  MediaStream? _microphone;
  Producer? _producer;
  int _nextId = 0;
  bool connected = false;
  String? error;
  bool get microphoneOn => _producer != null;
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
    if (!connected || tracks.isEmpty) {
      throw StateError('Thành viên chưa phát âm thanh trong phòng.');
    }
    for (final track in tracks) {
      await Helper.setVolume(volume, track);
    }
    if (!hasRemoteAudio(userId)) {
      throw StateError('Âm thanh thành viên đã ngắt kết nối.');
    }
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
    if (connected) return;
    try {
      final ticket = await repository.voiceTicket(roomId);
      final uri = Uri.parse(ticket['websocketUrl'].toString());
      if (!(uri.scheme == 'wss' || uri.scheme == 'ws') ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment) {
        throw const FormatException('Địa chỉ voice không hợp lệ.');
      }
      final socket = await WebSocket.connect(uri.toString());
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
            unawaited(
              _consume(p['producerId'].toString(), p['userId'].toString()),
            );
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
      final caps = await _request('get-rtp-capabilities');
      final device = Device();
      await device.load(
        routerRtpCapabilities: RtpCapabilities.fromMap(
          caps['routerRtpCapabilities'] as Map,
        ),
      );
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
      connected = true;
      error = null;
      _notify();
      for (final raw in (auth['existingProducers'] as List? ?? const [])) {
        final p = Map<String, dynamic>.from(raw as Map);
        unawaited(_consume(p['producerId'].toString(), p['userId'].toString()));
      }
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
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
    void connectHandler(Map data, Function callback, Function errback) async {
      try {
        await _request('connect-transport', {
          'transportId': id,
          'dtlsParameters': data['dtlsParameters'].toMap(),
        });
        callback();
      } catch (e) {
        errback(e);
      }
    }

    if (direction == 'send') {
      final transport = device.createSendTransport(
        id: id,
        iceParameters: ice,
        iceCandidates: candidates,
        dtlsParameters: dtls,
        iceServers: iceServers,
        producerCallback: (Producer producer) {
          _producer = producer;
          _notify();
        },
      );
      transport.on('connect', connectHandler);
      transport.on('produce', (
        Map data,
        Function callback,
        Function errback,
      ) async {
        try {
          final result = await _request('produce', {
            'transportId': id,
            'kind': data['kind'],
            'rtpParameters': data['rtpParameters'].toMap(),
          });
          callback({'id': result['id']});
        } catch (e) {
          errback(e);
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
    return transport;
  }

  Future<void> _consume(String producerId, String userId) async {
    final device = _device;
    final transport = _receive;
    if (!connected ||
        device == null ||
        transport == null ||
        _consumers.containsKey(producerId)) {
      return;
    }
    try {
      final options = await _request('consume', {
        'transportId': transport.id,
        'producerId': producerId,
        'rtpCapabilities': device.rtpCapabilities.toMap(),
      });
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
      _consumerWaiters.remove(producerId);
      _consumers[producerId] = consumer;
      _idsByUser[userId] = producerId;
      remoteUserIds.add(userId);
      final volume = _userVolumes[userId];
      if (volume != null) await Helper.setVolume(volume, consumer.track);
      await _request('resume-consumer', {'consumerId': consumer.id});
      _notify();
    } catch (e) {
      _consumerWaiters.remove(producerId);
      if (_consumers.containsKey(producerId)) {
        _closeRemote(producerId);
      } else {
        _usersByProducer.remove(producerId);
      }
      error = 'Không nhận được âm thanh thành viên: $e';
      _notify();
    }
  }

  void _closeRemote(String producerId) {
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
    if (_producer != null) {
      final producer = _producer!;
      _producer = null;
      producer.close();
      await _microphone?.dispose();
      _microphone = null;
      await _request('close-producer', {'producerId': producer.id});
      _notify();
      return;
    }
    if (!connected || _send == null) {
      throw StateError('Đợi voice kết nối xong rồi bật micro.');
    }
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    final track = stream.getAudioTracks().first;
    _microphone = stream;
    _send!.produce(
      track: track,
      stream: stream,
      source: 'microphone',
      stopTracks: false,
    );
  }

  Future<void> disconnect() async {
    try {
      if (_socket?.readyState == WebSocket.open) {
        _socket!.add(jsonEncode({'id': 'leave', 'type': 'leave'}));
      }
    } catch (_) {}
    _producer?.close();
    _producer = null;
    await _microphone?.dispose();
    _microphone = null;
    for (final consumer in _consumers.values) {
      consumer.close();
    }
    _consumers.clear();
    _idsByUser.clear();
    _usersByProducer.clear();
    _userVolumes.clear();
    _consumerWaiters.clear();
    remoteUserIds.clear();
    _send?.close();
    _receive?.close();
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
    await disconnect();
    await onChanged.close();
  }
}
