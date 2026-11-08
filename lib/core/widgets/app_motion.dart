import 'package:flutter/material.dart';

abstract final class AppMotion {
  static Duration duration(BuildContext context, [int milliseconds = 220]) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);
}

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  final _pressed = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _pressed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _pressed,
    child: InkWell(
      borderRadius: widget.borderRadius,
      onTap: widget.onTap,
      onHighlightChanged: widget.onTap == null
          ? null
          : (value) {
              if (_pressed.value != value) _pressed.value = value;
            },
      child: widget.child,
    ),
    builder: (context, pressed, child) => AnimatedScale(
      scale: pressed && widget.onTap != null ? .98 : 1,
      duration: AppMotion.duration(context, 100),
      curve: Curves.easeOutCubic,
      child: child,
    ),
  );
}

/// Runs once per mounted section; playback ticks do not restart the entrance.
class SectionEntrance extends StatefulWidget {
  const SectionEntrance({super.key, required this.child, this.order = 0});
  final Widget child;
  final int order;

  @override
  State<SectionEntrance> createState() => _SectionEntranceState();
}

class _SectionEntranceState extends State<SectionEntrance> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done || MediaQuery.disableAnimationsOf(context)) return widget.child;
    final delay = widget.order.clamp(0, 4) * 35;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + delay),
      curve: Interval(delay / (240 + delay), 1, curve: Curves.easeOutCubic),
      onEnd: () {
        if (mounted && !_done) setState(() => _done = true);
      },
      child: widget.child,
      builder: (_, value, child) {
        if (value >= 0.999) return child!;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}
