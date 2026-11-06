import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/karaoke/data/karaoke_room_live_client.dart';

class _FakeSocket implements KaraokeLiveSocket {
  final controller = StreamController<dynamic>.broadcast();
  final sent = <String>[];
  var closed = false;

  @override
  Stream<dynamic> get events => controller.stream;

  @override
  void send(Object? data) {
    if (data is String) sent.add(data);
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  void receive(Map<String, dynamic> message) {
    controller.add(jsonEncode(message));
  }

  List<Map<String, dynamic>> get sentMessages =>
      sent.map((frame) => jsonDecode(frame) as Map<String, dynamic>).toList();

  void disconnect() {
    controller.close();
  }
}

class _Harness {
  _Harness() {
    client = KaraokeRoomLiveClient(
      uri: Uri.parse('wss://api.example.test/api/ws/karaoke'),
      accessToken: () async => 'token-1',
      deviceUuid: () async => 'device-1',
      socketFactory: (uri) async {
        connections.add(_FakeSocket());
        return connections.last;
      },
      heartbeatInterval: const Duration(milliseconds: 10),
      maxBackoff: const Duration(milliseconds: 8),
      backoffStep: const Duration(milliseconds: 1),
    );
  }

  final connections = <_FakeSocket>[];
  late final KaraokeRoomLiveClient client;

  Future<void> waitUntil(bool Function() condition) => Future.doWhile(() async {
    if (condition()) return false;
    await Future<void>.delayed(const Duration(milliseconds: 2));
    return true;
  });
}

void main() {
  test('subscribes with token frame and forwards room events', () async {
    final harness = _Harness();
    final received = <KaraokeRoomLiveEvent>[];
    final done = Completer<void>();
    final subscription = harness.client.events.listen(
      received.add,
      onDone: done.complete,
    );

    await harness.client.enter(7);
    final socket = harness.connections.single;
    expect(harness.connections, hasLength(1));
    expect(socket.sentMessages.first, {
      'type': 'subscribeRoom',
      'roomId': 7,
      'accessToken': 'token-1',
      'deviceUuid': 'device-1',
    });

    socket.receive({'type': 'subscribed', 'scope': 'room', 'roomId': 7});
    socket.receive({'type': 'heartbeat.ack'});
    socket.receive({
      'type': 'score.updated',
      'roomId': 7,
      'sessionId': 'score-1',
      'status': 'completed',
      'score': {
        'score': {'overall': 88.5},
      },
    });
    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(1));
    expect(received.single.type, 'score.updated');
    expect(received.single.roomId, 7);
    expect(received.single.sessionId, 'score-1');
    expect(received.single.status, 'completed');
    expect((received.single.score?['score'] as Map)['overall'], 88.5);

    await harness.client.exit();
    expect(socket.closed, isTrue);
    await subscription.cancel();
    await harness.client.dispose();
  });

  test('sends heartbeat frames while connected', () async {
    final harness = _Harness();
    await harness.client.enter(3);
    final socket = harness.connections.single;
    socket.receive({'type': 'subscribed'});

    await Future<void>.delayed(const Duration(milliseconds: 45));
    final heartbeats = socket.sentMessages
        .where((message) => message['type'] == 'heartbeat')
        .toList();
    expect(heartbeats, isNotEmpty);

    await harness.client.exit();
    await harness.client.dispose();
  });

  test('reconnects after an abnormal disconnect', () async {
    final harness = _Harness();
    await harness.client.enter(5);
    final first = harness.connections.single;
    first.receive({'type': 'subscribed'});
    first.disconnect();

    await harness.waitUntil(() => harness.connections.length > 1);
    final second = harness.connections.last;
    expect(second, isNot(same(first)));
    expect(second.sentMessages.first['type'], 'subscribeRoom');

    await harness.client.exit();
    await harness.client.dispose();
  });

  test('server error frame stops reconnect attempts', () async {
    final harness = _Harness();
    final received = <KaraokeRoomLiveEvent>[];
    final subscription = harness.client.events.listen(received.add);
    await harness.client.enter(9);
    final socket = harness.connections.single;
    socket.receive({'type': 'error', 'code': 'ROOM_MEMBERSHIP_REQUIRED'});
    await Future<void>.delayed(Duration.zero);
    expect(socket.closed, isTrue);
    expect(received.single.type, 'error');
    expect(received.single.code, 'ROOM_MEMBERSHIP_REQUIRED');

    socket.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(harness.connections, hasLength(1));

    await subscription.cancel();
    await harness.client.dispose();
  });

  test('exit cancels a pending reconnect', () async {
    final harness = _Harness();
    await harness.client.enter(2);
    harness.connections.single.disconnect();
    await harness.client.exit();

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(harness.connections, hasLength(1));
    await harness.client.dispose();
  });
}
