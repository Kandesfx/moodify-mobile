import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../features/auth/domain/session_state.dart';
import '../../features/auth/presentation/session_controller.dart';

/// Choreographed launch splash overlay that animates the Moodify wave logo on
/// cold start and smoothly transitions into the active route once both the
/// entrance motion and initial session restoration complete.
class SplashLaunchGate extends ConsumerStatefulWidget {
  const SplashLaunchGate({
    super.key,
    required this.child,
    this.entranceDuration = const Duration(milliseconds: 1850),
    this.exitDuration = const Duration(milliseconds: 380),
  });

  final Widget child;
  final Duration entranceDuration;
  final Duration exitDuration;

  @override
  ConsumerState<SplashLaunchGate> createState() => _SplashLaunchGateState();
}

class _SplashLaunchGateState extends ConsumerState<SplashLaunchGate>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _entranceController;
  late final AnimationController _loopController;
  late final AnimationController _exitController;
  late final Animation<double> _exitOpacity;
  late final Animation<double> _exitScale;
  bool _started = false;
  bool _dismissed = false;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entranceController = AnimationController(
      vsync: this,
      duration: widget.entranceDuration,
    )..addStatusListener(_onEntranceStatus);
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _exitController = AnimationController(
      vsync: this,
      duration: widget.exitDuration,
    )..addStatusListener(_onExitStatus);
    final exitCurve = CurvedAnimation(
      parent: _exitController,
      curve: Curves.easeInOutCubic,
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(exitCurve);
    _exitScale = Tween<double>(begin: 1.0, end: 1.16).animate(exitCurve);
  }

  @override
  void didChangeMetrics() {
    if (!_started && mounted && !_dismissed) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      unawaited(
        precacheImage(
          const AssetImage('assets/brand/moodify-mark.png'),
          context,
        ).catchError((Object _) {}),
      );
    }
    _ensureStarted();
  }

  void _ensureStarted() {
    if (_dismissed) return;
    final size = MediaQuery.sizeOf(context);
    // Wait until the Android SurfaceView / iOS window reports non-zero viewport
    // metrics so the animation never runs off-screen during engine pre-warming.
    if (size.width <= 0 || size.height <= 0) return;

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      if (disableAnimations) {
        _entranceController.value = 1;
        _tryComplete(immediate: true);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _dismissed) return;
          if (MediaQuery.disableAnimationsOf(context)) {
            _entranceController.value = 1;
            _tryComplete(immediate: true);
          } else {
            _entranceController.forward(from: 0);
          }
        });
      }
    } else if (disableAnimations && !_dismissed) {
      _loopController.stop();
      _entranceController.value = 1;
      _tryComplete(immediate: true);
    }
  }

  void _onEntranceStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && !_dismissed) {
      final phase = ref.read(sessionControllerProvider).phase;
      if (phase == SessionPhase.restoring &&
          !MediaQuery.disableAnimationsOf(context)) {
        _loopController.repeat();
      } else {
        _tryComplete(immediate: MediaQuery.disableAnimationsOf(context));
      }
    }
  }

  void _onExitStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && !_dismissed) {
      _loopController.stop();
      setState(() => _dismissed = true);
    }
  }

  void _tryComplete({required bool immediate}) {
    if (!mounted || _dismissed) return;
    final phase = ref.read(sessionControllerProvider).phase;
    if (phase == SessionPhase.restoring) return;
    _loopController.stop();
    if (phase == SessionPhase.restoreFailed) {
      // Reveal the restore recovery actions immediately without extra delay.
      _exitController.value = 1;
      setState(() => _dismissed = true);
      return;
    }
    if (!_entranceController.isCompleted) return;
    if (immediate) {
      _exitController.value = 1;
      setState(() => _dismissed = true);
    } else if (!_exitController.isAnimating && !_exitController.isCompleted) {
      _exitController.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entranceController.dispose();
    _loopController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensureStarted();
    ref.listen<SessionPhase>(sessionControllerProvider.select((s) => s.phase), (
      _,
      next,
    ) {
      if (next != SessionPhase.restoring) {
        _tryComplete(immediate: MediaQuery.disableAnimationsOf(context));
      }
    });

    final phase = ref.watch(sessionControllerProvider.select((s) => s.phase));
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_dismissed ||
        phase == SessionPhase.restoreFailed ||
        (disableAnimations && phase != SessionPhase.restoring)) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        RepaintBoundary(
          child: FadeTransition(
            opacity: _exitOpacity,
            child: ScaleTransition(
              scale: _exitScale,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _entranceController,
                  _loopController,
                  _exitController,
                ]),
                builder: (context, _) {
                  final exiting = _exitController.value > 0;
                  return IgnorePointer(
                    ignoring: exiting,
                    child: ExcludeSemantics(
                      excluding: exiting,
                      child: Material(
                        color: AppColors.background,
                        child: SafeArea(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  BrandSplashHero(
                                    progress: _entranceController.value,
                                    loopPhase: _loopController.value,
                                  ),
                                  if (phase == SessionPhase.restoring) ...[
                                    const SizedBox(height: 24),
                                    _RestoringWaveIndicator(
                                      progress: _entranceController.value,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated Moodify logo lockup driven by normalized [progress] in `0.0..1.0`.
/// Renders the soundwave 'M' mark with smooth scale & specular sheen,
/// acoustic ambient aura bloom, and staggered letter-by-letter wordmark.
class BrandSplashHero extends StatelessWidget {
  const BrandSplashHero({super.key, this.progress = 1.0, this.loopPhase = 0.0});

  final double progress;
  final double loopPhase;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final cycle = t + loopPhase;
    final markOpacity = const Interval(
      0.0,
      0.48,
      curve: Curves.easeOut,
    ).transform(t);
    final markScale = Tween<double>(begin: 0.72, end: 1.0).transform(
      const Interval(0.0, 0.60, curve: Curves.easeOutCubic).transform(t),
    );
    final markSlideY =
        16.0 *
        (1.0 -
            const Interval(0.0, 0.52, curve: Curves.easeOutCubic).transform(t));

    final taglineProgress = const Interval(
      0.48,
      0.90,
      curve: Curves.easeOutCubic,
    ).transform(t);

    final shimmerPhase = ((t - 0.42) / 0.48).clamp(0.0, 1.0);
    final shimmerAlpha = shimmerPhase > 0 && shimmerPhase < 1
        ? math.sin(shimmerPhase * math.pi) * 0.45
        : 0.0;

    return Semantics(
      label: 'Moodify',
      image: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 232,
              height: 148,
              child: CustomPaint(
                painter: _SplashAuraPainter(progress: t, cycle: cycle),
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, markSlideY),
                    child: Transform.scale(
                      scale: markScale,
                      child: _WaveRevealMark(
                        opacity: markOpacity,
                        shimmerPhase: shimmerPhase,
                        shimmerAlpha: shimmerAlpha,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: _AnimatedWordmark(progress: t),
            ),
            const SizedBox(height: 12),
            _SoundwaveEqualizer(progress: t, cycle: cycle),
            const SizedBox(height: 10),
            Opacity(
              opacity: taglineProgress,
              child: Transform.translate(
                offset: Offset(0, 6.0 * (1.0 - taglineProgress)),
                child: const Text(
                  'Âm nhạc theo từng cảm xúc',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                    color: AppColors.secondary,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedWordmark extends StatelessWidget {
  const _AnimatedWordmark({required this.progress});

  final double progress;
  static const _letters = ['m', 'o', 'o', 'd', 'i', 'f', 'y'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _letters.length; i++) _buildLetter(i, _letters[i]),
      ],
    );
  }

  Widget _buildLetter(int index, String char) {
    final start = 0.20 + (index * 0.05);
    final end = (start + 0.32).clamp(0.0, 1.0);
    final raw = ((progress - start) / (end - start)).clamp(0.0, 1.0);
    final opacity = Curves.easeOut.transform(raw);
    final pop = Curves.easeOutCubic.transform(raw);
    final slideY = 12.0 * (1.0 - pop);
    final scale = 0.8 + (0.2 * pop);

    final color = raw < 0.6
        ? Color.lerp(AppColors.primary, AppColors.lavender, raw / 0.6)!
        : Color.lerp(AppColors.lavender, AppColors.text, (raw - 0.6) / 0.4)!;

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, slideY),
        child: Transform.scale(
          scale: scale,
          child: Text(
            char,
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.0,
              color: color,
              height: 1.05,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _SoundwaveEqualizer extends StatelessWidget {
  const _SoundwaveEqualizer({required this.progress, required this.cycle});

  final double progress;
  final double cycle;
  static const _baseHeights = <double>[10, 18, 26, 16, 30, 18, 26, 16, 10];

  @override
  Widget build(BuildContext context) {
    final visibility = const Interval(
      0.32,
      0.75,
      curve: Curves.easeOut,
    ).transform(progress);
    if (visibility <= 0) return const SizedBox(height: 30);

    return Opacity(
      opacity: visibility,
      child: SizedBox(
        height: 30,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < _baseHeights.length; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              _buildBar(i, visibility),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBar(int index, double visibility) {
    final activeWave = progress < 0.999 || cycle > 1.0;
    final wave = activeWave
        ? 0.45 +
              0.55 *
                  (0.5 +
                      0.5 * math.sin((cycle * math.pi * 6.0) - (index * 0.65)))
        : 0.55;
    final h = (_baseHeights[index] * wave * visibility).clamp(4.0, 30.0);
    final t = index / (_baseHeights.length - 1);
    final color = t < 0.5
        ? Color.lerp(AppColors.primary, AppColors.lavender, t * 2)!
        : Color.lerp(AppColors.lavender, AppColors.liked, (t - 0.5) * 2)!;

    return Container(
      width: 4,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45 * visibility),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

class _WaveRevealMark extends StatelessWidget {
  const _WaveRevealMark({
    required this.opacity,
    required this.shimmerPhase,
    required this.shimmerAlpha,
  });

  final double opacity;
  final double shimmerPhase;
  final double shimmerAlpha;

  @override
  Widget build(BuildContext context) {
    Widget mark = Image.asset(
      'assets/brand/moodify-mark.png',
      width: 136,
      height: 74,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (shimmerAlpha > 0.005) {
      final center = -1.0 + (3.0 * shimmerPhase);
      mark = ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(center - 0.4, -0.6),
          end: Alignment(center + 0.4, 0.6),
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: shimmerAlpha),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(bounds),
        child: mark,
      );
    }

    return Opacity(opacity: opacity.clamp(0.0, 1.0), child: mark);
  }
}

class _SplashAuraPainter extends CustomPainter {
  const _SplashAuraPainter({required this.progress, required this.cycle});

  final double progress;
  final double cycle;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final glowCurve = Curves.easeOutCubic.transform(progress);
    final pulse = math.sin(cycle * math.pi * 1.5).abs();

    final glowRadius = (size.width * 0.46) * (0.65 + (0.35 * glowCurve));
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primary.withValues(
            alpha: (0.30 * glowCurve) + (0.10 * pulse),
          ),
          AppColors.liked.withValues(
            alpha: (0.15 * glowCurve) + (0.06 * pulse),
          ),
          AppColors.background.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    canvas.drawCircle(center, glowRadius, glowPaint);

    // Continuous flowing soundwave ribbons behind the M mark.
    final ribbonAlpha = (math.sin(progress * math.pi) * 0.42).clamp(0.14, 0.42);
    for (var waveIndex = 0; waveIndex < 2; waveIndex++) {
      final path = Path();
      final amplitude = (waveIndex == 0 ? 18.0 : 12.0) * glowCurve;
      final phaseShift = (cycle * math.pi * 5.0) + (waveIndex * math.pi * 0.85);
      final width = size.width * 0.92;
      final startX = (size.width - width) / 2;
      const steps = 48;
      for (var step = 0; step <= steps; step++) {
        final norm = step / steps;
        final envelope = math.sin(norm * math.pi);
        final x = startX + (width * norm);
        final y =
            center.dy +
            math.sin((norm * math.pi * 2.5) - phaseShift) *
                amplitude *
                envelope;
        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = waveIndex == 0 ? 2.2 : 1.4
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0),
            AppColors.primary.withValues(alpha: ribbonAlpha),
            AppColors.lavender.withValues(alpha: ribbonAlpha),
            AppColors.liked.withValues(alpha: ribbonAlpha),
            AppColors.liked.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
        ).createShader(Offset.zero & size);
      canvas.drawPath(path, wavePaint);
    }

    // Expanding harmonic wave rings around the logo.
    final ringPhase = cycle > 1.0 ? (cycle % 1.0) : progress;
    for (var i = 0; i < 2; i++) {
      final start = i * 0.18;
      final ringT = ((ringPhase - start) / (1.0 - start)).clamp(0.0, 1.0);
      if (ringT <= 0) continue;
      final eased = Curves.easeOutCubic.transform(ringT);
      final ringAlpha = (1.0 - eased) * 0.38;
      if (ringAlpha <= 0.01) continue;

      final rx = (44.0 + (i * 14.0)) + (48.0 * eased);
      final ry = (26.0 + (i * 8.0)) + (28.0 * eased);
      final rect = Rect.fromCenter(
        center: center,
        width: rx * 2,
        height: ry * 2,
      );
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: ringAlpha),
            AppColors.lavender.withValues(alpha: ringAlpha * 0.85),
            AppColors.liked.withValues(alpha: ringAlpha),
          ],
        ).createShader(rect);
      canvas.drawOval(rect, ringPaint);
    }
  }

  @override
  bool shouldRepaint(_SplashAuraPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.cycle != cycle;
}

class _RestoringWaveIndicator extends StatelessWidget {
  const _RestoringWaveIndicator({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final fade = const Interval(
      0.35,
      1.0,
      curve: Curves.easeOut,
    ).transform(progress.clamp(0.0, 1.0));
    return Semantics(
      label: 'Đang khôi phục phiên',
      child: Opacity(
        opacity: fade,
        child: SizedBox(
          width: 112,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress < 1.0 ? progress : null,
              minHeight: 3,
              backgroundColor: AppColors.surfaceRaised,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
