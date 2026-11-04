import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';
import '../data/catalog_repository.dart';

class ArtworkBackdrop extends ConsumerWidget {
  const ArtworkBackdrop({super.key, this.image, this.hero = false});
  final String? image;
  final bool hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = ref.watch(catalogRepositoryProvider).artwork(image);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.surfaceRaised),
                if (uri != null)
                  AnimatedSwitcher(
                    duration: AppMotion.duration(context, 350),
                    child: SizedBox.expand(
                      key: ValueKey(uri),
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: 22,
                          sigmaY: 22,
                        ),
                        child: Image.network(
                          uri.toString(),
                          fit: BoxFit.cover,
                          cacheWidth: 360,
                          errorBuilder: (_, _, _) => const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: hero
                          ? [const Color(0xA019112E), const Color(0xED121219)]
                          : [const Color(0xBF0C0C10), const Color(0xFA0C0C10)],
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
