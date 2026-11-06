/// Kết quả chấm điểm công khai mà máy chủ trả về cho cả hát một mình
/// (`/score/features`) lẫn hát chung (trường `score` của phiên điểm phòng).
///
/// Cùng payload với web: `{status, score: {overall, pitch, rhythm, coverage},
/// quality: {status, warnings[]}, diagnostics: {...}}` — xem
/// `karaoke-score-details.tsx` phía frontend.
class KaraokeScoreResult {
  const KaraokeScoreResult({
    this.hasScore = false,
    this.overall,
    this.pitch,
    this.rhythm,
    this.coverage,
    this.qualityStatus,
    this.qualityWarnings = const [],
    KaraokeScoreDiagnostics? diagnostics,
  }) : diagnostics = diagnostics ?? KaraokeScoreDiagnostics.empty;

  factory KaraokeScoreResult.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const KaraokeScoreResult();
    final score = map['score'];
    final scoreMap = score is Map<String, dynamic> ? score : null;
    final quality = map['quality'];
    final qualityMap = quality is Map<String, dynamic> ? quality : null;
    final warnings = qualityMap?['warnings'];
    final diagnostics = map['diagnostics'];
    return KaraokeScoreResult(
      hasScore: scoreMap != null,
      overall: _score(scoreMap?['overall']),
      pitch: _score(scoreMap?['pitch']),
      rhythm: _score(scoreMap?['rhythm']),
      coverage: _score(scoreMap?['coverage']),
      qualityStatus: qualityMap?['status']?.toString(),
      qualityWarnings: warnings is List
          ? warnings
                .map((warning) => warning.toString())
                .toList(growable: false)
          : const [],
      diagnostics: diagnostics is Map<String, dynamic>
          ? KaraokeScoreDiagnostics.fromMap(diagnostics)
          : null,
    );
  }

  static double? _score(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : null;

  /// Khối điểm có tồn tại trong phản hồi hay không. Máy chủ vẫn trả khối
  /// điểm rỗng (các giá trị null) khi chất lượng thu không đủ để chấm.
  final bool hasScore;

  final double? overall;
  final double? pitch;
  final double? rhythm;
  final double? coverage;

  /// `insufficient_audio`, `reference_unreliable`... khi phiên không chấm được.
  final String? qualityStatus;
  final List<String> qualityWarnings;
  final KaraokeScoreDiagnostics diagnostics;

  /// Thời lượng bản tham chiếu (độ dài bài hát) theo giây.
  double? get songSeconds => _valid(diagnostics.referenceDurationSeconds);

  /// Thời lượng đã thu của người hát theo giây.
  double? get recordingSeconds => _valid(diagnostics.recordingDurationSeconds);

  /// Phần trăm thời lượng bài hát được phủ bởi bản thu, tính cả offset bắt
  /// đầu thu — bản dịch của `scoreDurationSummary` phía web.
  double? get capturedSongPercent {
    final song = songSeconds;
    final recording = recordingSeconds;
    if (song == null || song <= 0 || recording == null) return null;
    final start = (diagnostics.recordingStartOffsetMs ?? 0) / 1000;
    final covered =
        (song < start + recording ? song : start + recording) -
        (start > 0 ? start : 0.0);
    if (covered <= 0) return 0;
    return (100 * covered / song).clamp(0, 100).toDouble();
  }

  static double? _valid(double? value) =>
      value != null && value.isFinite && value >= 0 ? value : null;
}

class KaraokeScoreDiagnostics {
  const KaraokeScoreDiagnostics({
    this.referenceDurationSeconds,
    this.recordingDurationSeconds,
    this.recordingStartOffsetMs,
    this.referenceVoicedSeconds,
    this.pairedVoicedSeconds,
  });

  static const empty = KaraokeScoreDiagnostics();

  factory KaraokeScoreDiagnostics.fromMap(Map<String, dynamic> map) {
    double? read(String key) {
      final value = map[key];
      return value is num && value.isFinite ? value.toDouble() : null;
    }

    return KaraokeScoreDiagnostics(
      referenceDurationSeconds: read('reference_duration_seconds'),
      recordingDurationSeconds: read('recording_duration_seconds'),
      recordingStartOffsetMs: read('recording_start_offset_ms'),
      referenceVoicedSeconds: read('reference_voiced_seconds'),
      pairedVoicedSeconds: read('paired_voiced_seconds'),
    );
  }

  final double? referenceDurationSeconds;
  final double? recordingDurationSeconds;
  final double? recordingStartOffsetMs;
  final double? referenceVoicedSeconds;
  final double? pairedVoicedSeconds;
}
