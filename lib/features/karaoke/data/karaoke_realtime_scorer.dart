import 'dart:math' as math;

import 'pitch_capture.dart';

class KaraokeRealtimeScore {
  const KaraokeRealtimeScore({
    required this.overall,
    required this.pitch,
    required this.rhythm,
    required this.coverage,
  });

  final double overall;
  final double pitch;
  final double rhythm;
  final double coverage;
}

/// Incremental copy of the server's pitch/rhythm/coverage score.
///
/// It runs locally while singing; the server remains authoritative at the end.
class KaraokeRealtimeScorer {
  KaraokeRealtimeScorer._(
    this._referencePitch,
    this._referenceConfidence,
    this._referenceActivePrefix,
    this._recordingOffsetFrames,
    this._referenceEvents,
  );

  factory KaraokeRealtimeScorer.fromMap(
    Map<String, dynamic> data, {
    required int recordingStartOffsetMs,
  }) {
    if (data['sampleRate'] != PitchCapture.sampleRate ||
        data['hopLength'] != PitchCapture.hopSize) {
      throw const FormatException('Pitch reference format is unsupported.');
    }
    final rawPitch = data['f0Hz'];
    final rawConfidence = data['voicedProbability'];
    if (rawPitch is! List ||
        rawConfidence is! List ||
        rawPitch.isEmpty ||
        rawPitch.length != rawConfidence.length) {
      throw const FormatException('Pitch reference is incomplete.');
    }

    final pitch = rawPitch
        .map<double?>((value) => value is num ? value.toDouble() : null)
        .toList(growable: false);
    final confidence = rawConfidence
        .map<double>((value) => value is num ? value.toDouble() : 0)
        .toList(growable: false);
    final activePrefix = _activePrefix(pitch, confidence);
    final activeCount = activePrefix.last;
    if (activeCount == 0) {
      throw const FormatException('Pitch reference has no voiced frames.');
    }

    return KaraokeRealtimeScorer._(
      pitch,
      confidence,
      activePrefix,
      recordingStartOffsetMs *
          PitchCapture.sampleRate /
          (1000 * PitchCapture.hopSize),
      _events(pitch, confidence),
    );
  }

  final List<double?> _referencePitch;
  final List<double> _referenceConfidence;
  final List<int> _referenceActivePrefix;
  final double _recordingOffsetFrames;
  final List<double> _referenceEvents;
  final List<double> _pitchDifferences = [];
  final List<double> _recordingEvents = [];
  int _pairedFrames = 0;
  int _furthestReferenceFrame = -1;
  int _lastEventFrame = -3;
  bool _previousActive = false;
  double? _previousPitch;

  static List<int> _activePrefix(List<double?> pitch, List<double> confidence) {
    final prefix = List<int>.filled(pitch.length + 1, 0);
    for (var i = 0; i < pitch.length; i++) {
      prefix[i + 1] =
          prefix[i] + (pitch[i] != null && confidence[i] >= .5 ? 1 : 0);
    }
    return prefix;
  }

  void addFrame(int frameIndex, double? pitch, double confidence) {
    final referenceIndex = (frameIndex + _recordingOffsetFrames).round();
    if (referenceIndex >= 0 && referenceIndex < _referencePitch.length) {
      _furthestReferenceFrame = math
          .max(_furthestReferenceFrame, referenceIndex)
          .toInt();
    }
    final active = pitch != null && pitch.isFinite && confidence >= .5;
    final changed = active != _previousActive;
    final noteChanged =
        active &&
        _previousActive &&
        _previousPitch != null &&
        (1200 * math.log(pitch / _previousPitch!) / math.ln2).abs() > 150;
    if ((changed || noteChanged) && frameIndex - _lastEventFrame >= 3) {
      _lastEventFrame = frameIndex;
      _recordingEvents.add(
        frameIndex * PitchCapture.hopSize / PitchCapture.sampleRate +
            _recordingOffsetFrames *
                PitchCapture.hopSize /
                PitchCapture.sampleRate,
      );
    }
    _previousActive = active;
    _previousPitch = active ? pitch : null;

    if (!active) return;
    if (referenceIndex < 0 || referenceIndex >= _referencePitch.length) return;
    final expectedPitch = _referencePitch[referenceIndex];
    if (expectedPitch == null ||
        _referenceConfidence[referenceIndex] < .5 ||
        expectedPitch <= 0) {
      return;
    }
    _pairedFrames++;
    _pitchDifferences.add(1200 * math.log(pitch / expectedPitch) / math.ln2);
  }

