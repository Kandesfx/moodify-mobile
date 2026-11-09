import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/app/bootstrap.dart';
import 'package:moodify_flutter/core/config/app_config.dart';
import 'package:moodify_flutter/features/auth/domain/auth_session.dart';
import 'package:moodify_flutter/features/auth/domain/session_state.dart';
import 'package:moodify_flutter/features/auth/presentation/session_controller.dart';
import 'package:moodify_flutter/features/catalog/domain/catalog_models.dart';
import 'package:moodify_flutter/features/home/data/recommendation_repository.dart';
import 'package:moodify_flutter/features/home/domain/recommendation_models.dart';
import 'package:moodify_flutter/features/home/presentation/recommendation_controller.dart';
import 'package:moodify_flutter/features/home/presentation/widgets/personalized_mix_detail_sheet.dart';
import 'package:moodify_flutter/features/home/presentation/widgets/recommendation_section_widget.dart';

AuthSession _buildTestSession() => AuthSession(
  accessToken: 'tok',
  refreshToken: 'ref',
  accessExpiresAt: DateTime.utc(2030),
  refreshExpiresAt: DateTime.utc(2030, 1, 8),
  user: const UserProfile(
    id: 'u1',
    fullName: 'User One',
    email: 'u1@moodify.local',
    username: 'user1',
    role: 'USER',
    status: 'ACTIVE',
  ),
);

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._state);
  final SessionState _state;

  @override
  SessionState build() => _state;
}

class _FakeRecommendationRepository implements RecommendationRepository {
  _FakeRecommendationRepository({this.mixData});

  final PersonalizedMix? mixData;
  final List<String> recordedEvents = [];
  final List<Map<String, dynamic>> feedbackLog = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<RecommendationHome> fetchHome({String? genre, dynamic cancel}) async {
    return const RecommendationHome(
      requestId: 'test-req',
      coldStart: false,
      sections: [],
    );
  }

  @override
  Future<PersonalizedMix> fetchPersonalizedMix(
    String mixId, {
    dynamic cancel,
  }) async {
    return mixData ??
        PersonalizedMix(
          id: mixId,
          mixType: 'DAILY_MIX',
          name: 'Daily Mix Test',
          description: 'Mô tả bản phối thử nghiệm',
          trackCount: 1,
          tracks: const [
            Track(
              id: 'trk-1',
              spotifyId: 'trk-1',
              name: 'Bài hát mẫu',
              artist: 'Nghệ sĩ mẫu',
              durationMs: 180000,
            ),
          ],
        );
  }

