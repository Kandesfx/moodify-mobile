import 'dart:async';

import 'package:record/record.dart';

/// Opens the microphone and immediately discards input; it never writes audio.
class MicrophoneCapture {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<List<int>>? _input;
  bool _started = false;

  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Cần cấp quyền micro để bật micro.');
    }
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 22050,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );
    _input = stream.listen((_) {}, onError: (Object _) {});
    _started = true;
  }

  Future<void> stop() async {
    await _input?.cancel();
    _input = null;
    if (_started) {
      _started = false;
      await _recorder.stop();
    }
  }

  Future<void> dispose() => _recorder.dispose();
}
