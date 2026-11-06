import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/auth/presentation/session_controller.dart';
import 'package:moodify_flutter/features/auth/domain/session_state.dart';
import 'package:moodify_flutter/features/auth/domain/auth_session.dart';
import 'package:moodify_flutter/features/karaoke/data/karaoke_repository.dart';
import 'package:moodify_flutter/features/karaoke/data/karaoke_room_live_client.dart';
import 'package:moodify_flutter/features/karaoke/data/karaoke_voice_client.dart';
import 'package:moodify_flutter/features/catalog/data/catalog_repository.dart';
import 'package:moodify_flutter/features/player/data/ad_policy.dart';
import 'package:moodify_flutter/features/player/presentation/player_controller.dart';
import '../../support/music_harness.dart';
import 'package:moodify_flutter/features/karaoke/presentation/karaoke_screen.dart';

import '../../support/auth_harness.dart';

class TestAdPolicy extends AdPolicyService {
  TestAdPolicy() : super(Dio(), MemoryStore(), 'test');
  @override
  Future<AdDecision> decide(String? userId) async =>
      const AdDecision(false, false);
}

/// WS phòng karaoke chạy thật trong test sẽ mở socket ngoài FakeAsync, nên
/// thay bằng client trơ như cách test voice đang làm.
class TestKaraokeRoomLive extends KaraokeRoomLiveClient {
  TestKaraokeRoomLive()
    : super(
        uri: Uri.parse('wss://api.example.test/api/ws/karaoke'),
        accessToken: () async => 'test-token',
        deviceUuid: () async => 'test-device',
      );

  @override
  Future<void> enter(int roomId) async {}
}

class TestSessionController extends SessionController {
  @override
  SessionState build() => SessionState(
    phase: SessionPhase.signedIn,
    session: AuthSession.fromAuthResponse(authResponse(), DateTime.now()),
  );
}

class TestKaraokeRepository extends KaraokeRepository {
  TestKaraokeRepository() : super(Dio());
  int creates = 0;
  int joins = 0;
  int scoreStarts = 0;
  String? receivedCode;
  List<Map<String, dynamic>> initialRooms = [];
  Map<String, dynamic>? detail;
  final queueRequests = <String>[];
  final removals = <int>[];
  @override
  Future<Map<String, dynamic>> room(int id) async => detail!;
  @override
  Future<List<Map<String, dynamic>>> tracks({String query = ''}) async => [
    {'songId': 'song-1', 'title': 'Bài thứ nhất', 'artist': 'Ca sĩ'},
    {'songId': 'song-2', 'title': 'Bài thứ hai', 'artist': 'Ca sĩ'},
  ];
  @override
  Future<void> addQueue(int id, String trackId) async {
    queueRequests.add(trackId);
    detail = {
      ...detail!,
      'queue': [
        ...detail!['queue'] as List,
        {
          'id': queueRequests.length,
          'title': trackId == 'song-1' ? 'Bài thứ nhất' : 'Bài thứ hai',
          'artist': 'Ca sĩ',
          'requestedByMe': true,
        },
      ],
    };
  }

