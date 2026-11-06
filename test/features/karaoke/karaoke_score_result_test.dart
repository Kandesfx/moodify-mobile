import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/karaoke/data/karaoke_score_result.dart';

void main() {
  test('parses the public score payload including sub-scores and quality', () {
    final result = KaraokeScoreResult.fromMap(const {
      'status': 'completed',
      'score': {'overall': 85, 'pitch': 70.5, 'rhythm': null, 'coverage': 92},
      'scoring_version': 'v2',
      'quality': {
        'status': 'ok',
        'warnings': ['thiếu đoạn cuối'],
      },
      'diagnostics': {
        'reference_duration_seconds': 180,
        'recording_duration_seconds': 175.5,
        'recording_start_offset_ms': 2500,
      },
    });
    expect(result.hasScore, isTrue);
    expect(result.overall, 85);
    expect(result.pitch, 70.5);
    expect(result.rhythm, isNull);
    expect(result.coverage, 92);
    expect(result.qualityStatus, 'ok');
    expect(result.qualityWarnings, ['thiếu đoạn cuối']);
    expect(result.songSeconds, 180);
    expect(result.recordingSeconds, 175.5);
    expect(result.capturedSongPercent, closeTo(100 * 175.5 / 180, 0.001));
  });

  test('keeps an empty score block scorable so the reason stays visible', () {
    final result = KaraokeScoreResult.fromMap(const {
      'status': 'completed',
      'score': {
        'overall': null,
        'pitch': null,
        'rhythm': null,
        'coverage': null,
      },
      'quality': {'status': 'insufficient_audio', 'warnings': []},
    });
    expect(result.hasScore, isTrue);
    expect(result.overall, isNull);
    expect(result.qualityStatus, 'insufficient_audio');
    expect(result.capturedSongPercent, isNull);
  });

  test('treats a missing score block as unscored', () {
    final result = KaraokeScoreResult.fromMap(const {'status': 'failed'});
    expect(result.hasScore, isFalse);
    expect(result.overall, isNull);
    expect(KaraokeScoreResult.fromMap(null).hasScore, isFalse);
  });

  test('ignores non-finite numbers', () {
    final result = KaraokeScoreResult.fromMap(const {
      'score': {'overall': double.nan},
      'diagnostics': {'recording_duration_seconds': -3},
    });
    expect(result.overall, isNull);
    expect(result.recordingSeconds, isNull);
  });

  test('captured coverage clamps against song bounds and start offset', () {
    double? percent(double song, double recording, double startOffsetMs) =>
        KaraokeScoreResult.fromMap({
          'diagnostics': {
            'reference_duration_seconds': song,
            'recording_duration_seconds': recording,
            'recording_start_offset_ms': startOffsetMs,
          },
        }).capturedSongPercent;

    // Bắt đầu ở giây 10, thu 30 giây trên bài 100 giây -> phủ 30%.
    expect(percent(100, 30, 10000), closeTo(30, 0.001));
    // Thu vượt quá cuối bài -> bị chặn lại ở 5 giây cuối.
    expect(percent(100, 20, 95000), closeTo(5, 0.001));
    // Thu dài hơn bài -> phủ trọn 100%.
    expect(percent(50, 100, 0), 100);
    // Thiếu offset -> coi như thu từ đầu bài.
    expect(
      KaraokeScoreResult.fromMap(const {
        'diagnostics': {
          'reference_duration_seconds': 100,
          'recording_duration_seconds': 25,
        },
      }).capturedSongPercent,
      25,
    );
  });
}
