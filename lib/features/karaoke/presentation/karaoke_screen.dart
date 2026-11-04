import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/domain/session_state.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../player/presentation/player_controller.dart'
    show playerControllerProvider;
import '../data/karaoke_realtime_scorer.dart';
import '../data/karaoke_repository.dart';
import '../data/microphone_capture.dart';
import '../data/pitch_capture.dart';
import '../data/karaoke_voice_client.dart';

final karaokePlaybackActiveProvider = StateProvider<bool>((ref) => false);
final karaokeAudioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});

class KaraokeScreen extends StatelessWidget {
  const KaraokeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Karaoke')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Bạn muốn hát thế nào?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Chọn bài yêu thích hoặc hát cùng bạn bè.',
          style: TextStyle(color: AppColors.secondary),
        ),
        const SizedBox(height: 24),
        _ModeCard(
          icon: Icons.mic_rounded,
          title: 'Hát một mình',
          subtitle: 'Chọn bài, nghe nhạc nền và hát theo lời.',
          onTap: () => context.push('/karaoke/solo'),
        ),
        const SizedBox(height: 12),
        _ModeCard(
          icon: Icons.groups_rounded,
          title: 'Hát cùng nhau',
          subtitle: 'Tạo phòng hoặc tham gia phòng đang mở.',
          onTap: () => context.push('/karaoke/rooms'),
        ),
      ],
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.secondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class KaraokeSoloScreen extends ConsumerStatefulWidget {
  const KaraokeSoloScreen({super.key});
  @override
  ConsumerState<KaraokeSoloScreen> createState() => _KaraokeSoloScreenState();
}