  @override
  Future<void> removeQueue(int id, int itemId) async {
    removals.add(itemId);
    detail = {
      ...detail!,
      'queue': (detail!['queue'] as List)
          .where((item) => item['id'] != itemId)
          .toList(),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> rooms() async => initialRooms;
  @override
  Future<void> leaveRoom(int id) async {}
  @override
  Future<Map<String, dynamic>> createRoom({
    required String name,
    required bool isPrivate,
  }) async {
    creates++;
    return {'id': 1, 'name': name};
  }

  @override
  Future<Map<String, dynamic>> startRoomScoreSession(int roomId) async {
    scoreStarts++;
    return {'sessionId': 'session-1', 'status': 'collecting', 'roomId': roomId};
  }

  @override
  Future<Map<String, dynamic>> joinRoom(int id, {String? inviteCode}) async {
    joins++;
    receivedCode = inviteCode;
    return detail ??
        {
          'id': id,
          'name': 'Phòng thử',
          'members': [],
          'queue': [],
          'memberCount': 1,
          'maxMembers': 6,
          'canManage': true,
          'playback': {'status': 'IDLE'},
        };
  }
}

class TestKaraokeVoice extends KaraokeVoiceClient {
  TestKaraokeVoice() : super(KaraokeRepository(Dio()));
  int connections = 0;
  bool mic = false;
  bool disposed = false;
  bool failConnection = false;
  @override
  bool get microphoneOn => mic;
  @override
  Future<void> connect(int roomId) async {
    connections++;
    connected = !failConnection;
    error = failConnection ? 'Không kết nối được âm thanh phòng.' : null;
    onChanged.add(null);
  }

  @override
  Future<void> toggleMicrophone() async {
    mic = !mic;
    onChanged.add(null);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    mic = false;
    connected = false;
    unawaited(onChanged.close());
  }
}

void main() {
  testWidgets('create room closes the dialog and displays room details', (
    tester,
  ) async {
    final repository = TestKaraokeRepository();
    final music = MusicRepositoryFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(TestSessionController.new),
          karaokeRepositoryProvider.overrideWithValue(repository),
          karaokeVoiceFactoryProvider.overrideWithValue(TestKaraokeVoice.new),
          karaokeRoomLiveFactoryProvider.overrideWithValue(
            (roomId) => TestKaraokeRoomLive(),
          ),
          adPolicyProvider.overrideWithValue(TestAdPolicy()),
          playbackEngineFactoryProvider.overrideWithValue(
            () async => PlaybackEngineFake(),
          ),
          catalogRepositoryProvider.overrideWithValue(music),
        ],
        child: const MaterialApp(home: KaraokeRoomsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tạo phòng'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Phòng thử');
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo'));
    await tester.pumpAndSettle();
    expect(repository.creates, 1);
    expect(repository.joins, 1);
    expect(find.text('Phòng thử'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Hàng đợi đang trống.'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Hàng đợi đang trống.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    music.remote.dio.close();
  });
  testWidgets(
    'joining private room closes invite dialog without disposing its input early',
    (tester) async {
      final repository = TestKaraokeRepository()
        ..initialRooms = [
          {
            'id': 9,
            'name': 'Phòng riêng',
            'visibility': 'PRIVATE',
            'memberCount': 1,
            'maxMembers': 6,
          },
        ];
      final music = MusicRepositoryFake();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith(TestSessionController.new),
            karaokeRepositoryProvider.overrideWithValue(repository),
            karaokeVoiceFactoryProvider.overrideWithValue(TestKaraokeVoice.new),
            karaokeRoomLiveFactoryProvider.overrideWithValue(
              (roomId) => TestKaraokeRoomLive(),
            ),
            adPolicyProvider.overrideWithValue(TestAdPolicy()),
            playbackEngineFactoryProvider.overrideWithValue(
              () async => PlaybackEngineFake(),
            ),
            catalogRepositoryProvider.overrideWithValue(music),
          ],
          child: const MaterialApp(home: KaraokeRoomsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phòng riêng'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ABC123');
      await tester.tap(find.widgetWithText(FilledButton, 'Tham gia'));
      await tester.pumpAndSettle();
      expect(repository.receivedCode, 'ABC123');
      await tester.scrollUntilVisible(
        find.text('Hàng đợi đang trống.'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Hàng đợi đang trống.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      music.remote.dio.close();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('create room dialog fits a small screen and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = TestKaraokeRepository();
    final music = MusicRepositoryFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(TestSessionController.new),
          karaokeRepositoryProvider.overrideWithValue(repository),
          karaokeVoiceFactoryProvider.overrideWithValue(TestKaraokeVoice.new),
          karaokeRoomLiveFactoryProvider.overrideWithValue(
            (roomId) => TestKaraokeRoomLive(),
          ),
          adPolicyProvider.overrideWithValue(TestAdPolicy()),
          playbackEngineFactoryProvider.overrideWithValue(
            () async => PlaybackEngineFake(),
          ),
          catalogRepositoryProvider.overrideWithValue(music),
        ],
        child: const MaterialApp(home: KaraokeRoomsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tạo phòng'));
    await tester.pumpAndSettle();
    expect(find.text('Tạo phòng hát'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(repository.creates, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    music.remote.dio.close();
  });
  testWidgets(
    'room with music, members and queue fits a small screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repository = TestKaraokeRepository()
        ..initialRooms = [
          {
            'id': 9,
            'name': 'Phòng thực tế',
            'visibility': 'PUBLIC',
            'memberCount': 1,
            'maxMembers': 6,
          },
        ]
        ..detail = {
          'id': 9,
          'name': 'Phòng thực tế',
          'visibility': 'PUBLIC',
          'memberCount': 1,
          'maxMembers': 6,
          'canManage': true,
          'members': [
            {'name': 'Người hát có tên dài', 'host': true},
          ],
          'queue': [
            {
              'id': 1,
              'title': 'Bài trong hàng đợi',
              'artist': 'Nghệ sĩ',
              'requestedByMe': true,
            },
          ],
          'playback': {
            'status': 'PAUSED',
            'track': {
              'title': 'Bài đang phát',
              'artist': 'Nghệ sĩ',
              'lyricsPlain': 'Một câu hát',
            },
          },
        };
      final music = MusicRepositoryFake();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith(TestSessionController.new),
            karaokeRepositoryProvider.overrideWithValue(repository),
            karaokeVoiceFactoryProvider.overrideWithValue(TestKaraokeVoice.new),
            karaokeRoomLiveFactoryProvider.overrideWithValue(
              (roomId) => TestKaraokeRoomLive(),
            ),
            adPolicyProvider.overrideWithValue(TestAdPolicy()),
            playbackEngineFactoryProvider.overrideWithValue(
              () async => PlaybackEngineFake(),
            ),
            catalogRepositoryProvider.overrideWithValue(music),
          ],
          child: const MaterialApp(home: KaraokeRoomsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Phòng thực tế'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Phòng thực tế'));
      await tester.pumpAndSettle();
      expect(find.text('Bài đang phát'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Bài trong hàng đợi'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Bài trong hàng đợi'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Thêm bài'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Thêm bài'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      music.remote.dio.close();
    },
  );
  testWidgets(
    'playback run opens the shared score session without a manual button',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repository = TestKaraokeRepository()
        ..initialRooms = [
          {
            'id': 9,
            'name': 'Phòng chấm điểm',
            'visibility': 'PUBLIC',
            'memberCount': 1,
            'maxMembers': 6,
          },
        ]
        ..detail = {
          'id': 9,
          'name': 'Phòng chấm điểm',
          'visibility': 'PUBLIC',
          'memberCount': 1,
          'maxMembers': 6,
          'canManage': true,
          'members': [
            {'name': 'Chủ phòng', 'host': true},
          ],
          'queue': [],
          'playback': {
            'status': 'PAUSED',
            'playbackRunId': 'run-1',
            'track': {
              'title': 'Bài đang phát',
              'artist': 'Nghệ sĩ',
              'durationMs': 200000,
              'lyricsPlain': 'Một câu hát',
            },
          },
        };
      final music = MusicRepositoryFake();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith(TestSessionController.new),
            karaokeRepositoryProvider.overrideWithValue(repository),
            karaokeVoiceFactoryProvider.overrideWithValue(TestKaraokeVoice.new),
            karaokeRoomLiveFactoryProvider.overrideWithValue(
              (roomId) => TestKaraokeRoomLive(),
            ),
            adPolicyProvider.overrideWithValue(TestAdPolicy()),
            playbackEngineFactoryProvider.overrideWithValue(
              () async => PlaybackEngineFake(),
            ),
            catalogRepositoryProvider.overrideWithValue(music),
          ],
          child: const MaterialApp(home: KaraokeRoomsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Phòng chấm điểm'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Phòng chấm điểm'));
      await tester.pumpAndSettle();
      expect(repository.scoreStarts, 1);
      expect(find.text('Bắt đầu chấm điểm nhóm'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Thêm bài'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Thêm bài'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      music.remote.dio.close();
    },
  );

  Future<void> openRoom(
    WidgetTester tester,
    TestKaraokeRepository repository,
    KaraokeVoiceClient Function() voiceFactory,
  ) async {
    final music = MusicRepositoryFake();
    addTearDown(() => music.remote.dio.close());
    repository.initialRooms = [
      {'id': 9, 'name': 'Phòng kiểm thử', 'visibility': 'PUBLIC'},
    ];
    repository.detail = {
      'id': 9,
      'name': 'Phòng kiểm thử',
      'canManage': true,
      'members': [
        {'userId': 2, 'name': 'Bạn hát', 'host': false},
      ],
      'queue': [],
      'playback': {'status': 'IDLE'},
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(TestSessionController.new),
          karaokeRepositoryProvider.overrideWithValue(repository),
          karaokeVoiceFactoryProvider.overrideWithValue(voiceFactory),
          karaokeRoomLiveFactoryProvider.overrideWithValue(
            (roomId) => TestKaraokeRoomLive(),
          ),
          adPolicyProvider.overrideWithValue(TestAdPolicy()),
          playbackEngineFactoryProvider.overrideWithValue(
            () async => PlaybackEngineFake(),
          ),
          catalogRepositoryProvider.overrideWithValue(music),
        ],
        child: const MaterialApp(home: KaraokeRoomsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phòng kiểm thử'));
    await tester.pumpAndSettle();
  }

  testWidgets('queue allows a second song and removes only the selected item', (
    tester,
  ) async {
    final repository = TestKaraokeRepository();
    await openRoom(tester, repository, TestKaraokeVoice.new);
    for (final title in ['Bài thứ nhất', 'Bài thứ hai']) {
      await tester.scrollUntilVisible(
        find.text('Thêm bài'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Thêm bài'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, title));
      await tester.pumpAndSettle();
    }
    expect(repository.queueRequests, ['song-1', 'song-2']);
    expect((repository.detail!['queue'] as List).length, 2);
    expect(find.text('Thêm bài'), findsOneWidget);
    await tester.tap(find.byTooltip('Xóa khỏi hàng đợi').first);
    await tester.pumpAndSettle();
    expect(repository.removals, [1]);
    expect((repository.detail!['queue'] as List).single['id'], 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'join connects voice, toggles personal mic and releases on leave',
    (tester) async {
      final voice = TestKaraokeVoice();
      await openRoom(tester, TestKaraokeRepository(), () => voice);
      expect(voice.connections, 1);
      await tester.tap(find.byTooltip('Bật mic của tôi'));
      await tester.pumpAndSettle();
      expect(voice.microphoneOn, isTrue);
      await tester.tap(find.byTooltip('Tắt mic của tôi'));
      await tester.pumpAndSettle();
      expect(voice.microphoneOn, isFalse);
      await tester.tap(find.byTooltip('Rời phòng'));
      await tester.pumpAndSettle();
      expect(voice.disposed, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('member volume can be saved before they enable their mic', (
    tester,
  ) async {
    final voice = TestKaraokeVoice();
    await openRoom(tester, TestKaraokeRepository(), () => voice);
    await tester.scrollUntilVisible(
      find.byType(Tooltip).last,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byTooltip('Bạn hát'));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(0.4);
    slider.onChangeEnd!(0.4);
    await tester.pumpAndSettle();
    expect(voice.userVolume('2'), 0.4);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('failed voice connection exposes retry without enabling mic', (
    tester,
  ) async {
    final failed = TestKaraokeVoice()..failConnection = true;
    final recovered = TestKaraokeVoice();
    var attempts = 0;
    await openRoom(
      tester,
      TestKaraokeRepository(),
      () => attempts++ == 0 ? failed : recovered,
    );
    // Kết nối đầu thất bại: chỉ còn icon micro trên AppBar, chạm để thử lại.
    await tester.tap(find.byTooltip('Kết nối âm thanh phòng'));
    await tester.pumpAndSettle();
    expect(failed.disposed, isTrue);
    expect(recovered.connected, isTrue);
    expect(recovered.microphoneOn, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
