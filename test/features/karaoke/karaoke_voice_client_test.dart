import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/karaoke/data/karaoke_repository.dart';
import 'package:moodify_flutter/features/karaoke/data/karaoke_voice_client.dart';

void main() {
  test(
    'volume preference is retained while a member has no producer',
    () async {
      final voice = KaraokeVoiceClient(KaraokeRepository(Dio()))
        ..connected = true;
      await voice.setUserVolume('member-2', 0.25);
      expect(voice.hasRemoteAudio('member-2'), isFalse);
      expect(voice.userVolume('member-2'), 0.25);
      await voice.dispose();
    },
  );

  test('volume rejects invalid values and disconnected updates', () async {
    final voice = KaraokeVoiceClient(KaraokeRepository(Dio()));
    for (final volume in [-0.1, 1.1, double.nan, double.infinity]) {
      await expectLater(
        voice.setUserVolume('member-2', volume),
        throwsArgumentError,
      );
    }
    await expectLater(voice.setUserVolume('member-2', 0.5), throwsStateError);
    expect(voice.userVolume('member-2'), 1);
    await voice.dispose();
  });

  test(
    'disposing voice closes the notifier after listeners are canceled',
    () async {
      final voice = KaraokeVoiceClient(KaraokeRepository(Dio()));
      final subscription = voice.onChanged.stream.listen((_) {});
      await subscription.cancel();
      await voice.dispose().timeout(const Duration(seconds: 1));
      expect(voice.onChanged.isClosed, isTrue);
      expect(voice.connected, isFalse);
      expect(voice.microphoneOn, isFalse);
    },
  );

  test('stalled consumer media raises and clears the receive issue', () async {
    final voice = KaraokeVoiceClient(KaraokeRepository(Dio()))
      ..connected = true;
    expect(voice.issue, isNull);
    voice.noteConsumerMedia('producer-1', mediaFlowing: false);
    expect(voice.issue, contains('chưa nhận được dữ liệu âm thanh'));
    // Một producer khác vẫn giữ cảnh báo sau khi producer đầu hồi phục.
    voice.noteConsumerMedia('producer-2', mediaFlowing: false);
    voice.noteConsumerMedia('producer-1', mediaFlowing: true);
    expect(voice.issue, isNotNull);
    voice.noteConsumerMedia('producer-2', mediaFlowing: true);
    expect(voice.issue, isNull);
    await voice.dispose();
  });

  test('issue is hidden while disconnected', () async {
    final voice = KaraokeVoiceClient(KaraokeRepository(Dio()));
    voice.noteConsumerMedia('producer-1', mediaFlowing: false);
    expect(voice.connected, isFalse);
    expect(voice.issue, isNull);
    voice.connected = true;
    expect(voice.issue, isNotNull);
    await voice.dispose();
    expect(voice.issue, isNull);
  });
}
