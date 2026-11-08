import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/home/domain/recommendation_models.dart';
import 'package:moodify_flutter/features/home/presentation/recommendation_controller.dart';

void main() {
  test('RecommendationHome parses sections and items correctly', () {
    final home = RecommendationHome.fromJson({
      'requestId': 'req-123',
      'coldStart': false,
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
    expect(home.sections.length, 2);

    final mixSection = home.sections.first;
    expect(mixSection.id, 'personal_mixes');
    expect(mixSection.items.length, 1);
    expect(mixSection.items.first.title, 'Daily Mix 1');
    expect(mixSection.items.first.isPersonalizedMix, true);

    final trackSection = home.sections[1];
    expect(trackSection.id, 'for_you');
    expect(trackSection.items.first.isTrack, true);
    expect(trackSection.items.first.track?.hasAudio, true);
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
}
