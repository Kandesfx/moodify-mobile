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
class SectionEntrance extends StatelessWidget {
  const SectionEntrance({super.key, required this.child, this.order = 0});
  final Widget child;
  final int order;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final delay = order.clamp(0, 4) * 35;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + delay),
      curve: Interval(delay / (280 + delay), 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}