class _KaraokeSoloScreenState extends ConsumerState<KaraokeSoloScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  Future<List<Map<String, dynamic>>>? _tracks;

  @override
  void initState() {
    super.initState();
    _tracks = ref.read(karaokeRepositoryProvider).tracks();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _query(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(
          () => _tracks = ref
              .read(karaokeRepositoryProvider)
              .tracks(query: value),
        );
      }
    });
  }

  Future<void> _openTrack(String songId, List<String> nextSongIds) async {
    context.push(
      '/karaoke/solo/${Uri.encodeComponent(songId)}',
      extra: nextSongIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Hát một mình')),
      body: session.phase == SessionPhase.signedOut
          ? _SignInPrompt(
              onTap: () => context.push('/sign-in?from=/karaoke/solo'),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    controller: _search,
                    onChanged: _query,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Tìm bài karaoke',
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _tracks,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _RetryPanel(
                          message: karaokeError(snapshot.error!),
                          onRetry: () => setState(
                            () => _tracks = ref
                                .read(karaokeRepositoryProvider)
                                .tracks(query: _search.text),
                          ),
                        );
                      }
                      final rows = snapshot.data ?? const [];
                      if (rows.isEmpty) {
                        return const Center(
                          child: Text(
                            'Chưa có bài karaoke phù hợp.',
                            style: TextStyle(color: AppColors.secondary),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final row = rows[i];
                          final id = row['songId']?.toString() ?? '';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 4,
                            ),
                            leading: MusicArtwork(
                              image: row['imageUrl']?.toString(),
                              size: 52,
                            ),
                            title: Text(row['title']?.toString() ?? 'Bài hát'),
                            subtitle: Text(
                              row['artist']?.toString() ?? 'Chưa rõ nghệ sĩ',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _openTrack(
                              id,
                              rows
                                  .skip(i + 1)
                                  .map(
                                    (track) =>
                                        track['songId']?.toString() ?? '',
                                  )
                                  .where((songId) => songId.isNotEmpty)
                                  .toList(growable: false),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class KaraokePerformanceScreen extends ConsumerStatefulWidget {
  const KaraokePerformanceScreen({
    super.key,
    required this.songId,
    this.nextSongIds = const [],
  });
  final String songId;
  final List<String> nextSongIds;

  @override
  ConsumerState<KaraokePerformanceScreen> createState() =>
      _KaraokePerformanceScreenState();
}

class _KaraokePerformanceScreenState
    extends ConsumerState<KaraokePerformanceScreen> {
  late final AudioPlayer _audio;
  late Future<Map<String, dynamic>> _track;
  StreamSubscription<PlayerState>? _playerStateEvents;
  bool _loadingAudio = false;
  bool _requestingMicrophonePermission = false;
  bool _togglingMicrophone = false;
  bool _navigatingNext = false;
  bool _leavingForNext = false;
  bool _microphonePermissionGranted = false;
  bool _scoreSubmitting = false;
  PitchCapture? _pitchCapture;
  Map<String, dynamic>? _scoreSession;
  KaraokeRealtimeScorer? _realtimeScorer;
  double? _liveScore;
  DateTime _lastLiveScoreUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  int _captureStartOffsetMs = 0;
  MicrophoneCapture? _microphoneCapture;
  String _currentTrackTitle = 'Bài hát';
  double? _scrubPositionMs;
  bool _trackFlowStarted = false;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(karaokeAudioPlayerProvider);
    _track = ref.read(karaokeRepositoryProvider).track(widget.songId);
    _playerStateEvents = _audio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        ref.read(karaokePlaybackActiveProvider.notifier).state = false;
        if (_pitchCapture != null) unawaited(_finishScoring());
      } else {
        _pitchCapture?.setPaused(!state.playing);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_playerStateEvents?.cancel());
    if (!_leavingForNext) {
      unawaited(_audio.stop());
      ref.read(karaokePlaybackActiveProvider.notifier).state = false;
    }
    final capture = _pitchCapture;
    if (capture != null) {
      unawaited(() async {
        await capture.cancel();
        await capture.dispose();
      }());
    }
    final microphoneCheck = _microphoneCapture;
    if (microphoneCheck != null) {
      unawaited(_releaseMicrophone(microphoneCheck));
    }
    super.dispose();
  }

  Future<bool> _requestMicrophonePermission() async {
    if (_microphonePermissionGranted) return true;
    if (_requestingMicrophonePermission) return false;
    setState(() => _requestingMicrophonePermission = true);
    try {
      final granted = await PitchCapture.requestMicrophonePermission();
      if (!mounted) return false;
      setState(() => _microphonePermissionGranted = granted);
      if (!granted) {
        _message('Chưa cấp quyền micro để chấm điểm.');
      }
      return granted;
    } catch (error) {
      if (mounted) _message(karaokeError(error));
      return false;
    } finally {
      if (mounted) setState(() => _requestingMicrophonePermission = false);
    }
  }

  Future<void> _startSelectedTrack(Map<String, dynamic> track) async {
    if (_loadingAudio) return;
    final songId = track['songId']?.toString() ?? '';
    final url = Uri.tryParse(track['instrumentalUrl']?.toString() ?? '');
    if (songId.isEmpty ||
        url == null ||
        url.scheme != 'https' ||
        url.host != 'moodify.click') {
      _message('Đường dẫn nhạc nền không hợp lệ.');
      return;
    }

    setState(() {
      _loadingAudio = true;
      _currentTrackTitle = track['title']?.toString() ?? 'Bài hát';
    });
    try {
      await ref.read(playerControllerProvider.notifier).pause();
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await _audio.setUrl(url.toString()).timeout(const Duration(seconds: 25));
      await _audio.seek(Duration.zero);
      if (track['scoringAvailable'] == true) {
        await _beginScoring(track);
      } else {
        _message('Bài này chưa có dữ liệu tham chiếu đủ tin cậy để chấm điểm.');
        unawaited(_playAndReportError());
        ref.read(karaokePlaybackActiveProvider.notifier).state = true;
      }
    } catch (error) {
      unawaited(_audio.stop().catchError((Object _) {}));
      if (mounted) {
        _message(
          error is TimeoutException
              ? 'Tải nhạc nền quá lâu. Kiểm tra kết nối rồi thử lại.'
              : karaokeError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  Future<void> _beginScoring(Map<String, dynamic> track) async {
    if (_pitchCapture != null || _scoreSubmitting) return;
    final microphoneCheck = _microphoneCapture;
    if (microphoneCheck != null) {
      _microphoneCapture = null;
      await _releaseMicrophone(microphoneCheck);
    }
    setState(() {
      _togglingMicrophone = true;
    });
    PitchCapture? capture;
    try {
      final granted = await _requestMicrophonePermission();
      if (!granted) {
        throw StateError('Cần cấp quyền micro để bắt đầu chấm điểm.');
      }
      final repository = ref.read(karaokeRepositoryProvider);
      final session = await repository.startSession(track['songId'].toString());
      final referenceFuture = repository.pitchReference(
        session['sessionId'].toString(),
      );
      final playbackStarted = Completer<void>();
      unawaited(_playAndReportError(started: playbackStarted));
      await playbackStarted.future;
      capture = PitchCapture();
      final activeCapture = capture;
      activeCapture.onFrame = (index, pitch, confidence) =>
          _handlePitchFrame(activeCapture, index, pitch, confidence);
      await capture.start();
      if (!mounted) {
        await capture.cancel();
        await capture.dispose();
        return;
      }
      setState(() {
        _pitchCapture = capture;
        _scoreSession = session;
        // Match the web flow: start playback first, then anchor capture to the
        // player's actual position once the microphone stream is live.
        _captureStartOffsetMs = _audio.position.inMilliseconds;
        _realtimeScorer = null;
        _liveScore = null;
      });
      ref.read(karaokePlaybackActiveProvider.notifier).state = true;
      unawaited(
        _loadRealtimeScorer(
          referenceFuture,
          activeCapture,
          _captureStartOffsetMs,
        ),
      );
    } catch (error) {
      await capture?.cancel();
      await capture?.dispose();
      await _audio.pause();
      ref.read(karaokePlaybackActiveProvider.notifier).state = false;
      if (mounted) {
        setState(() {
          _pitchCapture = null;
          _scoreSession = null;
          _realtimeScorer = null;
          _liveScore = null;
        });
        _message(karaokeError(error));
      }
    } finally {
      if (mounted) setState(() => _togglingMicrophone = false);
    }
  }

  Future<void> _loadRealtimeScorer(
    Future<Map<String, dynamic>> referenceFuture,
    PitchCapture capture,
    int recordingStartOffsetMs,
  ) async {
    try {
      final reference = await referenceFuture;
      if (!mounted || !identical(_pitchCapture, capture)) return;
      final scorer = KaraokeRealtimeScorer.fromMap(
        reference,
        recordingStartOffsetMs: recordingStartOffsetMs,
      );
      for (var i = 0; i < capture.completedFrameCount; i++) {
        scorer.addFrame(i, capture.pitchAt(i), capture.confidenceAt(i));
      }
      _realtimeScorer = scorer;
      _lastLiveScoreUpdate = DateTime.now();
      setState(
        () => _liveScore = scorer.hasProgress ? scorer.score.overall : null,
      );
    } catch (_) {
      if (mounted && identical(_pitchCapture, capture)) {
        _message(
          'Không tải được tham chiếu chấm realtime. Điểm cuối bài vẫn được tính.',
        );
      }
    }
  }

  void _handlePitchFrame(
    PitchCapture capture,
    int frameIndex,
    double? pitch,
    double confidence,
  ) {
    if (!mounted || !identical(_pitchCapture, capture)) return;
    final scorer = _realtimeScorer;
    if (scorer == null) return;
    scorer.addFrame(frameIndex, pitch, confidence);
    final now = DateTime.now();
    if (now.difference(_lastLiveScoreUpdate).inMilliseconds < 300) return;
    _lastLiveScoreUpdate = now;
    setState(
      () => _liveScore = scorer.hasProgress ? scorer.score.overall : null,
    );
  }

  Future<void> _playAndReportError({Completer<void>? started}) async {
    try {
      final playback = _audio.play();
      if (started != null) {
        if (_audio.playing) {
          started.complete();
        } else {
          await _audio.playerStateStream
              .firstWhere((state) => state.playing)
              .timeout(const Duration(seconds: 10));
          if (!started.isCompleted) started.complete();
        }
      }
      await playback;
    } catch (error) {
      if (started != null && !started.isCompleted) {
        started.completeError(error);
        return;
      }
      final capture = _pitchCapture;
      _pitchCapture = null;
      _scoreSession = null;
      if (capture != null) {
        await capture.cancel();
        await capture.dispose();
      }
      if (mounted) {
        ref.read(karaokePlaybackActiveProvider.notifier).state = false;
        setState(() => _realtimeScorer = null);
        _message(karaokeError(error));
      }
    }
  }

  Future<void> _finishScoring() async {
    final capture = _pitchCapture;
    final session = _scoreSession;
    if (capture == null || session == null || _scoreSubmitting) return;
    setState(() {
      _scoreSubmitting = true;
      _pitchCapture = null;
      _scoreSession = null;
      _realtimeScorer = null;
    });

    double? overall;
    try {
      final features = await capture.finish(
        startOffsetMs: _captureStartOffsetMs,
      );
      features['allow_octave_shift'] = true;
      final f0 = features['f0_hz'] as List? ?? const [];
      final voiced = features['voiced_probability'] as List? ?? const [];
      if (f0.isEmpty || f0.length != voiced.length) {
        throw StateError('Dữ liệu giọng hát chưa đầy đủ để tính điểm.');
      }
      var reliableVoiceFrames = 0;
      for (var i = 0; i < f0.length; i++) {
        final pitch = f0[i];
        final confidence = voiced[i];
        if (pitch is num &&
            pitch.isFinite &&
            confidence is num &&
            confidence >= .5) {
          reliableVoiceFrames++;
        }
      }
      if (reliableVoiceFrames * PitchCapture.hopSize / PitchCapture.sampleRate <
          2) {
        if (mounted) {
          _message(
            'Chưa thu được giọng hát rõ để chấm điểm. Hãy bật micro, đeo tai nghe và hát gần micro rồi thử lại.',
          );
        }
        return;
      }
      final result = await ref
          .read(karaokeRepositoryProvider)
          .submitPitchFeatures(session['sessionId'].toString(), features);
      final score = result['score'] as Map<String, dynamic>?;
      overall = (score?['overall'] as num?)?.toDouble();
      if (overall == null && mounted) {
        _message('Bản thu chưa đủ dữ liệu để tính điểm.');
      }
    } catch (error) {
      if (mounted) _message(karaokeError(error));
    } finally {
      await capture.dispose();
      if (mounted) setState(() => _scoreSubmitting = false);
    }
    final scoreValue = overall;
    if (mounted && scoreValue != null) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.graphic_eq_rounded),
          title: const Text('Kết quả Karaoke'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_currentTrackTitle),
              const SizedBox(height: 12),
              Text(
                '${scoreValue.toStringAsFixed(1)} / 100',
                style: Theme.of(dialogContext).textTheme.headlineMedium
                    ?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _toggleMicrophone() async {
    if (_loadingAudio ||
        _requestingMicrophonePermission ||
        _togglingMicrophone ||
        _pitchCapture != null ||
        _scoreSubmitting) {
      return;
    }
    final activeMicrophone = _microphoneCapture;
    if (activeMicrophone != null) {
      setState(() => _microphoneCapture = null);
      await _releaseMicrophone(activeMicrophone);
      return;
    }

    final granted = await _requestMicrophonePermission();
    if (!mounted || !granted) return;
    setState(() => _togglingMicrophone = true);
    final microphone = MicrophoneCapture();
    try {
      await microphone.start();
      if (!mounted) {
        await _releaseMicrophone(microphone);
        return;
      }
      setState(() => _microphoneCapture = microphone);
    } catch (error) {
      await _releaseMicrophone(microphone);
      if (mounted) _message(karaokeError(error));
    } finally {
      if (mounted) setState(() => _togglingMicrophone = false);
    }
  }

  Future<void> _togglePlayback() async {
    if (_loadingAudio || _requestingMicrophonePermission || _scoreSubmitting) {
      return;
    }
    if (_pitchCapture != null) {
      if (_audio.playing) {
        _pitchCapture?.setPaused(true);
        await _audio.pause();
        ref.read(karaokePlaybackActiveProvider.notifier).state = false;
      } else {
        _pitchCapture?.setPaused(false);
        unawaited(_playAndReportError());
        ref.read(karaokePlaybackActiveProvider.notifier).state = true;
      }
      return;
    }
    if (_audio.playing) {
      await _audio.pause();
      return;
    }
    if (_audio.processingState == ProcessingState.completed) {
      await _audio.seek(Duration.zero);
    }
    unawaited(_playAndReportError());
    ref.read(karaokePlaybackActiveProvider.notifier).state = true;
  }

  Future<void> _playNext() async {
    if (widget.nextSongIds.isEmpty ||
        _loadingAudio ||
        _scoreSubmitting ||
        _navigatingNext) {
      return;
    }
    setState(() => _navigatingNext = true);
    try {
      final capture = _pitchCapture;
      _pitchCapture = null;
      _scoreSession = null;
      if (capture != null) {
        await capture.cancel();
        await capture.dispose();
      }
      final microphone = _microphoneCapture;
      _microphoneCapture = null;
      if (microphone != null) await _releaseMicrophone(microphone);
      await _audio.stop();
      ref.read(karaokePlaybackActiveProvider.notifier).state = false;
      if (!mounted) return;
      _leavingForNext = true;
      final nextSongId = widget.nextSongIds.first;
      context.pushReplacement(
        '/karaoke/solo/${Uri.encodeComponent(nextSongId)}',
        extra: widget.nextSongIds.skip(1).toList(growable: false),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _navigatingNext = false;
          _leavingForNext = false;
        });
        _message(karaokeError(error));
      }
    }
  }

  Future<void> _seekTo(double milliseconds) async {
    await _audio.seek(Duration(milliseconds: milliseconds.round()));
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Karaoke')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _track,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _RetryPanel(
              message: karaokeError(snapshot.error!),
              onRetry: () => setState(() {
                _trackFlowStarted = false;
                _track = ref
                    .read(karaokeRepositoryProvider)
                    .track(widget.songId);
              }),
            );
          }
          final track = snapshot.data!;
          if (!_trackFlowStarted) {
            _trackFlowStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) unawaited(_startSelectedTrack(track));
            });
          }
          return _buildPerformance(context, track);
        },
      ),
    );
  }

  Widget _buildPerformance(BuildContext context, Map<String, dynamic> track) {
    final controlsBusy =
        _loadingAudio ||
        _requestingMicrophonePermission ||
        _togglingMicrophone ||
        _navigatingNext ||
        _scoreSubmitting;
    final seekBusy = controlsBusy || _pitchCapture != null;
    final duration =
        _audio.duration ??
        Duration(milliseconds: (track['durationMs'] as num?)?.toInt() ?? 0);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            child: Row(
              children: [
                MusicArtwork(image: track['imageUrl']?.toString(), size: 58),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track['title']?.toString() ?? 'Bài hát',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        track['artist']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 26,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Text(
                          'LỜI BÀI HÁT',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 11,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_scoreSession != null && _liveScore != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.graphic_eq_rounded,
                                      size: 13,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 5),
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      transitionBuilder: (child, animation) =>
                                          FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          ),
                                      child: Text(
                                        _liveScore!.toStringAsFixed(0),
                                        key: ValueKey(_liveScore!.round()),
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _KaraokeSoloLyrics(
                      timeline: track['lyricTimeline'],
                      syncedLyrics: track['lyricsSynced']?.toString(),
                      plainLyrics: track['lyricsPlain']?.toString(),
                      position: _audio.positionStream,
                    ),
                  ),
                ],
              ),
            ),
          ),
          StreamBuilder<PlayerState>(
            stream: _audio.playerStateStream,
            initialData: _audio.playerState,
            builder: (context, playerSnapshot) {
              final playing = playerSnapshot.data?.playing ?? false;
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: Column(
                  children: [
                    StreamBuilder<Duration>(
                      stream: _audio.positionStream,
                      initialData: _audio.position,
                      builder: (context, positionSnapshot) {
                        final position = positionSnapshot.data ?? Duration.zero;
                        final maxMs = duration.inMilliseconds.toDouble();
                        final value =
                            (_scrubPositionMs ??
                                    position.inMilliseconds.toDouble())
                                .clamp(0, maxMs > 0 ? maxMs : 1)
                                .toDouble();
                        return Column(
                          children: [
                            Slider(
                              value: value,
                              max: maxMs > 0 ? maxMs : 1,
                              onChanged: maxMs > 0 && !seekBusy
                                  ? (value) =>
                                        setState(() => _scrubPositionMs = value)
                                  : null,
                              onChangeEnd: maxMs > 0 && !seekBusy
                                  ? (value) {
                                      unawaited(_seekTo(value));
                                      setState(() => _scrubPositionMs = null);
                                    }
                                  : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_karaokeTime(position)),
                                  Text(_karaokeTime(duration)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _KaraokeSecondaryControl(
                          icon: _microphoneCapture != null
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          isActive: _microphoneCapture != null,
                          isBusy: _togglingMicrophone,
                          tooltip: _microphoneCapture != null
                              ? 'Dừng kiểm tra micro'
                              : 'Kiểm tra micro',
                          onPressed: controlsBusy || _pitchCapture != null
                              ? null
                              : () => unawaited(_toggleMicrophone()),
                        ),
                        const SizedBox(width: 28),
                        IconButton.filled(
                          onPressed: controlsBusy
                              ? null
                              : () => unawaited(_togglePlayback()),
                          tooltip: playing
                              ? 'Tạm dừng nhạc nền'
                              : 'Phát nhạc nền',
                          icon:
                              _loadingAudio ||
                                  _requestingMicrophonePermission ||
                                  _scoreSubmitting
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                          iconSize: 34,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(68, 68),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 28),
                        _KaraokeSecondaryControl(
                          icon: Icons.skip_next_rounded,
                          tooltip: 'Bài tiếp theo',
                          onPressed: widget.nextSongIds.isEmpty || controlsBusy
                              ? null
                              : () => unawaited(_playNext()),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _releaseMicrophone(MicrophoneCapture microphone) async {
  try {
    await microphone.stop();
  } catch (_) {
    // Always dispose the native recorder, including after a stream error.
  } finally {
    await microphone.dispose();
  }
}

String _karaokeTime(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 86400);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class KaraokeRoomsScreen extends ConsumerStatefulWidget {
  const KaraokeRoomsScreen({super.key});
  @override
  ConsumerState<KaraokeRoomsScreen> createState() => _KaraokeRoomsScreenState();
}

class _KaraokeRoomsScreenState extends ConsumerState<KaraokeRoomsScreen> {
  Future<List<Map<String, dynamic>>>? _rooms;
  Map<String, dynamic>? _joined;
  late final AudioPlayer _roomAudio;
  String? _roomRunId;
  DateTime? _roomSnapshotAt;
  Timer? _roomPoll;
  Timer? _roomScorePoll;
  bool _polling = false;
  KaraokeVoiceClient? _voice;
  StreamSubscription<void>? _voiceEvents;
  PitchCapture? _roomCapture;
  Map<String, dynamic>? _roomScoreSession;
  String? _roomScoreRunId;
  int _roomScoreStartOffsetMs = 0;
  int _roomScoreDurationMs = 0;
  final List<Map<String, dynamic>> _roomScoreSegments = [];
  bool _roomScoreFinishing = false;
  @override
  void initState() {
    super.initState();
    _roomAudio = ref.read(karaokeAudioPlayerProvider);
    _rooms = ref.read(karaokeRepositoryProvider).rooms();
    _roomPoll = Timer.periodic(const Duration(seconds: 4), (_) => _syncRoom());
    _roomScorePoll = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollRoomScore(),
    );
  }

  @override
  void dispose() {
    _roomPoll?.cancel();
    _roomScorePoll?.cancel();
    unawaited(_voiceEvents?.cancel());
    unawaited(_voice?.dispose());
    final capture = _roomCapture;
    if (capture != null) {
      unawaited(() async {
        await capture.cancel();
        await capture.dispose();
      }());
    }
    unawaited(_roomAudio.stop());
    ref.read(karaokePlaybackActiveProvider.notifier).state = false;
    super.dispose();
  }

  Future<void> _connectVoice() async {
    final room = _joined;
    if (room == null) return;
    await _voiceEvents?.cancel();
    await _voice?.dispose();
    final voice = KaraokeVoiceClient(ref.read(karaokeRepositoryProvider));
    _voice = voice;
    _voiceEvents = voice.onChanged.stream.listen((_) {
      if (mounted) setState(() {});
    });
    setState(() {});
    try {
      await voice.connect((room['id'] as num).toInt());
    } catch (_) {
      if (mounted) _message(voice.error ?? 'Không thể kết nối voice.');
    }
  }

  Future<void> _toggleVoice() async {
    final voice = _voice;
    if (voice == null || !voice.connected) return;
    try {
      await voice.toggleMicrophone();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _message(karaokeError(error));
    }
  }

  Future<void> _startRoomScoring() async {
    final room = _joined;
    final playback = room?['playback'] as Map<String, dynamic>? ?? const {};
    final track = playback['track'] as Map<String, dynamic>?;
    if (room == null || track == null || playback['status'] != 'PLAYING') {
      _message('Phát bài trong phòng trước khi bắt đầu chấm điểm nhóm.');
      return;
    }
    if (_voice?.microphoneOn == true) {
      _message('Tắt micro Voice trước khi bắt đầu chấm điểm nhóm.');
      return;
    }
    if (_roomCapture != null || _roomScoreFinishing) return;
    final roomId = (room['id'] as num).toInt();
    final runId = playback['playbackRunId']?.toString();
    final songId = track['trackId']?.toString();
    if (runId == null || songId == null || songId.isEmpty) {
      _message('Không tìm thấy bài hát đang phát trong phòng.');
      return;
    }
    if (_roomScoreRunId == runId && _roomScoreSession?['ended'] == true) {
      _message('Phiên chấm điểm bài này đã kết thúc.');
      return;
    }

    PitchCapture? capture;
    try {
      final detail = await ref.read(karaokeRepositoryProvider).track(songId);
      if (detail['scoringAvailable'] != true) {
        throw StateError('Bài này chưa có dữ liệu tham chiếu để chấm điểm.');
      }
      final session = await ref
          .read(karaokeRepositoryProvider)
          .startRoomScoreSession(roomId);
      if (session['status'] != 'collecting' || session['ended'] == true) {
        throw StateError('Phiên chấm điểm của bài này đã kết thúc.');
      }
      capture = PitchCapture();
      await capture.start();
      final latest = _joined?['playback'] as Map<String, dynamic>? ?? const {};
      if (!mounted || latest['playbackRunId']?.toString() != runId) {
        await capture.cancel();
        await capture.dispose();
        return;
      }
      final registered = await ref
          .read(karaokeRepositoryProvider)
          .registerRoomScoreParticipant(
            roomId,
            session['sessionId'].toString(),
          );
      if (!mounted) {
        await capture.cancel();
        await capture.dispose();
        return;
      }
      final continuingRun =
          _roomScoreSession?['sessionId'] == registered['sessionId'];
      setState(() {
        _roomCapture = capture;
        _roomScoreSession = registered;
        _roomScoreRunId = runId;
        _roomScoreStartOffsetMs = _roomAudio.position.inMilliseconds;
        _roomScoreDurationMs =
            (track['durationMs'] as num?)?.toInt() ??
            (detail['durationMs'] as num?)?.toInt() ??
            0;
        if (!continuingRun) _roomScoreSegments.clear();
      });
    } catch (error) {
      await capture?.cancel();
      await capture?.dispose();
      if (mounted) _message(karaokeError(error));
    }
  }

  Future<void> _submitRoomScoreSegment() async {
    final capture = _roomCapture;
    final session = _roomScoreSession;
    if (capture == null || session == null) return;
    _roomCapture = null;
    try {
      final features = await capture.finish(startOffsetMs: 0);
      final remainingMs = _roomScoreDurationMs - _roomScoreStartOffsetMs;
      if (remainingMs <= 50) {
        throw StateError('Bài hát đã kết thúc trước khi ghi được phần hát.');
      }
      final availableSeconds = remainingMs / 1000;
      final durationSeconds = (features['duration_seconds'] as num)
          .toDouble()
          .clamp(0, availableSeconds);
      final maxFrames =
          (durationSeconds * PitchCapture.sampleRate / PitchCapture.hopSize)
              .ceil();
      final f0 = (features['f0_hz'] as List).take(maxFrames).toList();
      final probability = (features['voiced_probability'] as List)
          .take(maxFrames)
          .toList();
      if (durationSeconds <= 0.05 || f0.isEmpty || probability.isEmpty) {
        throw StateError('Bản thu quá ngắn để chấm điểm.');
      }
      final segment = <String, dynamic>{
        'offset_ms': _roomScoreStartOffsetMs,
        'features': {
          'duration_seconds': durationSeconds,
          'f0_hz': f0,
          'voiced_probability': probability,
          'rms_dbfs': features['rms_dbfs'],
          'clipped_fraction': features['clipped_fraction'],
          'recording_start_offset_ms': 0,
          'capture_latency_ms': 0,
          'allow_octave_shift': true,
        },
      };
      _roomScoreSegments.add(segment);
      final roomId = (_joined?['id'] as num?)?.toInt();
      if (roomId == null) return;
      final updated = await ref
          .read(karaokeRepositoryProvider)
          .submitRoomScoreContribution(
            roomId: roomId,
            sessionId: session['sessionId'].toString(),
            segments: List.unmodifiable(_roomScoreSegments),
          );
      if (mounted) setState(() => _roomScoreSession = updated);
    } finally {
      await capture.dispose();
    }
  }

  Future<void> _finishRoomScoring() async {
    final roomId = (_joined?['id'] as num?)?.toInt();
    final session = _roomScoreSession;
    if (roomId == null || session == null || _roomScoreFinishing) return;
    setState(() => _roomScoreFinishing = true);
    Object? segmentError;
    try {
      try {
        await _submitRoomScoreSegment();
      } catch (error) {
        segmentError = error;
      }
      final finished = await ref
          .read(karaokeRepositoryProvider)
          .finishRoomScoreSession(roomId, session['sessionId'].toString());
      if (mounted) setState(() => _roomScoreSession = finished);
      if (segmentError != null && mounted) {
        _message(karaokeError(segmentError));
      }
    } catch (error) {
      if (mounted) _message(karaokeError(error));
    } finally {
      if (mounted) setState(() => _roomScoreFinishing = false);
    }
  }

  Future<void> _pollRoomScore() async {
    final session = _roomScoreSession;
    final roomId = (_joined?['id'] as num?)?.toInt();
    final sessionId = session?['sessionId']?.toString();
    if (roomId == null ||
        sessionId == null ||
        ['completed', 'failed'].contains(session?['status'])) {
      return;
    }
    try {
      final latest = await ref
          .read(karaokeRepositoryProvider)
          .roomScoreSession(roomId, sessionId);
      if (mounted && _roomScoreSession?['sessionId'] == sessionId) {
        setState(() => _roomScoreSession = latest);
      }
    } catch (_) {
      // The score service can finish asynchronously; the next poll retries.
    }
  }

  Future<void> _finishRoomScoreBeforePop() async {
    while (_roomScoreFinishing && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final session = _roomScoreSession;
    if (mounted &&
        session?['status'] == 'collecting' &&
        session?['ended'] != true) {
      await _finishRoomScoring();
    }
    if (mounted) context.pop();
  }

  Future<void> _leaveRoom(int id) async {
    try {
      if (_roomScoreSession?['status'] == 'collecting') {
        await _finishRoomScoring();
      }
      await _voiceEvents?.cancel();
      _voiceEvents = null;
      await _voice?.dispose();
      _voice = null;
      await _roomAudio.stop();
      ref.read(karaokePlaybackActiveProvider.notifier).state = false;
      await ref.read(karaokeRepositoryProvider).leaveRoom(id);
      if (mounted) setState(() => _joined = null);
      _refresh();
    } catch (error) {
      if (mounted) _message(karaokeError(error));
    }
  }

  Future<void> _syncRoom() async {
    final room = _joined;
    if (room == null || _polling || !mounted) return;
    _polling = true;
    try {
      final next = await ref
          .read(karaokeRepositoryProvider)
          .room((room['id'] as num).toInt());
      if (mounted) {
        setState(() => _joined = next);
        unawaited(_syncRoomAudio(next));
      }
    } catch (_) {
      // Keep the last server snapshot visible; manual refresh exposes errors.
    } finally {
      _polling = false;
    }
  }

  Future<void> _syncRoomAudio(Map<String, dynamic> room) async {
    final playback = room['playback'] as Map<String, dynamic>? ?? const {};
    final track = playback['track'] as Map<String, dynamic>?;
    final runId = playback['playbackRunId']?.toString();
    final status = playback['status']?.toString() ?? 'IDLE';
    if (_roomScoreRunId != null && _roomScoreRunId != runId) {
      if (_roomScoreSession?['status'] == 'collecting') {
        await _finishRoomScoring();
      }
      _roomScoreRunId = null;
    } else if (status != 'PLAYING' && _roomCapture != null) {
      try {
        await _submitRoomScoreSegment();
      } catch (error) {
        if (mounted) _message(karaokeError(error));
      }
    }
    if (track == null || runId == null || status == 'IDLE') {
      if (_roomAudio.playing) await _roomAudio.stop();
      _roomRunId = null;
      ref.read(karaokePlaybackActiveProvider.notifier).state = false;
      return;
    }
    final url = Uri.tryParse(track['instrumentalUrl']?.toString() ?? '');
    if (url == null || url.scheme != 'https' || url.host != 'moodify.click') {
      _message('Đường dẫn nhạc nền trong phòng không hợp lệ.');
      return;
    }
    final now = DateTime.now();
    final serverPosition = (playback['positionMs'] as num?)?.toInt() ?? 0;
    final sameRun = _roomRunId == runId && _roomSnapshotAt != null;
    final elapsed = sameRun && status == 'PLAYING'
        ? now.difference(_roomSnapshotAt!).inMilliseconds
        : 0;
    final target = Duration(
      milliseconds: (serverPosition + elapsed).clamp(0, 24 * 60 * 60 * 1000),
    );
    try {
      if (!sameRun) {
        await ref.read(playerControllerProvider.notifier).pause();
        await _roomAudio.setUrl(url.toString());
        await _roomAudio.seek(target);
        _roomRunId = runId;
      } else if ((_roomAudio.position - target).inMilliseconds.abs() > 1800) {
        await _roomAudio.seek(target);
      }
      if (status == 'PLAYING' && !_roomAudio.playing) {
        unawaited(_roomAudio.play());
      }
      if (status == 'PAUSED' && _roomAudio.playing) await _roomAudio.pause();
      _roomSnapshotAt = now;
      ref.read(karaokePlaybackActiveProvider.notifier).state =
          status == 'PLAYING';
    } catch (error) {
      if (mounted) _message(karaokeError(error));
    }
  }

  void _refresh() =>
      setState(() => _rooms = ref.read(karaokeRepositoryProvider).rooms());
  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _create() async {
    final name = TextEditingController();
    var private = false;
    final input = await showDialog<(String, bool)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Tạo phòng hát'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Tên phòng'),
              ),
              SwitchListTile(
                value: private,
                onChanged: (v) => setState(() => private = v),
                title: const Text('Phòng riêng'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, (name.text.trim(), private)),
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (input == null || input.$1.isEmpty) return;
    try {
      final created = await ref
          .read(karaokeRepositoryProvider)
          .createRoom(name: input.$1, isPrivate: input.$2);
      if (!mounted) return;
      final id = (created['id'] as num).toInt();
      setState(() => _joined = null);
      final detail = await ref.read(karaokeRepositoryProvider).joinRoom(id);
      if (mounted) {
        setState(() => _joined = detail);
        unawaited(_syncRoomAudio(detail));
      }
      _refresh();
    } catch (error) {
      if (mounted) _message(karaokeError(error));
    }
  }

  Future<void> _join(Map<String, dynamic> room) async {
    final id = (room['id'] as num).toInt();
    String? code;
    if (room['visibility'] == 'PRIVATE') {
      final field = TextEditingController();
      code = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nhập mã mời'),
          content: TextField(
            controller: field,
            decoration: const InputDecoration(labelText: 'Mã phòng'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, field.text),
              child: const Text('Tham gia'),
            ),
          ],
        ),
      );
      field.dispose();
      if (code == null) return;
    }
    try {
      final result = await ref
          .read(karaokeRepositoryProvider)
          .joinRoom(id, inviteCode: code);
      if (mounted) {
        setState(() => _joined = result);
        unawaited(_syncRoomAudio(result));
      }
    } catch (error) {
      if (mounted) _message(karaokeError(error));
    }
  }

  Future<void> _roomCommand(String command) async {
    final current = _joined;
    if (current == null) return;
    try {
      final id = (current['id'] as num).toInt();
      final playback = current['playback'] as Map<String, dynamic>? ?? const {};
      await ref
          .read(karaokeRepositoryProvider)
          .playback(id, command, (playback['version'] as num?)?.toInt() ?? 0);
      final updated = await ref.read(karaokeRepositoryProvider).room(id);
      if (mounted) {
        setState(() => _joined = updated);
        unawaited(_syncRoomAudio(updated));
      }
    } catch (error) {
      if (mounted) _message(karaokeError(error));
    }
  }

  Future<void> _addTrack() async {
    try {
      final tracks = await ref.read(karaokeRepositoryProvider).tracks();
      if (!mounted) return;
      final track = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: AppColors.surface,
        builder: (context) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Thêm bài vào hàng đợi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ...tracks.map(
                (item) => ListTile(
                  title: Text(item['title']?.toString() ?? 'Bài hát'),
                  subtitle: Text(item['artist']?.toString() ?? ''),
                  onTap: () => Navigator.pop(context, item),
                ),
              ),
            ],
          ),
        ),
      );
      final current = _joined;
      if (track == null || current == null) return;
      final id = (current['id'] as num).toInt();
      await ref
          .read(karaokeRepositoryProvider)
          .addQueue(id, track['songId'].toString());
      final updated = await ref.read(karaokeRepositoryProvider).room(id);
      if (mounted) setState(() => _joined = updated);
    } catch (error) {
      if (mounted) _message(karaokeError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionControllerProvider).phase == SessionPhase.signedOut) {
      return Scaffold(
        appBar: AppBar(title: const Text('Phòng hát')),
        body: _SignInPrompt(
          onTap: () => context.push('/sign-in?from=/karaoke/rooms'),
        ),
      );
    }
    final joined = _joined;
    final scoreSession = _roomScoreSession;
    final hasOpenScore =
        scoreSession?['status'] == 'collecting' &&
        scoreSession?['ended'] != true;
    return PopScope<void>(
      canPop: !hasOpenScore && _roomCapture == null && !_roomScoreFinishing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_finishRoomScoreBeforePop());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            joined == null
                ? 'Phòng hát'
                : joined['name']?.toString() ?? 'Phòng hát',
          ),
          actions: [
            if (joined == null)
              IconButton(
                tooltip: 'Tạo phòng',
                onPressed: _create,
                icon: const Icon(Icons.add_rounded),
              )
            else
              IconButton(
                tooltip: 'Rời phòng',
                onPressed: () => _leaveRoom((joined['id'] as num).toInt()),
                icon: const Icon(Icons.logout_rounded),
              ),
          ],
        ),
        body: joined != null
            ? _RoomDetailView(
                room: joined,
                audio: _roomAudio,
                onAddTrack: _addTrack,
                onCommand: _roomCommand,
                voice: _voice,
                onConnectVoice: _connectVoice,
                onToggleVoice: _toggleVoice,
                groupScoring: _roomCapture != null,
                groupScoreSession:
                    _roomScoreRunId ==
                        (joined['playback']
                            as Map<String, dynamic>?)?['playbackRunId']
                    ? _roomScoreSession
                    : null,
                groupScoringBusy: _roomScoreFinishing,
                onStartGroupScoring: _startRoomScoring,
                onFinishGroupScoring: _finishRoomScoring,
                onRemoveQueue: (itemId) async {
                  try {
                    final id = (joined['id'] as num).toInt();
                    await ref
                        .read(karaokeRepositoryProvider)
                        .removeQueue(id, itemId);
                    final updated = await ref
                        .read(karaokeRepositoryProvider)
                        .room(id);
                    if (mounted) {
                      setState(() => _joined = updated);
                      unawaited(_syncRoomAudio(updated));
                    }
                  } catch (error) {
                    if (mounted) _message(karaokeError(error));
                  }
                },
                onCloseRoom: () async {
                  try {
                    if (_roomScoreSession?['status'] == 'collecting') {
                      await _finishRoomScoring();
                    }
                    await _voiceEvents?.cancel();
                    _voiceEvents = null;
                    await _voice?.dispose();
                    _voice = null;
                    await _roomAudio.stop();
                    ref.read(karaokePlaybackActiveProvider.notifier).state =
                        false;
                    await ref
                        .read(karaokeRepositoryProvider)
                        .closeRoom((joined['id'] as num).toInt());
                    if (mounted) setState(() => _joined = null);
                    _refresh();
                  } catch (error) {
                    if (mounted) _message(karaokeError(error));
                  }
                },
                onRefresh: () async {
                  final next = await ref
                      .read(karaokeRepositoryProvider)
                      .room((joined['id'] as num).toInt());
                  if (mounted) {
                    setState(() => _joined = next);
                    unawaited(_syncRoomAudio(next));
                  }
                },
              )
            : FutureBuilder<List<Map<String, dynamic>>>(
                future: _rooms,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _RetryPanel(
                      message: karaokeError(snapshot.error!),
                      onRetry: _refresh,
                    );
                  }
                  final rooms = snapshot.data ?? const [];
                  return RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (rooms.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(30),
                            child: Center(
                              child: Text(
                                'Chưa có phòng đang mở. Hãy tạo phòng mới.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.secondary),
                              ),
                            ),
                          )
                        else
                          ...rooms.map(
                            (room) => Card(
                              color: AppColors.surface,
                              child: ListTile(
                                title: Text(
                                  room['name']?.toString() ?? 'Phòng hát',
                                ),
                                subtitle: Text(
                                  '${room['hostName'] ?? 'Người tổ chức'} · ${room['memberCount']}/${room['maxMembers']} người',
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () => _join(room),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Tạo phòng'),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _RoomDetailView extends StatelessWidget {
  const _RoomDetailView({
    required this.room,
    required this.audio,
    required this.onRefresh,
    required this.onAddTrack,
    required this.onCommand,
    required this.onRemoveQueue,
    required this.onCloseRoom,
    required this.voice,
    required this.onConnectVoice,
    required this.onToggleVoice,
    required this.groupScoring,
    required this.groupScoreSession,
    required this.groupScoringBusy,
    required this.onStartGroupScoring,
    required this.onFinishGroupScoring,
  });
  final Map<String, dynamic> room;
  final AudioPlayer audio;
  final VoidCallback onRefresh;
  final VoidCallback onAddTrack;
  final ValueChanged<String> onCommand;
  final ValueChanged<int> onRemoveQueue;
  final VoidCallback onCloseRoom;
  final KaraokeVoiceClient? voice;
  final VoidCallback onConnectVoice;
  final VoidCallback onToggleVoice;
  final bool groupScoring, groupScoringBusy;
  final Map<String, dynamic>? groupScoreSession;
  final VoidCallback onStartGroupScoring, onFinishGroupScoring;
  @override
  Widget build(BuildContext context) {
    final members = room['members'] as List? ?? const [];
    final queue = room['queue'] as List? ?? const [];
    final playback = room['playback'] as Map<String, dynamic>? ?? const {};
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Thành viên · ${room['memberCount']}/${room['maxMembers']}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...members.map((raw) {
            final member = raw as Map<String, dynamic>;
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(member['name']?.toString() ?? 'Người nghe'),
              subtitle: member['host'] == true ? const Text('Chủ phòng') : null,
            );
          }),
          const Divider(height: 32),
          Row(
            children: [
              const Icon(Icons.graphic_eq_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  voice?.connected == true
                      ? 'Voice đã kết nối · ${voice!.remoteUserIds.length} thành viên'
                      : voice?.error ?? 'Voice chưa kết nối',
                ),
              ),
              if (voice?.connected == true)
                IconButton.filledTonal(
                  onPressed: onToggleVoice,
                  tooltip: voice?.microphoneOn == true
                      ? 'Tắt micro'
                      : 'Bật micro',
                  icon: Icon(
                    voice?.microphoneOn == true
                        ? Icons.mic_rounded
                        : Icons.mic_off_rounded,
                  ),
                )
              else
                TextButton(
                  onPressed: onConnectVoice,
                  child: const Text('Kết nối'),
                ),
            ],
          ),
          const Divider(height: 32),
          Text('Đang phát', style: Theme.of(context).textTheme.titleMedium),
          Text(
            (playback['track'] as Map<String, dynamic>?)?['title']
                    ?.toString() ??
                'Chưa có bài hát',
          ),
          if (playback['track'] is Map<String, dynamic>) ...[
            const SizedBox(height: 12),
            _SyncedRoomLyrics(
              timeline:
                  (playback['track'] as Map<String, dynamic>)['lyricTimeline'],
              plainLyrics:
                  (playback['track'] as Map<String, dynamic>)['lyricsPlain']
                      ?.toString(),
              position: audio.positionStream,
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: groupScoringBusy
                  ? null
                  : groupScoring
                  ? onFinishGroupScoring
                  : groupScoreSession?['ended'] == true ||
                        [
                          'scoring',
                          'completed',
                          'failed',
                        ].contains(groupScoreSession?['status'])
                  ? null
                  : onStartGroupScoring,
              icon: Icon(
                groupScoring
                    ? Icons.stop_circle_outlined
                    : Icons.graphic_eq_rounded,
              ),
              label: Text(
                groupScoring
                    ? 'Hoàn tất phần hát'
                    : groupScoringBusy
                    ? 'Đang chốt điểm…'
                    : groupScoreSession?['ended'] == true
                    ? 'Đã gửi phần hát'
                    : 'Bắt đầu chấm điểm nhóm',
              ),
            ),
            if (groupScoreSession != null) ...[
              const SizedBox(height: 8),
              _GroupScoreStatus(session: groupScoreSession!),
            ],
          ],
          if (room['canManage'] == true) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onAddTrack,
                  icon: const Icon(Icons.queue_music_rounded),
                  label: const Text('Thêm bài'),
                ),
                if (playback['status'] == 'PLAYING')
                  IconButton.filledTonal(
                    onPressed: () => onCommand('pause'),
                    icon: const Icon(Icons.pause_rounded),
                    tooltip: 'Tạm dừng',
                  )
                else
                  IconButton.filledTonal(
                    onPressed: () => onCommand(
                      playback['status'] == 'PAUSED' ? 'resume' : 'start',
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    tooltip: 'Phát',
                  ),
                IconButton.filledTonal(
                  onPressed: () => onCommand('skip'),
                  icon: const Icon(Icons.skip_next_rounded),
                  tooltip: 'Bỏ qua',
                ),
                TextButton.icon(
                  onPressed: onCloseRoom,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Đóng phòng'),
                ),
              ],
            ),
            if (room['visibility'] == 'PRIVATE' && room['inviteCode'] != null)
              SelectableText(
                'Mã mời: ${room['inviteCode']}',
                style: const TextStyle(color: AppColors.secondary),
              ),
          ],
          const SizedBox(height: 20),
          Text(
            'Hàng đợi · ${queue.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (queue.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Hàng đợi đang trống.',
                style: TextStyle(color: AppColors.secondary),
              ),
            ),
          ...queue.map((raw) {
            final item = raw as Map<String, dynamic>;
            return ListTile(
              title: Text(item['title']?.toString() ?? 'Bài hát'),
              subtitle: Text(item['artist']?.toString() ?? ''),
              leading: const Icon(Icons.queue_music_rounded),
              trailing: item['requestedByMe'] == true
                  ? IconButton(
                      tooltip: 'Xóa khỏi hàng đợi',
                      onPressed: () =>
                          onRemoveQueue((item['id'] as num).toInt()),
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
            );
          }),
          const SizedBox(height: 20),
          const Text(
            'Chấm điểm nhóm dùng micro riêng; hãy tắt micro Voice trước khi ghi phần hát.',
            style: TextStyle(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _GroupScoreStatus extends StatelessWidget {
  const _GroupScoreStatus({required this.session});
  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final score = session['score'] as Map<String, dynamic>?;
    final nested = score?['score'] as Map<String, dynamic>?;
    final overall = (nested?['overall'] as num?)?.toDouble();
    final status = session['status']?.toString();
    final text = overall != null
        ? 'Điểm nhóm: ${overall.toStringAsFixed(1)}'
        : status == 'failed'
        ? 'Máy chủ chưa chấm được phiên hát này.'
        : status == 'completed'
        ? 'Chưa thu được giọng hát đủ rõ để chấm.'
        : 'Đã gửi phần hát · đang chờ kết quả nhóm';
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: overall == null ? AppColors.secondary : AppColors.primary,
      ),
    );
  }
}

class _KaraokeLyricLine {
  const _KaraokeLyricLine({required this.text, this.startMs, this.endMs});

  final String text;
  final int? startMs, endMs;
}

class _KaraokeSoloLyrics extends StatefulWidget {
  const _KaraokeSoloLyrics({
    required this.timeline,
    required this.syncedLyrics,
    required this.plainLyrics,
    required this.position,
  });

  final Object? timeline;
  final String? syncedLyrics, plainLyrics;
  final Stream<Duration> position;

  @override
  State<_KaraokeSoloLyrics> createState() => _KaraokeSoloLyricsState();
}

class _KaraokeSoloLyricsState extends State<_KaraokeSoloLyrics> {
  final ScrollController _scrollController = ScrollController();
  late List<_KaraokeLyricLine> _lines;
  late List<GlobalKey> _lineKeys;
  int _lastScrolledLine = -1;

  @override
  void initState() {
    super.initState();
    _readLyrics();
  }

  @override
  void didUpdateWidget(covariant _KaraokeSoloLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeline != widget.timeline ||
        oldWidget.syncedLyrics != widget.syncedLyrics ||
        oldWidget.plainLyrics != widget.plainLyrics) {
      _readLyrics();
      _lastScrolledLine = -1;
    }
  }

  void _readLyrics() {
    _lines = _parseKaraokeLyrics(
      timeline: widget.timeline,
      syncedLyrics: widget.syncedLyrics,
      plainLyrics: widget.plainLyrics,
    );
    _lineKeys = List.generate(_lines.length, (_) => GlobalKey());
  }

  int _activeLineIndex(int positionMs) {
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final startMs = line.startMs;
      if (startMs == null || positionMs < startMs) continue;
      if (line.endMs != null) {
        if (positionMs <= line.endMs!) return i;
      } else {
        final nextStartMs = i + 1 < _lines.length
            ? _lines[i + 1].startMs
            : null;
        if (nextStartMs == null || positionMs < nextStartMs) return i;
      }
    }
    return -1;
  }

  void _scrollToActiveLine(int index) {
    if (index < 0 || index == _lastScrolledLine) return;
    _lastScrolledLine = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lineContext = _lineKeys[index].currentContext;
      if (lineContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          lineContext,
          alignment: .48,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
        ),
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) {
      return const Center(
        child: Text(
          'Bài hát chưa có lời được cung cấp.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondary),
        ),
      );
    }
    final hasTiming = _lines.any((line) => line.startMs != null);
    return Column(
      children: [
        if (!hasTiming)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Bài này chưa có mốc thời gian cho lời hát.',
              style: TextStyle(color: AppColors.secondary, fontSize: 12),
            ),
          ),
        Expanded(
          child: StreamBuilder<Duration>(
            stream: widget.position,
            initialData: Duration.zero,
            builder: (context, snapshot) {
              final activeIndex = hasTiming
                  ? _activeLineIndex(
                      (snapshot.data ?? Duration.zero).inMilliseconds,
                    )
                  : -1;
              _scrollToActiveLine(activeIndex);
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      SizedBox(height: constraints.maxHeight * .4),
                      ...List.generate(_lines.length, (index) {
                        final active = index == activeIndex;
                        return Padding(
                          key: _lineKeys[index],
                          padding: EdgeInsets.symmetric(
                            vertical: active ? 12 : 8,
                          ),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOut,
                            style: TextStyle(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.secondary.withValues(alpha: .72),
                              fontSize: active ? 23 : 17,
                              height: 1.55,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                            child: Text(_lines[index].text),
                          ),
                        );
                      }),
                      SizedBox(height: constraints.maxHeight * .4),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

List<_KaraokeLyricLine> _parseKaraokeLyrics({
  required Object? timeline,
  required String? syncedLyrics,
  required String? plainLyrics,
}) {
  if (timeline is Map && timeline['lines'] is List) {
    final rawLines = timeline['lines'] as List;
    final words = timeline['words'] is List
        ? timeline['words'] as List
        : const [];
    final lines = <_KaraokeLyricLine>[];
    for (final rawLine in rawLines) {
      if (rawLine is! Map) continue;
      final startWord = (rawLine['firstWordIndex'] as num?)?.toInt() ?? 0;
      final wordCount = (rawLine['wordCount'] as num?)?.toInt() ?? 0;
      final text =
          rawLine['text']?.toString() ??
          words
              .skip(startWord)
              .take(wordCount)
              .map((word) => word is Map ? word['text']?.toString() ?? '' : '')
              .join();
      final startMs = (rawLine['startMs'] as num?)?.toInt();
      if (text.trim().isEmpty || startMs == null) continue;
      lines.add(
        _KaraokeLyricLine(
          text: text.trim(),
          startMs: startMs,
          endMs: (rawLine['endMs'] as num?)?.toInt(),
        ),
      );
    }
    if (lines.isNotEmpty) return lines;
  }

  final rawSyncedLyrics = syncedLyrics?.trim() ?? '';
  if (rawSyncedLyrics.isNotEmpty) {
    final timestampPattern = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
    final offsetMatch = RegExp(
      r'^\s*\[offset:([+-]?\d+)\]\s*$',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(rawSyncedLyrics);
    final offsetMs = int.tryParse(offsetMatch?.group(1) ?? '') ?? 0;
    final timedLines = <_KaraokeLyricLine>[];
    for (final rawLine in rawSyncedLyrics.split(RegExp(r'\r?\n'))) {
      final timestamps = timestampPattern.allMatches(rawLine).toList();
      final text = rawLine.replaceAll(timestampPattern, '').trim();
      if (timestamps.isEmpty || text.isEmpty) continue;
      for (final match in timestamps) {
        final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        if (seconds > 59) continue;
        final fraction = (match.group(3) ?? '').padRight(3, '0');
        final milliseconds = int.tryParse(fraction.substring(0, 3)) ?? 0;
        timedLines.add(
          _KaraokeLyricLine(
            text: text,
            startMs: (minutes * 60 + seconds) * 1000 + milliseconds + offsetMs,
          ),
        );
      }
    }
    timedLines.sort((a, b) => a.startMs!.compareTo(b.startMs!));
    if (timedLines.isNotEmpty) {
      final deduplicated = <_KaraokeLyricLine>[];
      for (final line in timedLines) {
        if (deduplicated.isNotEmpty &&
            deduplicated.last.startMs == line.startMs) {
          final previous = deduplicated.removeLast();
          deduplicated.add(
            _KaraokeLyricLine(
              text: '${previous.text} · ${line.text}',
              startMs: line.startMs,
            ),
          );
        } else {
          deduplicated.add(line);
        }
      }
      return deduplicated;
    }
  }

  return (plainLyrics ?? '')
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) => _KaraokeLyricLine(text: line))
      .toList(growable: false);
}

class _KaraokeSecondaryControl extends StatelessWidget {
  const _KaraokeSecondaryControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.isBusy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive, isBusy;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: isActive ? AppColors.primary.withValues(alpha: .15) : null,
      shape: BoxShape.circle,
    ),
    child: IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: isBusy
          ? const SizedBox.square(
              dimension: 19,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      color: isActive ? AppColors.primary : AppColors.secondary,
      iconSize: 24,
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
  );
}

class _SyncedRoomLyrics extends StatelessWidget {
  const _SyncedRoomLyrics({
    required this.timeline,
    required this.plainLyrics,
    required this.position,
  });
  final Object? timeline;
  final String? plainLyrics;
  final Stream<Duration> position;
  @override
  Widget build(BuildContext context) {
    if (timeline is! Map || (timeline as Map)['lines'] is! List) {
      final allLines =
          plainLyrics
              ?.trim()
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .toList() ??
          const <String>[];
      final lines = allLines.take(3).toList();
      if (lines.isEmpty) {
        return const Text(
          'Bài hát chưa có lời được cung cấp.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondary),
        );
      }
      return Text(
        lines.join('\n'),
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.secondary, fontSize: 14, height: 1.5),
      );
    }
    final data = timeline as Map;
    final lines = data['lines'] as List;
    final words = data['words'] as List? ?? const [];
    if (lines.isEmpty || words.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<Duration>(
      stream: position,
      builder: (context, snapshot) {
        final ms = snapshot.data?.inMilliseconds ?? 0;
        var active = lines.indexWhere((raw) {
          final line = raw as Map;
          return ms >= ((line['startMs'] as num?)?.toInt() ?? 0) &&
              ms <= ((line['endMs'] as num?)?.toInt() ?? -1);
        });
        if (active < 0) {
          active = lines.indexWhere((raw) {
            final start = (raw as Map)['startMs'];
            return start is num && start.toInt() > ms;
          });
        }
        if (active < 0) active = lines.length - 1;
        String lineText(int index) {
          if (index < 0 || index >= lines.length) return '';
          final line = lines[index] as Map;
          final start = (line['firstWordIndex'] as num?)?.toInt() ?? 0;
          final count = (line['wordCount'] as num?)?.toInt() ?? 0;
          return words
              .skip(start)
              .take(count)
              .map((word) => (word as Map)['text']?.toString() ?? '')
              .join();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active > 0)
              Text(
                lineText(active - 1),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondary.withValues(alpha: .55),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                lineText(active),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (active + 1 < lines.length)
              Text(
                lineText(active + 1),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondary.withValues(alpha: .55),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 42,
            color: AppColors.secondary,
          ),
          const SizedBox(height: 16),
          const Text('Đăng nhập để dùng Karaoke và lưu phiên hát.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onTap, child: const Text('Đăng nhập')),
        ],
      ),
    ),
  );
}

class _RetryPanel extends StatelessWidget {
  const _RetryPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}