  KaraokeRealtimeScore get score {
    final progressedFrames = (_furthestReferenceFrame + 1)
        .clamp(0, _referenceActivePrefix.length - 1)
        .toInt();
    final denominator = math
        .max(1, _referenceActivePrefix[progressedFrames])
        .toInt();
    final coverage = 100 * _pairedFrames / denominator;
    final pitch = _pitchScore(denominator);
    final referenceTime = _furthestReferenceFrame < 0
        ? 0.0
        : _furthestReferenceFrame *
              PitchCapture.hopSize /
              PitchCapture.sampleRate;
    final referenceEventCount = _upperBound(_referenceEvents, referenceTime);
    final rhythm = _rhythmScore(
      _referenceEvents.take(referenceEventCount).toList(growable: false),
      _recordingEvents,
    );
    return KaraokeRealtimeScore(
      overall: .3 * pitch + .2 * rhythm + .5 * coverage,
      pitch: pitch,
      rhythm: rhythm,
      coverage: coverage,
    );
  }

  bool get hasProgress {
    if (_furthestReferenceFrame < 0) return false;
    final progressedFrames = (_furthestReferenceFrame + 1)
        .clamp(0, _referenceActivePrefix.length - 1)
        .toInt();
    return _referenceActivePrefix[progressedFrames] > 0;
  }

  static int _upperBound(List<double> values, double target) {
    var low = 0;
    var high = values.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (values[middle] <= target) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  double _pitchScore(int denominator) {
    if (_pitchDifferences.isEmpty) return 0;
    const choices = [-1200.0, 0.0, 1200.0];
    var octave = choices.first;
    var minimumMedianError = double.infinity;
    for (final choice in choices) {
      final errors =
          _pitchDifferences
              .map((difference) => (difference - choice).abs())
              .toList()
            ..sort();
      final middle = errors.length ~/ 2;
      final median = errors.length.isOdd
          ? errors[middle]
          : (errors[middle - 1] + errors[middle]) / 2;
      if (median < minimumMedianError) {
        minimumMedianError = median;
        octave = choice;
      }
    }
    var total = 0.0;
    for (final difference in _pitchDifferences) {
      final cents = (difference - octave) / 100;
      total += math.exp(-(cents * cents));
    }
    return 100 * total / denominator;
  }

  static List<double> _events(List<double?> pitch, List<double> confidence) {
    final indices = <int>[];
    var previousActive = false;
    double? previousPitch;
    for (var i = 0; i < pitch.length; i++) {
      final currentPitch = pitch[i];
      final active =
          currentPitch != null && currentPitch.isFinite && confidence[i] >= .5;
      if (active != previousActive) indices.add(i);
      if (active &&
          previousActive &&
          previousPitch != null &&
          (1200 * math.log(currentPitch / previousPitch) / math.ln2).abs() >
              150) {
        indices.add(i);
      }
      previousActive = active;
      previousPitch = active ? currentPitch : null;
    }
    if (previousActive) indices.add(pitch.length);
    indices.sort();

    final selected = <int>[];
    for (final index in indices) {
      if (selected.isEmpty || index - selected.last >= 3) selected.add(index);
    }
    return selected
        .map((index) => index * PitchCapture.hopSize / PitchCapture.sampleRate)
        .toList(growable: false);
  }

  static double _rhythmScore(List<double> reference, List<double> recording) {
    if (reference.isEmpty || recording.isEmpty) return 0;
    final candidates = <(double, int, int)>[];
    var left = 0;
    var right = 0;
    for (var i = 0; i < reference.length; i++) {
      final time = reference[i];
      while (left < recording.length && recording[left] < time - .15) {
        left++;
      }
      if (right < left) right = left;
      while (right < recording.length && recording[right] <= time + .15) {
        right++;
      }
      for (var j = left; j < right; j++) {
        candidates.add(((time - recording[j]).abs(), i, j));
      }
    }
    candidates.sort((a, b) {
      final distance = a.$1.compareTo(b.$1);
      if (distance != 0) return distance;
      final referenceIndex = a.$2.compareTo(b.$2);
      return referenceIndex != 0 ? referenceIndex : a.$3.compareTo(b.$3);
    });
    final usedReference = <int>{};
    final usedRecording = <int>{};
    var matched = 0.0;
    for (final candidate in candidates) {
      if (!usedReference.contains(candidate.$2) &&
          !usedRecording.contains(candidate.$3)) {
        usedReference.add(candidate.$2);
        usedRecording.add(candidate.$3);
        matched += math.max(0.0, 1 - candidate.$1 / .15).toDouble();
      }
    }
    return 100 * 2 * matched / (reference.length + recording.length);
  }
}
