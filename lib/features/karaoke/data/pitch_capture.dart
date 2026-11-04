import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

/// Captures the same 22.05 kHz, 2048/512 YIN feature grid used by the web client.
class PitchCapture {
  static const sampleRate = 22050;
  static const frameSize = 2048;
  static const hopSize = 512;

  static Future<bool> requestMicrophonePermission() async {
    final recorder = AudioRecorder();
    try {
      return await recorder.hasPermission(request: true);
    } finally {
      await recorder.dispose();
    }
  }

  final AudioRecorder _recorder = AudioRecorder();
  final List<double> _ring = List.filled(frameSize, 0);
  final List<double?> _f0 = [];
  final List<double> _voiced = [];
  final ReceivePort _workerMessages = ReceivePort();
  StreamSubscription<List<int>>? _subscription;
  Isolate? _pitchWorker;
  SendPort? _workerCommands;
  final Completer<void> _workerDone = Completer<void>();
  int _ringIndex = frameSize ~/ 2, _contextSamples = frameSize ~/ 2;
  int _realSamples = 0, _frames = 0, _audioSamples = 0, _clipped = 0;
  double _sumSquares = 0;
  bool _paused = false;
  Object? failure;
  void Function(int frameIndex, double? pitch, double confidence)? onFrame;

  int get completedFrameCount => _f0.length;
  double? pitchAt(int index) => _f0[index];
  double confidenceAt(int index) => _voiced[index];

  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Cần cấp quyền micro để bắt đầu hát.');
    }
    final workerReady = Completer<SendPort>();
    _workerMessages.listen((message) {
      if (message is SendPort) {
        if (!workerReady.isCompleted) workerReady.complete(message);
        return;
      }
      if (message is! List || message.isEmpty) return;
      if (message.first == 'done') {
        if (!_workerDone.isCompleted) _workerDone.complete();
        return;
      }
      if (message.first != 'frame' || message.length != 4) return;
      final frameIndex = message[1] as int;
      final pitch = message[2] as double?;
      final confidence = (message[3] as num).toDouble();
      if (frameIndex != _f0.length) {
        failure = StateError('Pitch frames arrived out of order.');
        return;
      }
      _f0.add(pitch);
      _voiced.add(confidence);
      onFrame?.call(frameIndex, pitch, confidence);
    });
    _pitchWorker = await Isolate.spawn(
      _pitchWorkerEntry,
      _workerMessages.sendPort,
    );
    _workerCommands = await workerReady.future;
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );
    _subscription = stream.listen(
      _onBytes,
      onError: (Object error) => failure = error,
    );
  }

  void _onBytes(List<int> bytes) {
    if (_paused) return;
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      var sample = (bytes[i] & 0xff) | ((bytes[i + 1] & 0xff) << 8);
      if (sample >= 0x8000) sample -= 0x10000;
      final value = sample / 32768.0;
      _audioSamples++;
      _sumSquares += value * value;
      if (value.abs() >= .999) _clipped++;
      _append(value);
    }
  }

  void _append(double value) {
    _ring[_ringIndex] = value;
    _ringIndex = (_ringIndex + 1) % frameSize;
    _contextSamples++;
    _realSamples++;
    if (_contextSamples >= frameSize &&
        (_contextSamples - frameSize) % hopSize == 0) {
      _processFrame();
    }
  }

  void _processFrame() {
    final frame = Float32List(frameSize);
    for (var i = 0; i < frameSize; i++) {
      frame[i] = _ring[(_ringIndex + i) % frameSize];
    }
    _workerCommands?.send(<Object>['frame', _frames, frame]);
    _frames++;
  }

  void setPaused(bool paused) => _paused = paused;

  Future<Map<String, dynamic>> finish({required int startOffsetMs}) async {
    await _recorder.stop();
    await _subscription?.cancel();
    final expectedFrames = (_realSamples / hopSize).ceil();
    while (_frames < expectedFrames) {
      _ring[_ringIndex] = 0;
      _ringIndex = (_ringIndex + 1) % frameSize;
      _contextSamples++;
      if (_contextSamples >= frameSize &&
          (_contextSamples - frameSize) % hopSize == 0) {
        _processFrame();
      }
    }
    if (failure != null) throw StateError('Thu âm bị gián đoạn.');
    _workerCommands?.send('finish');
    await _workerDone.future.timeout(const Duration(seconds: 10));
    if (_f0.length != _frames || _voiced.length != _frames) {
      throw StateError('Pitch capture did not finish all frames.');
    }
    final meanSquare = _audioSamples > 0 ? _sumSquares / _audioSamples : 0.0;
    return {
      'duration_seconds': _realSamples / sampleRate,
      'f0_hz': _f0,
      'voiced_probability': _voiced,
      'rms_dbfs': meanSquare > 0 ? 10 * math.log(meanSquare) / math.ln10 : -240,
      'clipped_fraction': _audioSamples > 0 ? _clipped / _audioSamples : 0,
      'recording_start_offset_ms': startOffsetMs,
      'capture_latency_ms': 0,
      'allow_octave_shift': false,
    };
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    await _subscription?.cancel();
    _stopWorker();
  }

  Future<void> dispose() async {
    _stopWorker();
    await _recorder.dispose();
  }

  void _stopWorker() {
    _pitchWorker?.kill(priority: Isolate.immediate);
    _workerMessages.close();
  }
}

