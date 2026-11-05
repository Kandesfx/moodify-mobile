import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/domain/session_state.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../player/presentation/player_controller.dart'
    show playerControllerProvider;
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF29213F), Color(0xFF15141F)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF403455)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                color: Color(0xFFC6B6FF),
                size: 30,
              ),
              const SizedBox(height: 22),
              Text(
                'Đến lượt bạn\ncất giọng',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(height: 1.25),
              ),
              const SizedBox(height: 10),
              const Text(
                'Chọn cách bạn muốn tận hưởng âm nhạc.',
                style: TextStyle(color: Color(0xFFC4BDCF), height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('Chọn chế độ', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _ModeCard(
          icon: Icons.mic_rounded,
          title: 'Hát một mình',
          subtitle: 'Chọn bài yêu thích và cất giọng',
          onTap: () => context.push('/karaoke/solo'),
        ),
        const SizedBox(height: 12),
        _ModeCard(
          icon: Icons.people_alt_rounded,
          title: 'Hát cùng nhau',
          subtitle: 'Tạo phòng hoặc tham gia cùng bạn bè',
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
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF16151D),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2D2937)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF302746),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFFC8B8FF)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFFBEB5CF),
              size: 20,
            ),
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
  bool _microphoneMuted = false;
  Duration? _muteStartPosition;
  Completer<void>? _microphoneTransition;
  PitchCapture? _pitchCapture;
  Map<String, dynamic>? _scoreSession;
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
        _pitchCapture?.setPaused(
          !state.playing || state.processingState != ProcessingState.ready,
        );
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
      final playbackStarted = Completer<void>();
      unawaited(_playAndReportError(started: playbackStarted));
      await playbackStarted.future;
      capture = PitchCapture();
      final activeCapture = capture;
      capture.onFailure = (_) {
        if (!mounted || !identical(_pitchCapture, activeCapture)) return;
        setState(() {
          _pitchCapture = null;
          _scoreSession = null;
        });
        unawaited(() async {
          await activeCapture.cancel();
          await activeCapture.dispose();
        }());
        _message('Thu âm bị gián đoạn. Bài hát này sẽ không được chấm điểm.');
      };
      await capture.start();
      if (capture.failure != null) throw StateError('Thu âm bị gián đoạn.');
      capture.setPaused(
        !_audio.playing || _audio.processingState != ProcessingState.ready,
      );
      if (!mounted) {
        await capture.cancel();
        await capture.dispose();
        return;
      }
      setState(() {
        _pitchCapture = capture;
        _scoreSession = session;
        _microphoneMuted = false;
        _muteStartPosition = null;
        // Match the web flow: start playback first, then anchor capture to the
        // player's actual position once the microphone stream is live.
        _captureStartOffsetMs = _audio.position.inMilliseconds;
      });
      ref.read(karaokePlaybackActiveProvider.notifier).state = true;
    } catch (error) {
      await capture?.cancel();
      await capture?.dispose();
      await _audio.pause();
      ref.read(karaokePlaybackActiveProvider.notifier).state = false;
      if (mounted) {
        setState(() {
          _pitchCapture = null;
          _scoreSession = null;
        });
        _message(karaokeError(error));
      }
    } finally {
      if (mounted) setState(() => _togglingMicrophone = false);
    }
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
        setState(() {});
        _message(karaokeError(error));
      }
    }
  }

  Future<void> _finishScoring() async {
    await _microphoneTransition?.future;
    if (!mounted) return;
    final capture = _pitchCapture;
    final session = _scoreSession;
    if (capture == null || session == null || _scoreSubmitting) return;
    if (_microphoneMuted && _muteStartPosition != null) {
      capture.addSilence(_mutedDuration());
    }
    setState(() {
      _scoreSubmitting = true;
      _pitchCapture = null;
      _scoreSession = null;
      _microphoneMuted = false;
      _muteStartPosition = null;
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
        builder: (dialogContext) =>
            _KaraokeScoreDialog(title: _currentTrackTitle, score: scoreValue),
      );
    }
  }

  Future<void> _toggleMicrophone() async {
    if (_loadingAudio ||
        _requestingMicrophonePermission ||
        _togglingMicrophone ||
        _scoreSubmitting) {
      return;
    }
    final capture = _pitchCapture;
    if (capture != null) {
      final transition = Completer<void>();
      _microphoneTransition = transition;
      setState(() => _togglingMicrophone = true);
      try {
        if (!_microphoneMuted) {
          _muteStartPosition = _audio.position;
          await capture.mute();
          if (mounted && identical(_pitchCapture, capture)) {
            setState(() => _microphoneMuted = true);
          }
        } else {
          await capture.unmute(_mutedDuration);
          if (mounted && identical(_pitchCapture, capture)) {
            setState(() {
              _microphoneMuted = false;
              _muteStartPosition = null;
            });
          }
        }
      } catch (_) {
        if (mounted && identical(_pitchCapture, capture)) {
          setState(() {
            _pitchCapture = null;
            _scoreSession = null;
            _microphoneMuted = false;
            _muteStartPosition = null;
          });
          _message(
            'Không thể thay đổi micro. Bài này sẽ không được chấm điểm.',
          );
          await capture.cancel();
          await capture.dispose();
        }
      } finally {
        if (mounted) setState(() => _togglingMicrophone = false);
        _microphoneTransition = null;
        transition.complete();
      }
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
    microphone.onFailure = (_) {
      if (!mounted || !identical(_microphoneCapture, microphone)) return;
      setState(() => _microphoneCapture = null);
      unawaited(_releaseMicrophone(microphone));
      _message('Micro bị gián đoạn. Vui lòng thử lại.');
    };
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

  Duration _mutedDuration() {
    final elapsed = _audio.position - (_muteStartPosition ?? _audio.position);
    return elapsed.isNegative ? Duration.zero : elapsed;
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
          Container(
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF211D2C), Color(0xFF17161F)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF373043)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: MusicArtwork(
                    image: track['imageUrl']?.toString(),
                    size: 56,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track['title']?.toString() ?? 'Bài hát',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
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
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF211C2C), Color(0xFF12121A)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: .16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      'LỜI BÀI HÁT',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
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
              final playerState = playerSnapshot.data;
              final playing =
                  (playerState?.playing ?? false) &&
                  playerState?.processingState != ProcessingState.completed;
              final scoring = _pitchCapture != null;
              final microphoneOpen =
                  (scoring && !_microphoneMuted) || _microphoneCapture != null;
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
                          icon: microphoneOpen
                              ? Icons.mic_rounded
                              : Icons.mic_off_rounded,
                          isActive: microphoneOpen,
                          isBusy: _togglingMicrophone,
                          tooltip: microphoneOpen ? 'Tắt micro' : 'Bật micro',
                          onPressed: controlsBusy
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
                              : AnimatedSwitcher(
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 180),
                                  child: Icon(
                                    playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    key: ValueKey(playing),
                                  ),
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
  late final StateController<bool> _karaokePlaybackActive;
  String? _roomRunId;
  DateTime? _roomSnapshotAt;
  Timer? _roomPoll;
  Timer? _roomScorePoll;
  bool _polling = false;
  KaraokeVoiceClient? _voice;
  StreamSubscription<void>? _voiceEvents;
  PitchCapture? _roomCapture;
  Map<String, dynamic>? _roomScoreSession;
  Future<Map<String, dynamic>>? _roomScoreSessionFuture;
  String? _roomScoreRunId;
  String? _roomScoreRegisteredSessionId;
  String _roomScoreSongTitle = 'Bài hát trong phòng';
  int _roomScoreStartOffsetMs = 0;
  int _roomScoreDurationMs = 0;
  final List<Map<String, dynamic>> _roomScoreSegments = [];
  bool _roomScoreFinishing = false;
  bool _roomScoreRunClosed = false;
  bool _roomCaptureStarting = false;
  bool _scorePermissionDenied = false;
  bool _voiceMicHintShown = false;
  bool _permissionHintShown = false;
  final Set<String> _scoreDialogShownFor = {};
  StreamSubscription<PlayerState>? _roomAudioStateEvents;
  @override
  void initState() {
    super.initState();
    _roomAudio = ref.read(karaokeAudioPlayerProvider);
    _karaokePlaybackActive = ref.read(karaokePlaybackActiveProvider.notifier);
    _rooms = ref.read(karaokeRepositoryProvider).rooms();
    _roomPoll = Timer.periodic(const Duration(seconds: 4), (_) => _syncRoom());
    _roomScorePoll = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollRoomScore(),
    );
    _roomAudioStateEvents = _roomAudio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(_finishRoomScoreRun());
      }
    });
  }

  @override
  void dispose() {
    _roomPoll?.cancel();
    _roomScorePoll?.cancel();
    unawaited(_roomAudioStateEvents?.cancel());
    // Rời màn giữa chừng: gần hết bài thì chốt điểm chung, ngược lại hủy (như web).
    unawaited(_teardownScoreRun(finishIfNearEnd: true));
    unawaited(_voiceEvents?.cancel());
    unawaited(_voice?.dispose());
    unawaited(_roomAudio.stop());
    if (_karaokePlaybackActive.mounted) {
      _karaokePlaybackActive.state = false;
    }
    super.dispose();
  }

  // ---- Chấm điểm chung tự động, mô phỏng luồng web (useKaraokeRoomScoring) ----

  void _openScoreRun(
    Map<String, dynamic> playback,
    Map<String, dynamic> track,
    String runId,
  ) {
    _roomScoreRunId = runId;
    _roomScoreRunClosed = false;
    _roomScoreSession = null;
    _roomScoreSessionFuture = null;
    _roomScoreRegisteredSessionId = null;
    _roomScoreSegments.clear();
    _roomScoreDurationMs = (track['durationMs'] as num?)?.toInt() ?? 0;
    _roomScoreSongTitle = track['title']?.toString() ?? 'Bài hát trong phòng';
    unawaited(_openScoreSession());
  }

  Future<void> _openScoreSession() async {
    final room = _joined;
    if (room == null || _roomScoreSessionFuture != null) return;
    final roomId = (room['id'] as num).toInt();
    final future = ref
        .read(karaokeRepositoryProvider)
        .startRoomScoreSession(roomId);
    _roomScoreSessionFuture = future;
    try {
      final session = await future;
      if (!mounted ||
          _roomScoreRunClosed ||
          !identical(_roomScoreSessionFuture, future)) {
        return;
      }
      setState(() => _roomScoreSession = session);
    } catch (_) {
      // Phiên không chấm được (phòng dừng, thiếu dữ liệu tham chiếu): bỏ qua
      // im lặng, đúng như luồng web.
      if (identical(_roomScoreSessionFuture, future)) {
        _roomScoreSessionFuture = null;
        _roomScoreSession = null;
      }
    }
  }

  Future<void> _teardownScoreRun({required bool finishIfNearEnd}) async {
    if (_roomScoreRunId == null || _roomScoreRunClosed) return;
    final nearEnd =
        _roomScoreDurationMs > 0 &&
        _roomAudio.position.inMilliseconds >= _roomScoreDurationMs - 700;
    if (finishIfNearEnd && nearEnd) {
      await _finishRoomScoreRun();
      return;
    }
    final capture = _roomCapture;
    _roomCapture = null;
    if (capture != null) {
      await capture.cancel();
      await capture.dispose();
    }
    _roomScoreRunClosed = true;
  }

  Future<void> _startRoomCapture() async {
    final room = _joined;
    if (room == null ||
        _roomCapture != null ||
        _roomCaptureStarting ||
        _roomScoreFinishing ||
        _roomScoreRunClosed ||
        _scorePermissionDenied) {
      return;
    }
    final playback = room['playback'] as Map<String, dynamic>? ?? const {};
    if (playback['status'] != 'PLAYING') return;
    if (_voice?.microphoneOn == true) {
      if (!_voiceMicHintShown) {
        _voiceMicHintShown = true;
        _message('Micro voice đang bật nên không thu được giọng để chấm điểm.');
      }
      return;
    }
    _roomCaptureStarting = true;
    PitchCapture? capture;
    try {
      final granted = await PitchCapture.requestMicrophonePermission();
      if (!mounted) return;
      if (!granted) {
        _scorePermissionDenied = true;
        if (!_permissionHintShown) {
          _permissionHintShown = true;
          _message('Cần cấp quyền micro để tham gia chấm điểm chung.');
        }
        return;
      }
      final sessionFuture = _roomScoreSessionFuture;
      if (sessionFuture == null) return;
      final session = await sessionFuture;
      if (!mounted ||
          !identical(_roomScoreSessionFuture, sessionFuture) ||
          _roomScoreRunClosed ||
          session['status'] != 'collecting') {
        return;
      }
      final roomId = (room['id'] as num).toInt();
      final sessionId = session['sessionId']?.toString() ?? '';
      if (sessionId.isNotEmpty && _roomScoreRegisteredSessionId != sessionId) {
        final registered = await ref
            .read(karaokeRepositoryProvider)
            .registerRoomScoreParticipant(roomId, sessionId);
        _roomScoreRegisteredSessionId =
            registered['sessionId']?.toString() ?? sessionId;
      }
      final activeCapture = PitchCapture();
      capture = activeCapture;
      activeCapture.onFailure = (_) {
        if (!mounted || !identical(_roomCapture, activeCapture)) return;
        setState(() => _roomCapture = null);
        unawaited(() async {
          await activeCapture.cancel();
          await activeCapture.dispose();
        }());
      };
      await activeCapture.start();
      if (activeCapture.failure != null) {
        throw StateError('Không thể bật micro để chấm điểm.');
      }
      final latest = _joined?['playback'] as Map<String, dynamic>? ?? const {};
      if (!mounted ||
          latest['status'] != 'PLAYING' ||
          latest['playbackRunId']?.toString() != _roomScoreRunId) {
        await activeCapture.cancel();
        await activeCapture.dispose();
        return;
      }
      setState(() {
        _roomCapture = activeCapture;
        _roomScoreStartOffsetMs = _roomAudio.position.inMilliseconds;
      });
    } catch (_) {
      await capture?.cancel();
      await capture?.dispose();
      // Không thu được micro (ví dụ thiết bị khác đang chiếm mic): bỏ qua lượt này.
    } finally {
      _roomCaptureStarting = false;
    }
  }

  Future<void> _stopRoomCaptureAndSubmit([PitchCapture? provided]) async {
    final capture = provided ?? _roomCapture;
    if (capture == null) return;
    _roomCapture = null;
    Map<String, dynamic>? segment;
    try {
      final features = await capture.finish(startOffsetMs: 0);
      segment = _buildScoreSegment(features);
    } catch (_) {
      if (mounted) _message('Không thể chốt phần ghi giọng vừa rồi.');
    } finally {
      await capture.dispose();
    }
    if (segment == null) return;
    _roomScoreSegments.add(segment);
    await _submitRoomContribution();
  }

  Map<String, dynamic>? _buildScoreSegment(Map<String, dynamic> features) {
    final remainingMs = _roomScoreDurationMs - _roomScoreStartOffsetMs;
    if (remainingMs <= 50) return null;
    final availableSeconds = remainingMs / 1000;
    final durationSeconds =
        ((features['duration_seconds'] as num?)?.toDouble() ?? 0).clamp(
          0.0,
          availableSeconds,
        );
    final maxFrames =
        (durationSeconds * PitchCapture.sampleRate / PitchCapture.hopSize)
            .ceil();
    final f0 = ((features['f0_hz'] as List?) ?? const [])
        .take(maxFrames)
        .toList(growable: false);
    final probability = ((features['voiced_probability'] as List?) ?? const [])
        .take(maxFrames)
        .toList(growable: false);
    if (durationSeconds <= 0.05 || f0.isEmpty || probability.isEmpty) {
      return null;
    }
    var reliableFrames = 0;
    for (var i = 0; i < f0.length; i++) {
      final pitch = f0[i];
      final confidence = probability[i];
      if (pitch is num &&
          pitch.isFinite &&
          confidence is num &&
          confidence >= .5) {
        reliableFrames++;
      }
    }
    if (reliableFrames * PitchCapture.hopSize / PitchCapture.sampleRate < 2) {
      return null;
    }
    return {
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
  }

  Future<void> _submitRoomContribution() async {
    final room = _joined;
    final future = _roomScoreSessionFuture;
    if (room == null || future == null || _roomScoreSegments.isEmpty) return;
    try {
      final session = await future;
      if (_roomScoreRunClosed || session['status'] != 'collecting') return;
      final sessionId = session['sessionId']?.toString() ?? '';
      if (sessionId.isEmpty) return;
      final roomId = (room['id'] as num).toInt();
      if (_roomScoreRegisteredSessionId != sessionId) {
        final registered = await ref
            .read(karaokeRepositoryProvider)
            .registerRoomScoreParticipant(roomId, sessionId);
        _roomScoreRegisteredSessionId =
            registered['sessionId']?.toString() ?? sessionId;
      }
      final updated = await ref
          .read(karaokeRepositoryProvider)
          .submitRoomScoreContribution(
            roomId: roomId,
            sessionId: sessionId,
            segments: List.unmodifiable(_roomScoreSegments),
          );
      if (mounted && identical(_roomScoreSessionFuture, future)) {
        setState(() => _roomScoreSession = updated);
      }
    } catch (_) {
      // Đợt gửi thất bại: segment kế tiếp hoặc lúc chốt sẽ gửi lại toàn bộ.
    }
  }

  Future<void> _finishRoomScoreRun() async {
    if (_roomScoreFinishing || _roomScoreRunClosed || _roomScoreRunId == null) {
      return;
    }
    _roomScoreFinishing = true;
    try {
      final capture = _roomCapture;
      if (capture != null) await _stopRoomCaptureAndSubmit(capture);
      final future = _roomScoreSessionFuture;
      final roomId = (_joined?['id'] as num?)?.toInt();
      if (future == null || roomId == null) return;
      final session = await future;
      final sessionId = session['sessionId']?.toString() ?? '';
      if (sessionId.isEmpty) return;
      if (session['status'] == 'collecting') {
        await _submitRoomContribution();
        final finished = await ref
            .read(karaokeRepositoryProvider)
            .finishRoomScoreSession(roomId, sessionId);
        if (mounted && identical(_roomScoreSessionFuture, future)) {
          setState(() => _roomScoreSession = finished);
        }
        _maybeShowScoreDialog(finished);
      } else {
        _maybeShowScoreDialog(session);
      }
    } catch (_) {
      // Chốt thất bại: poll tiếp tục lấy kết quả chung mà máy chủ đã tính.
    } finally {
      _roomScoreFinishing = false;
      _roomScoreRunClosed = true;
    }
  }

  void _maybeShowScoreDialog(Map<String, dynamic> session) {
    if (!mounted) return;
    final score = session['score'] as Map<String, dynamic>?;
    final overall =
        ((score?['score'] as Map<String, dynamic>?)?['overall'] as num?)
            ?.toDouble();
    final sessionId = session['sessionId']?.toString() ?? '';
    if (overall == null ||
        sessionId.isEmpty ||
        _scoreDialogShownFor.contains(sessionId)) {
      return;
    }
    _scoreDialogShownFor.add(sessionId);
    showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          _KaraokeScoreDialog(title: _roomScoreSongTitle, score: overall),
    );
  }

  Future<void> _pollRoomScore() async {
    final runActive =
        _roomScoreRunId != null && !_roomScoreRunClosed && !_roomScoreFinishing;
    if (runActive &&
        _roomScoreDurationMs > 0 &&
        _roomAudio.position.inMilliseconds >= _roomScoreDurationMs - 300) {
      unawaited(_finishRoomScoreRun());
      return;
    }
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
      _maybeShowScoreDialog(latest);
    } catch (_) {
      // The score service can finish asynchronously; the next poll retries.
    }
  }

  Future<void> _leaveRoom(int id) async {
    try {
      await _teardownScoreRun(finishIfNearEnd: true);
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
    if (_roomScoreRunId != null &&
        (_roomScoreRunId != runId || track == null)) {
      await _teardownScoreRun(finishIfNearEnd: true);
      _roomScoreRunId = null;
      _roomScoreSessionFuture = null;
      _roomScoreSession = null;
    }
    if (track != null && runId != null && _roomScoreRunId == null) {
      _openScoreRun(playback, track, runId);
    }
    if (_roomScoreRunId != null && !_roomScoreRunClosed) {
      if (status == 'PLAYING') {
        unawaited(_startRoomCapture());
      } else if (_roomCapture != null) {
        unawaited(_stopRoomCaptureAndSubmit());
      }
    }
    if (track == null || runId == null || status == 'IDLE') {
      if (_roomAudio.playing) await _roomAudio.stop();
      if (!mounted) return;
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
      if (!mounted) return;
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
    var name = '';
    var private = false;
    final input = await showDialog<(String, bool)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Tạo phòng hát'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (value) => name = value,
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, (name.trim(), private)),
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || input == null || input.$1.isEmpty) return;
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
        _refresh();
      }
    } catch (error) {
      if (mounted) _message(karaokeError(error));
    }
  }

  Future<void> _join(Map<String, dynamic> room) async {
    final id = (room['id'] as num).toInt();
    String? code;
    if (room['visibility'] == 'PRIVATE') {
      var enteredCode = '';
      code = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nhập mã mời'),
          content: TextField(
            onChanged: (value) => enteredCode = value,
            decoration: const InputDecoration(labelText: 'Mã phòng'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, enteredCode),
              child: const Text('Tham gia'),
            ),
          ],
        ),
      );
      if (!mounted || code == null) return;
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
      final track = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => const _RoomTrackPicker(),
      );
      if (!mounted || track == null) return;
      final current = _joined;
      if (current == null) return;
      final id = (current['id'] as num).toInt();
      final songId = track['songId']?.toString() ?? '';
      if (songId.isEmpty) throw const FormatException('Thiếu mã bài hát.');
      await ref.read(karaokeRepositoryProvider).addQueue(id, songId);
      if (!mounted) return;
      final updated = await ref.read(karaokeRepositoryProvider).room(id);
      if (mounted) setState(() => _joined = updated);
    } catch (error) {
      if (mounted) _message(karaokeError(error));
    }
  }

  Future<void> _closeRoom(int id) async {
    try {
      await _teardownScoreRun(finishIfNearEnd: true);
      await _voiceEvents?.cancel();
      _voiceEvents = null;
      await _voice?.dispose();
      _voice = null;
      await _roomAudio.stop();
      if (!mounted) return;
      ref.read(karaokePlaybackActiveProvider.notifier).state = false;
      await ref.read(karaokeRepositoryProvider).closeRoom(id);
      if (mounted) {
        setState(() => _joined = null);
        _refresh();
      }
    } catch (error) {
      if (mounted) _message(karaokeError(error));
    }
  }

  void _showMemberVolume(Map<String, dynamic> member) {
    final currentId = ref.read(sessionControllerProvider).session?.user.id;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _MemberVolumeSheet(
        member: member,
        voice: _voice,
        isSelf: currentId != null && member['userId']?.toString() == currentId,
      ),
    );
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
    return Scaffold(
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
          else ...[
            if (joined['canManage'] == true)
              IconButton(
                tooltip: 'Đóng phòng',
                onPressed: () => _closeRoom((joined['id'] as num).toInt()),
                icon: const Icon(Icons.meeting_room_outlined),
              ),
            IconButton(
              tooltip: 'Rời phòng',
              onPressed: () => _leaveRoom((joined['id'] as num).toInt()),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ],
      ),
      body: joined != null
          ? _RoomDetailView(
              room: joined,
              audio: _roomAudio,
              onAddTrack: _addTrack,
              onCommand: _roomCommand,
              onMemberTap: _showMemberVolume,
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
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF302849), Color(0xFF171620)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFF493D61)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.people_alt_rounded,
                              color: Color(0xFFC8B7FF),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Cùng nhau cất giọng',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tạo phòng hoặc tham gia phòng đang mở.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.secondary),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _create,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Tạo phòng'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Phòng đang mở',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      if (rooms.isEmpty)
                        const _RoomPanel(
                          child: Text(
                            'Chưa có phòng đang mở. Hãy tạo phòng mới.',
                            style: TextStyle(color: AppColors.secondary),
                          ),
                        )
                      else
                        ...rooms.map(
                          (room) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: const Color(0xFF15141E),
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => _join(room),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF352C4B),
                                          borderRadius: BorderRadius.circular(
                                            13,
                                          ),
                                        ),
                                        child: Icon(
                                          room['visibility'] == 'PRIVATE'
                                              ? Icons.lock_outline_rounded
                                              : Icons.mic_rounded,
                                          color: const Color(0xFFC8B7FF),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              room['name']?.toString() ??
                                                  'Phòng hát',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelLarge,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${room['hostName'] ?? 'Người tổ chức'} · ${room['memberCount'] ?? '—'}/${room['maxMembers'] ?? '—'} người',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppColors.secondary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.secondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
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
    required this.onMemberTap,
  });
  final Map<String, dynamic> room;
  final AudioPlayer audio;
  final VoidCallback onRefresh;
  final VoidCallback onAddTrack;
  final ValueChanged<String> onCommand;
  final ValueChanged<int> onRemoveQueue;
  final ValueChanged<Map<String, dynamic>> onMemberTap;
  @override
  Widget build(BuildContext context) {
    final members = room['members'] as List? ?? const [];
    final queue = room['queue'] as List? ?? const [];
    final playback = room['playback'] as Map<String, dynamic>? ?? const {};
    final track = playback['track'] as Map<String, dynamic>?;
    final canManage = room['canManage'] == true;
    final playing = playback['status'] == 'PLAYING';
    final textTheme = Theme.of(context).textTheme;
    Map<String, dynamic>? myQueueItem;
    for (final raw in queue) {
      if (raw is Map<String, dynamic> && raw['requestedByMe'] == true) {
        myQueueItem = raw;
        break;
      }
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF332A50), Color(0xFF171620)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF4A3F64)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.graphic_eq_rounded,
                      color: Color(0xFFBEACFF),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PHÒNG KARAOKE',
                        style: textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFD2C7F6),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (track != null)
                      MusicArtwork(
                        image: track['imageUrl']?.toString(),
                        size: 64,
                      )
                    else
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFF514574),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Color(0xFFE2D9FF),
                          size: 30,
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track?['title']?.toString() ?? 'Chưa có bài hát',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track == null
                                ? 'Thêm bài để bắt đầu hát cùng nhau'
                                : (track['artist']?.toString() ?? ''),
                            style: textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFCCC5D9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (track != null) ...[
                  const SizedBox(height: 18),
                  const Center(
                    child: Text(
                      'LỜI BÀI HÁT',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SyncedRoomLyrics(
                    timeline: track['lyricTimeline'],
                    syncedLyrics: track['lyricsSynced']?.toString(),
                    plainLyrics: track['lyricsPlain']?.toString(),
                    position: audio.positionStream,
                  ),
                ],
                if (canManage) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        onPressed: playback['status'] == 'IDLE' && queue.isEmpty
                            ? null
                            : () => onCommand(
                                playing
                                    ? 'pause'
                                    : playback['status'] == 'PAUSED'
                                    ? 'resume'
                                    : 'start',
                              ),
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        tooltip: playing ? 'Tạm dừng' : 'Phát',
                      ),
                      if (track != null) ...[
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          onPressed: () => onCommand('skip'),
                          icon: const Icon(Icons.skip_next_rounded),
                          tooltip: 'Bỏ qua',
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _RoomSectionHeader(
            title: 'Thành viên',
            subtitle:
                '${room['memberCount'] ?? members.length}/${room['maxMembers'] ?? '—'} người',
          ),
          const SizedBox(height: 10),
          if (members.isEmpty)
            Text(
              'Chưa có thông tin thành viên.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final raw in members)
                  _RoomMemberAvatar(
                    member: raw as Map<String, dynamic>,
                    onTap: onMemberTap,
                  ),
              ],
            ),
          if (room['visibility'] == 'PRIVATE' &&
              room['inviteCode'] != null &&
              canManage) ...[
            const SizedBox(height: 12),
            _RoomPanel(
              child: SelectableText(
                'Mã mời: ${room['inviteCode']}',
                style: const TextStyle(color: AppColors.secondary),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _RoomSectionHeader(
            title: 'Hàng đợi',
            subtitle: '${queue.length} bài',
          ),
          const SizedBox(height: 10),
          _RoomPanel(
            child: queue.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hàng đợi đang trống.'),
                      const SizedBox(height: 4),
                      Text(
                        canManage
                            ? 'Chọn bài hát để mọi người cùng thưởng thức.'
                            : 'Chờ chủ phòng thêm bài hát.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      for (final raw in queue)
                        Builder(
                          builder: (context) {
                            final item = raw as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  MusicArtwork(
                                    image: item['imageUrl']?.toString(),
                                    size: 44,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title']?.toString() ??
                                              'Bài hát',
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          item['artist']?.toString() ?? '',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: AppColors.secondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (item['requestedByMe'] == true)
                                    IconButton(
                                      tooltip: 'Xóa khỏi hàng đợi',
                                      onPressed: () => onRemoveQueue(
                                        (item['id'] as num).toInt(),
                                      ),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          if (myQueueItem != null)
            FilledButton.tonalIcon(
              onPressed: () =>
                  onRemoveQueue((myQueueItem!['id'] as num).toInt()),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Rút lượt hát của tôi'),
            )
          else
            FilledButton.icon(
              onPressed: onAddTrack,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm bài'),
            ),
        ],
      ),
    );
  }
}

class _RoomTrackPicker extends ConsumerStatefulWidget {
  const _RoomTrackPicker();
  @override
  ConsumerState<_RoomTrackPicker> createState() => _RoomTrackPickerState();
}

class _RoomTrackPickerState extends ConsumerState<_RoomTrackPicker> {
  final _search = TextEditingController();
  Timer? _debounce;
  late Future<List<Map<String, dynamic>>> _tracks;

  @override
  void initState() {
    super.initState();
    _tracks = ref.read(karaokeRepositoryProvider).tracks();
  }

  void _query(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(
        () =>
            _tracks = ref.read(karaokeRepositoryProvider).tracks(query: value),
      );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final available =
        MediaQuery.sizeOf(context).height -
        keyboard -
        MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: available.clamp(0.0, 620.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Thêm bài vào hàng đợi',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _search,
                  onChanged: _query,
                  maxLength: 100,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Tìm tên bài hát hoặc nghệ sĩ',
                    counterText: '',
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _tracks,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
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
                    final tracks = snapshot.data ?? const [];
                    if (tracks.isEmpty) {
                      return const Center(
                        child: Text(
                          'Không tìm thấy bài karaoke phù hợp.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.secondary),
                        ),
                      );
                    }
                    return ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: tracks.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = tracks[index];
                        final id = item['songId']?.toString() ?? '';
                        return ListTile(
                          leading: MusicArtwork(
                            image: item['imageUrl']?.toString(),
                            size: 48,
                          ),
                          title: Text(item['title']?.toString() ?? 'Bài hát'),
                          subtitle: Text(
                            item['artist']?.toString() ?? 'Chưa rõ nghệ sĩ',
                          ),
                          trailing: const Icon(Icons.add_rounded),
                          enabled: id.isNotEmpty,
                          onTap: id.isEmpty
                              ? null
                              : () => Navigator.pop(context, item),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomMemberAvatar extends ConsumerWidget {
  const _RoomMemberAvatar({required this.member, required this.onTap});
  final Map<String, dynamic> member;
  final ValueChanged<Map<String, dynamic>> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = member['name']?.toString().trim();
    final displayName = name == null || name.isEmpty ? 'Thành viên' : name;
    final avatar = ref
        .watch(catalogRepositoryProvider)
        .artwork(member['avatarUrl']?.toString());
    final fallback = Center(
      child: Text(
        displayName.characters.first.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
    return Tooltip(
      message: displayName,
      child: Semantics(
        button: true,
        label:
            'Âm lượng của $displayName${member['host'] == true ? ', chủ phòng' : ''}',
        child: InkWell(
          onTap: () => onTap(member),
          borderRadius: BorderRadius.circular(28),
          child: SizedBox.square(
            dimension: 56,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipOval(
                    child: ColoredBox(
                      color: const Color(0xFF514574),
                      child: avatar == null
                          ? fallback
                          : Image.network(
                              avatar.toString(),
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                              errorBuilder: (_, _, _) => fallback,
                            ),
                    ),
                  ),
                ),
                if (member['host'] == true)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF8B72F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberVolumeSheet extends StatefulWidget {
  const _MemberVolumeSheet({
    required this.member,
    required this.voice,
    required this.isSelf,
  });
  final Map<String, dynamic> member;
  final KaraokeVoiceClient? voice;
  final bool isSelf;
  @override
  State<_MemberVolumeSheet> createState() => _MemberVolumeSheetState();
}

class _MemberVolumeSheetState extends State<_MemberVolumeSheet> {
  late final String _userId;
  late double _volume;
  bool _saving = false;
  String? _error;
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _userId = widget.member['userId']?.toString() ?? '';
    _volume = widget.voice?.userVolume(_userId) ?? 1;
    _subscription = widget.voice?.onChanged.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _apply(double value) async {
    final voice = widget.voice;
    if (voice == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await voice.setUserVolume(_userId, value);
    } catch (_) {
      if (mounted) {
        setState(() {
          _volume = voice.userVolume(_userId);
          _error =
              'Không thể điều chỉnh âm lượng. Hãy kiểm tra kết nối voice và thử lại.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available =
        !widget.isSelf &&
        _userId.isNotEmpty &&
        (widget.voice?.hasRemoteAudio(_userId) ?? false);
    final name = widget.member['name']?.toString().trim();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name == null || name.isEmpty ? 'Thành viên' : name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.isSelf
                  ? 'Bạn không thể chỉnh âm lượng giọng của chính mình tại đây.'
                  : available
                  ? 'Điều chỉnh âm lượng giọng nói trên thiết bị của bạn.'
                  : 'Chỉ có thể điều chỉnh khi voice đã kết nối và thành viên đang phát âm thanh.',
              style: const TextStyle(color: AppColors.secondary),
            ),
            if (available) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.volume_down_rounded),
                  Expanded(
                    child: Slider(
                      value: _volume,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      label: '${(_volume * 100).round()}%',
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _volume = value),
                      onChangeEnd: _saving ? null : _apply,
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded),
                  const SizedBox(width: 4),
                  Text('${(_volume * 100).round()}%'),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoomPanel extends StatelessWidget {
  const _RoomPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF15141E),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF302B3A)),
    ),
    child: child,
  );
}

class _RoomSectionHeader extends StatelessWidget {
  const _RoomSectionHeader({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 3),
      Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
      ),
    ],
  );
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
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
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
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            style: TextStyle(
                              color: active
                                  ? const Color(0xFFF0EAFE)
                                  : AppColors.secondary.withValues(alpha: .65),
                              fontSize: active ? 21 : 15,
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

class _KaraokeScoreDialog extends StatelessWidget {
  const _KaraokeScoreDialog({required this.title, required this.score});
  final String title;
  final double score;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF302641), Color(0xFF191720)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF4B3C5E)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF413458),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: Color(0xFFD6C7FF),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Kết quả karaoke',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.secondary),
              ),
              const SizedBox(height: 24),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: reducedMotion ? score : 0, end: score),
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => SizedBox(
                  width: 148,
                  height: 148,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: (value / 100).clamp(0.0, 1.0),
                          strokeWidth: 7,
                          strokeCap: StrokeCap.round,
                          backgroundColor: const Color(0xFF443B50),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFFB9A1FF),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 36,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF2ECFF),
                            ),
                          ),
                          const Text(
                            '/ 100',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8D72DB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Tiếp tục'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        disabledForegroundColor: isActive ? const Color(0xFFB9A9FF) : null,
      ),
    ),
  );
}

class _SyncedRoomLyrics extends StatefulWidget {
  const _SyncedRoomLyrics({
    required this.timeline,
    required this.syncedLyrics,
    required this.plainLyrics,
    required this.position,
  });
  final Object? timeline;
  final String? syncedLyrics;
  final String? plainLyrics;
  final Stream<Duration> position;

  @override
  State<_SyncedRoomLyrics> createState() => _SyncedRoomLyricsState();
}

class _SyncedRoomLyricsState extends State<_SyncedRoomLyrics> {
  late List<_KaraokeLyricLine> _lines;

  @override
  void initState() {
    super.initState();
    _readLyrics();
  }

  @override
  void didUpdateWidget(covariant _SyncedRoomLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeline != widget.timeline ||
        oldWidget.syncedLyrics != widget.syncedLyrics ||
        oldWidget.plainLyrics != widget.plainLyrics) {
      _readLyrics();
    }
  }

  void _readLyrics() {
    // Dùng chung bộ parse với màn solo: ưu tiên lyricTimeline, thiếu thì tự
    // parse lời đồng bộ LRC (cách web highlight trong phòng), cuối cùng là
    // lời trơn.
    _lines = _parseKaraokeLyrics(
      timeline: widget.timeline,
      syncedLyrics: widget.syncedLyrics,
      plainLyrics: widget.plainLyrics,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) {
      return const Text(
        'Bài hát chưa có lời được cung cấp.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.secondary),
      );
    }
    final hasTiming = _lines.any((line) => line.startMs != null);
    if (!hasTiming) {
      return Text(
        _lines.take(3).map((line) => line.text).join('\n'),
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.secondary, fontSize: 14, height: 1.5),
      );
    }
    return StreamBuilder<Duration>(
      stream: widget.position,
      builder: (context, snapshot) {
        final ms = (snapshot.data ?? Duration.zero).inMilliseconds;
        var active = -1;
        for (var i = 0; i < _lines.length; i++) {
          final startMs = _lines[i].startMs;
          if (startMs != null && startMs <= ms) {
            active = i;
          } else if (startMs != null) {
            break;
          }
        }
        if (active < 0) {
          // Nhạc dạo chưa tới câu nào: hiện câu sắp tới, không sáng câu nào
          // (như màn solo).
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final line in _lines.take(2))
                Text(
                  line.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondary.withValues(alpha: .55),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
            ],
          );
        }
        String lineText(int index) =>
            index < 0 || index >= _lines.length ? '' : _lines[index].text;

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
            if (active + 1 < _lines.length)
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
