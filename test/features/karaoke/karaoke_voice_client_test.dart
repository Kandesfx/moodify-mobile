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
}