void _pitchWorkerEntry(SendPort mainPort) {
  final commands = ReceivePort();
  mainPort.send(commands.sendPort);
  commands.listen((message) {
    if (message == 'finish') {
      mainPort.send(const <Object>['done']);
      commands.close();
      return;
    }
    if (message is! List ||
        message.length != 3 ||
        message.first != 'frame' ||
        message[2] is! Float32List) {
      return;
    }
    final frameIndex = message[1] as int;
    final frame = message[2] as Float32List;
    final estimate = _estimatePitch(frame);
    mainPort.send(<Object?>[
      'frame',
      frameIndex,
      estimate?.$1,
      estimate?.$2 ?? 0.0,
    ]);
  });
}

(double, double)? _estimatePitch(Float32List frame) {
  var squares = 0.0;
  for (final sample in frame) {
    squares += sample * sample;
  }
  final rms = math.sqrt(squares / PitchCapture.frameSize);
  if (rms < math.pow(10, -55 / 20)) return null;

  const minLag = (PitchCapture.sampleRate + 1199) ~/ 1200;
  const maxLag = PitchCapture.sampleRate ~/ 65;
  final difference = List<double>.filled(maxLag + 1, 1);
  final compareLength = PitchCapture.frameSize - maxLag;
  var running = 0.0, bestValue = double.infinity, bestLag = -1;
  for (var lag = 1; lag <= maxLag; lag++) {
    var sum = 0.0;
    for (var i = 0; i < compareLength; i++) {
      final delta = frame[i] - frame[i + lag];
      sum += delta * delta;
    }
    running += sum;
    final normalized = running > 0 ? sum * lag / running : 1.0;
    difference[lag] = normalized;
    if (lag >= minLag && normalized < bestValue) {
      bestValue = normalized;
      bestLag = lag;
    }
  }
  if (bestLag < minLag || bestValue > .35) return null;
  var selected = bestLag;
  for (var lag = minLag; lag <= maxLag; lag++) {
    if (difference[lag] < .15) {
      selected = lag;
      while (selected < maxLag &&
          difference[selected + 1] < difference[selected]) {
        selected++;
      }
      bestValue = difference[selected];
      break;
    }
  }
  final left = difference[math.max(minLag, selected - 1)];
  final center = difference[selected];
  final right = difference[math.min(maxLag, selected + 1)];
  final denominator = left - 2 * center + right;
  final shift = denominator.abs() > 1e-12
      ? (.5 * (left - right) / denominator).clamp(-.5, .5)
      : 0.0;
  final pitch = PitchCapture.sampleRate / (selected + shift);
  if (!pitch.isFinite || pitch < 60 || pitch > 1300) return null;
  return (pitch, (1 - bestValue).clamp(0, 1));
}