  @override
  Future<PersonalizedMix> refreshPersonalizedMix(String mixId) async {
    return PersonalizedMix(
      id: mixId,
      mixType: 'DAILY_MIX',
      name: 'Daily Mix Refreshed',
      description: 'Đã làm mới',
      versionId: 'v-refreshed-1',
      trackCount: 1,
      tracks: const [
        Track(
          id: 'trk-2',
          spotifyId: 'trk-2',
          name: 'Bài hát mới làm mới',
          artist: 'Nghệ sĩ mới',
          durationMs: 200000,
        ),
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> copyPersonalizedMix(
    String mixId, {
    required String versionId,
    required String requestId,
  }) async {
    return {'id': 'copied-pl-1', 'title': 'Bản sao playlist'};
  }

  @override
  Future<List<Track>> fetchMixTracks(String mixId, {dynamic cancel}) async {
    final mix = await fetchPersonalizedMix(mixId, cancel: cancel);
    return mix.tracks;
  }

  @override
  Future<void> sendFeedback({
    required String entityType,
    required String entityId,
    required String feedbackType,
    required bool enabled,
  }) async {
    feedbackLog.add({
      'entityType': entityType,
      'entityId': entityId,
      'feedbackType': feedbackType,
      'enabled': enabled,
    });
  }

  @override
  Future<void> recordEvent({
    required String eventType,
    required String attributionToken,
  }) async {
    recordedEvents.add('$eventType:$attributionToken');
  }
}

void main() {
  test('RecommendationHome and PersonalizedMix parse correctly', () {
    final home = RecommendationHome.fromJson({
      'requestId': 'req-123',
      'coldStart': false,
      'availabilityStatus': 'READY',
      'eligibleCount': 24,
      'sections': [
        {
          'id': 'personal_mixes',
          'title': 'Bản phối của bạn',
          'description': 'Cập nhật theo lịch',
          'items': [
            {
              'itemId': 'item-mix-1',
              'entityType': 'PERSONALIZED_PLAYLIST',
              'entityId': 'mix-1',
              'versionId': 'v1',
              'title': 'Daily Mix 1',
              'subtitle': 'Vũ, GREY D',
              'trackCount': 12,
              'reason': 'Dựa trên lịch sử nghe',
              'reasonCode': 'PERSONAL_MIX',
              'score': 1.0,
              'attributionToken': 'tok-123',
            },
          ],
        },
        {
          'id': 'for_you',
          'title': 'Dành cho bạn',
          'description': 'Từ những giai điệu bạn nghe gần đây',
          'items': [
            {
              'itemId': 'item-track-1',
              'entityType': 'TRACK',
              'entityId': 'trk-1',
              'title': 'Bước qua nhau',
              'subtitle': 'Vũ.',
              'imageUrl': 'https://image.example.com/cover.jpg',
              'trackCount': 1,
              'reason': '✦ Dựa trên gu nghe gần đây',
              'reasonCode': 'FOR_YOU',
              'score': 0.95,
              'attributionToken': 'tok-456',
              'track': {
                'id': 'trk-1',
                'name': 'Bước qua nhau',
                'artistName': 'Vũ.',
                'artistSpotifyId': 'art-1',
                'imageUrl': 'https://image.example.com/cover.jpg',
                'localPath': 'media/bstep.mp3',
                'durationMs': 240000,
              },
            },
          ],
        },
      ],
    });

    expect(home.requestId, 'req-123');
    expect(home.availabilityStatus, 'READY');
    expect(home.eligibleCount, 24);
    expect(home.sections.length, 2);

    final mixSection = home.sections.first;
    expect(mixSection.id, 'personal_mixes');
    expect(mixSection.items.first.title, 'Daily Mix 1');
    expect(mixSection.items.first.isPersonalizedMix, true);

    final trackSection = home.sections[1];
    expect(trackSection.id, 'for_you');
    expect(trackSection.items.first.isTrack, true);
    expect(trackSection.items.first.track?.displayName, 'Bước qua nhau');
    expect(trackSection.items.first.track?.artistId, 'art-1');

    final mix = PersonalizedMix.fromJson({
      'id': 'mix-1',
      'mixType': 'DAILY_MIX',
      'name': 'Daily Mix 1',
      'description': 'Giai điệu thư giãn',
      'versionId': 'v-101',
      'generatedAt': '2026-11-08T12:00:00Z',
      'refreshDueAt': '2026-11-09T12:00:00Z',
      'trackCount': 1,
      'tracks': [
        {
          'id': 'trk-1',
          'name': 'Bước qua nhau',
          'artistName': 'Vũ.',
          'durationMs': 240000,
        },
      ],
    });

    expect(mix.id, 'mix-1');
    expect(mix.mixType, 'DAILY_MIX');
    expect(mix.tracks.length, 1);
    expect(mix.tracks.first.name, 'Bước qua nhau');
  });

  test('HiddenItemsNotifier adds and removes hidden items', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(hiddenItemsProvider), isEmpty);
    container.read(hiddenItemsProvider.notifier).hide('TRACK:trk-1');
    expect(container.read(hiddenItemsProvider).contains('TRACK:trk-1'), true);

    container.read(hiddenItemsProvider.notifier).unhide('TRACK:trk-1');
    expect(container.read(hiddenItemsProvider).contains('TRACK:trk-1'), false);
  });

  testWidgets(
    'Scenario 1: Guest sees recommendation prompt card with login action',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith(
              () => _FakeSessionController(
                const SessionState(
                  phase: SessionPhase.signedOut,
                  session: null,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CustomScrollView(slivers: [RecommendationSectionWidget()]),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ĐỀ XUẤT THÔNG MINH AI'), findsOneWidget);
      expect(find.text('Khám phá âm nhạc theo gu của bạn'), findsOneWidget);
      expect(find.text('Đăng nhập để nhận bản phối riêng'), findsOneWidget);
    },
  );

  testWidgets(
    'Scenario 2: Cold start displays personalization learning banner',
    (tester) async {
      final fakeHome = const RecommendationHome(
        requestId: 'cold-1',
        coldStart: true,
        sections: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith(
              () => _FakeSessionController(
                SessionState(
                  phase: SessionPhase.signedIn,
                  session: _buildTestSession(),
                ),
              ),
            ),
            recommendationHomeProvider(null).overrideWith((ref) => fakeHome),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CustomScrollView(slivers: [RecommendationSectionWidget()]),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Đang cá nhân hóa trải nghiệm âm nhạc'), findsOneWidget);
      expect(
        find.textContaining('Moodify đang học gu âm nhạc của bạn'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Scenario 3: Filtered genre with no eligible catalog shows empty card and onClearGenre resets',
    (tester) async {
      var didClearGenre = false;
      final fakeHome = const RecommendationHome(
        requestId: 'empty-genre-1',
        coldStart: false,
        availabilityStatus: 'NO_ELIGIBLE_CATALOG',
        sections: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith(
              () => _FakeSessionController(
                SessionState(
                  phase: SessionPhase.signedIn,
                  session: _buildTestSession(),
                ),
              ),
            ),
            recommendationHomeProvider('Rock').overrideWith((ref) => fakeHome),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  RecommendationSectionWidget(
                    genre: 'Rock',
                    onClearGenre: () => didClearGenre = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Chưa có đề xuất riêng cho thể loại "Rock"'),
        findsOneWidget,
      );
      final clearButton = find.text('Xem đề xuất của tất cả thể loại');
      expect(clearButton, findsOneWidget);

      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(didClearGenre, isTrue);
    },
  );

  testWidgets(
    'Scenario 4 & 5: Full recommendations with mix, tracks, reason and negative feedback with Undo',
    (tester) async {
      final fakeRepo = _FakeRecommendationRepository();
      final fakeHome = RecommendationHome(
        requestId: 'full-1',
        coldStart: false,
        availabilityStatus: 'READY',
        sections: [
          RecommendationSection(
            id: 'personal_mixes',
            title: 'Bản phối của bạn',
            description: 'Dành riêng cho bạn',
            items: [
              RecommendationItem(
                itemId: 'mix-1',
                entityType: 'PERSONALIZED_PLAYLIST',
                entityId: 'mix-1',
                title: 'Daily Mix 1',
                subtitle: 'Vũ, Sơn Tùng',
                trackCount: 15,
                reason: 'Dựa trên ca sĩ yêu thích',
                reasonCode: 'PERSONAL_MIX',
                attributionToken: 'tok-mix-1',
              ),
            ],
          ),
          RecommendationSection(
            id: 'discovery',
            title: 'Khám phá gu mới',
            description: 'Những bản thu có thể bạn sẽ thích',
            items: [
              RecommendationItem(
                itemId: 'track-item-1',
                entityType: 'TRACK',
                entityId: 'trk-10',
                title: 'Nơi này có anh',
                subtitle: 'Sơn Tùng M-TP',
                trackCount: 1,
                reason: 'Gợi ý từ thói quen nghe',
                reasonCode: 'BEHAVIORAL_RESONANCE',
                attributionToken: 'tok-trk-10',
                track: const Track(
                  id: 'trk-10',
                  spotifyId: 'trk-10',
                  name: 'Nơi này có anh',
                  artist: 'Sơn Tùng M-TP',
                  artistId: 'art-sontung',
                  durationMs: 210000,
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig(apiBaseUrl: 'https://api.example.test'),
            ),
            recommendationRepositoryProvider.overrideWithValue(fakeRepo),
            sessionControllerProvider.overrideWith(
              () => _FakeSessionController(
                SessionState(
                  phase: SessionPhase.signedIn,
                  session: _buildTestSession(),
                ),
              ),
            ),
            recommendationHomeProvider(null).overrideWith((ref) => fakeHome),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CustomScrollView(slivers: [RecommendationSectionWidget()]),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra sự xuất hiện của các sections và thông tin AI
      expect(find.text('Bản phối của bạn'), findsOneWidget);
      expect(find.text('Daily Mix 1'), findsOneWidget);
      expect(find.text('Bản phối riêng'), findsOneWidget);

      expect(find.text('Khám phá gu mới'), findsOneWidget);
      expect(find.text('Nơi này có anh'), findsOneWidget);
      expect(find.text('Gợi ý từ thói quen nghe'), findsOneWidget);

      // Mở menu 3 chấm trên bài hát 'Nơi này có anh'
      final moreButtons = find.byIcon(Icons.more_vert_rounded);
      expect(moreButtons, findsWidgets);

      await tester.tap(moreButtons.last);
      await tester.pumpAndSettle();

      expect(find.text('Không quan tâm nội dung này'), findsOneWidget);
      expect(find.text('Ẩn nghệ sĩ Sơn Tùng M-TP'), findsOneWidget);

      // Bấm Không quan tâm
      await tester.tap(find.text('Không quan tâm nội dung này'));
      await tester.pumpAndSettle();

      // Bài hát đã bị ẩn khỏi giao diện
      expect(find.text('Nơi này có anh'), findsNothing);
      expect(find.text('Đã ẩn "Nơi này có anh"'), findsOneWidget);
      expect(find.text('Hoàn tác'), findsOneWidget);

      // Bấm Hoàn tác
      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();

      // Bài hát hiển thị trở lại
      expect(find.text('Nơi này có anh'), findsOneWidget);
    },
  );

  testWidgets(
    'PersonalizedMixDetailSheet displays tracks and handles actions',
    (tester) async {
      final fakeRepo = _FakeRecommendationRepository(
        mixData: const PersonalizedMix(
          id: 'mix-detail-1',
          mixType: 'DAILY_MIX',
          name: 'Daily Mix Chill',
          description: 'Bản phối thư giãn buổi chiều',
          versionId: 'v-1',
          trackCount: 1,
          tracks: [
            Track(
              id: 'trk-100',
              spotifyId: 'trk-100',
              name: 'Cơn mưa băng giá',
              artist: 'Bằng Kiều',
              durationMs: 250000,
            ),
          ],
        ),
      );

      final item = RecommendationItem(
        itemId: 'mix-item-1',
        entityType: 'PERSONALIZED_PLAYLIST',
        entityId: 'mix-detail-1',
        versionId: 'v-item-1',
        title: 'Daily Mix Chill',
        subtitle: 'Bằng Kiều',
        trackCount: 1,
        reason: 'Dành riêng cho bạn',
        reasonCode: 'DAILY_MIX',
        attributionToken: 'tok-detail-1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig(apiBaseUrl: 'https://api.example.test'),
            ),
            recommendationRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 700,
                child: PersonalizedMixDetailSheet(item: item),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Daily Mix Chill'), findsOneWidget);
      expect(find.text('Bản phối thư giãn buổi chiều'), findsOneWidget);
      expect(find.text('Phát bản phối'), findsOneWidget);
      expect(find.text('Cơn mưa băng giá'), findsOneWidget);
      expect(find.text('Bằng Kiều'), findsOneWidget);

      // Bấm Làm mới
      final refreshBtn = find.byTooltip('Làm mới bản phối');
      expect(refreshBtn, findsOneWidget);
      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      expect(find.text('Daily Mix Refreshed'), findsOneWidget);
      expect(find.text('Bài hát mới làm mới'), findsOneWidget);

      // Bấm Lưu bản sao
      final copyBtn = find.byTooltip('Lưu bản sao vào thư viện');
      expect(copyBtn, findsOneWidget);
      await tester.tap(copyBtn);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Đã lưu bản sao vào thư viện của bạn! Bạn có thể chỉnh sửa tự do.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Scenario 6: playlists_for_you renders _RecommendedPlaylistCard with trackCount, badge and action',
    (tester) async {
      final fakeRepo = _FakeRecommendationRepository();
      final fakeHome = RecommendationHome(
        requestId: 'pl-home-1',
        coldStart: false,
        availabilityStatus: 'READY',
        sections: [
          RecommendationSection(
            id: 'playlists_for_you',
            title: 'Playlist hợp gu',
            description: 'Khám phá những tuyển tập công khai phù hợp',
            items: [
              RecommendationItem(
                itemId: 'item-pl-1',
                entityType: 'PLAYLIST',
                entityId: 'playlist-abc-123',
                title: 'Tuyển tập Indie Việt',
                subtitle: 'Giai điệu nhẹ nhàng',
                trackCount: 12,
                reason: 'Nội dung gần với những bài bạn quan tâm',
                reasonCode: 'PLAYLIST_CONTENT',
                attributionToken: 'tok-pl-1',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig(apiBaseUrl: 'https://api.example.test'),
            ),
            recommendationRepositoryProvider.overrideWithValue(fakeRepo),
            sessionControllerProvider.overrideWith(
              () => _FakeSessionController(
                SessionState(
                  phase: SessionPhase.signedIn,
                  session: _buildTestSession(),
                ),
              ),
            ),
            recommendationHomeProvider(null).overrideWith((ref) => fakeHome),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CustomScrollView(slivers: [RecommendationSectionWidget()]),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Playlist hợp gu'), findsOneWidget);
      expect(find.text('Tuyển tập'), findsOneWidget);
      expect(find.text('Tuyển tập Indie Việt'), findsOneWidget);
      expect(find.text('PLAYLIST'), findsOneWidget);
      expect(find.text('12 bài hát'), findsOneWidget);
      expect(
        find.text('Nội dung gần với những bài bạn quan tâm'),
        findsOneWidget,
      );
    },
  );
}
