import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';
import '../data/catalog_repository.dart';

@immutable
class ArtworkPalette {
  const ArtworkPalette({
    required this.dominant,
    required this.deep,
    required this.accent,
    required this.miniPlayer,
  });

  final Color dominant;
  final Color deep;
  final Color accent;
  final Color miniPlayer;

  static const studioDefault = ArtworkPalette(
    dominant: Color(0xFF1E2433),
    deep: Color(0xFF0E1118),
    accent: Color(0xFFE2E8F0),
    miniPlayer: Color(0xFF161A24),
  );

  static ArtworkPalette fromHueSaturation(double hue, double saturation) {
    final h = hue % 360.0;
    final domSat = (saturation * 1.25).clamp(0.28, 0.72);
    final deepSat = (saturation * 1.10).clamp(0.22, 0.56);
    final accSat = (saturation * 1.35).clamp(0.42, 0.86);
    final miniSat = (saturation * 1.15).clamp(0.26, 0.58);
    return ArtworkPalette(
      dominant: HSLColor.fromAHSL(1.0, h, domSat, 0.28).toColor(),
      deep: HSLColor.fromAHSL(1.0, h, deepSat, 0.13).toColor(),
      accent: HSLColor.fromAHSL(1.0, h, accSat, 0.72).toColor(),
      miniPlayer: HSLColor.fromAHSL(1.0, h, miniSat, 0.17).toColor(),
    );
  }

  static ArtworkPalette lerp(ArtworkPalette a, ArtworkPalette b, double t) =>
      ArtworkPalette(
        dominant: Color.lerp(a.dominant, b.dominant, t) ?? b.dominant,
        deep: Color.lerp(a.deep, b.deep, t) ?? b.deep,
        accent: Color.lerp(a.accent, b.accent, t) ?? b.accent,
        miniPlayer: Color.lerp(a.miniPlayer, b.miniPlayer, t) ?? b.miniPlayer,
      );
}

final _paletteCache = <Uri, ArtworkPalette>{};

ArtworkPalette? cachedArtworkPalette(Uri? uri) =>
    uri == null ? null : _paletteCache[uri];

void _cachePalette(Uri uri, ArtworkPalette palette) {
  _paletteCache.remove(uri);
  _paletteCache[uri] = palette;
  while (_paletteCache.length > 64) {
    _paletteCache.remove(_paletteCache.keys.first);
  }
}

ArtworkPalette _extractPaletteFromRgba(ByteData data) {
  final binWeights = List<double>.filled(12, 0.0);
  final binHueSin = List<double>.filled(12, 0.0);
  final binHueCos = List<double>.filled(12, 0.0);
  final binSatSum = List<double>.filled(12, 0.0);

  final length = data.lengthInBytes;
  for (var i = 0; i + 3 < length; i += 4) {
    final a = data.getUint8(i + 3);
    if (a < 128) continue;
    final r = data.getUint8(i) / 255.0;
    final g = data.getUint8(i + 1) / 255.0;
    final b = data.getUint8(i + 2) / 255.0;

    final maxC = r > g ? (r > b ? r : b) : (g > b ? g : b);
    final minC = r < g ? (r < b ? r : b) : (g < b ? g : b);
    final l = (maxC + minC) * 0.5;
    if (l < 0.07 || l > 0.92) continue;

    final delta = maxC - minC;
    if (delta < 0.04) continue;
    final s = l > 0.5 ? delta / (2.0 - maxC - minC) : delta / (maxC + minC);
    if (s < 0.08) continue;

    double h;
    if (maxC == r) {
      h = ((g - b) / delta) % 6.0;
    } else if (maxC == g) {
      h = ((b - r) / delta) + 2.0;
    } else {
      h = ((r - g) / delta) + 4.0;
    }
    h *= 60.0;
    if (h < 0) h += 360.0;

    final weight = (0.2 + s * 1.4) * (1.0 - (l - 0.48).abs() * 1.35);
    if (weight <= 0) continue;

    final bin = (h ~/ 30).clamp(0, 11);
    final rad = h * 0.017453292519943295;
    binWeights[bin] += weight;
    binHueSin[bin] += weight * (rad - (rad * rad * rad) / 6.0);
    binHueCos[bin] += weight;
    binSatSum[bin] += weight * s;
  }

  var bestBin = -1;
  var bestWeight = 0.0;
  for (var b = 0; b < 12; b++) {
    if (binWeights[b] > bestWeight) {
      bestWeight = binWeights[b];
      bestBin = b;
    }
  }
  if (bestBin < 0 || bestWeight <= 0) {
    return ArtworkPalette.studioDefault;
  }
  final avgSat = (binSatSum[bestBin] / bestWeight).clamp(0.18, 0.85);
  final centerHue = bestBin * 30.0 + 15.0;
  return ArtworkPalette.fromHueSaturation(centerHue, avgSat);
}

class ArtworkPaletteBuilder extends ConsumerStatefulWidget {
  const ArtworkPaletteBuilder({
    super.key,
    required this.image,
    required this.builder,
  });

  final String? image;
  final Widget Function(BuildContext context, ArtworkPalette palette, Uri? uri)
  builder;

  @override
  ConsumerState<ArtworkPaletteBuilder> createState() =>
      _ArtworkPaletteBuilderState();
}

class _ArtworkPaletteBuilderState extends ConsumerState<ArtworkPaletteBuilder> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Uri? _resolvedUri;
  ArtworkPalette _palette = ArtworkPalette.studioDefault;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ArtworkPaletteBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _resolve();
    }
  }

  void _resolve() {
    final uri = ref.read(catalogRepositoryProvider).artwork(widget.image);
    if (uri == _resolvedUri && _paletteCache.containsKey(uri)) return;
    _unsubscribe();
    _resolvedUri = uri;
    if (uri == null) {
      if (_palette != ArtworkPalette.studioDefault) {
        setState(() => _palette = ArtworkPalette.studioDefault);
      }
      return;
    }
    final cached = _paletteCache[uri];
    if (cached != null) {
      if (_palette != cached) {
        setState(() => _palette = cached);
      }
      return;
    }
    final ImageProvider baseProvider = uri.scheme == 'file'
        ? FileImage(File.fromUri(uri))
        : NetworkImage(uri.toString());
    final provider = ResizeImage(baseProvider, width: 36, height: 36);
    final stream = provider.resolve(ImageConfiguration.empty);
    _stream = stream;
    final listener = ImageStreamListener(
      (imageInfo, _) async {
        try {
          final byteData = await imageInfo.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (byteData == null) return;
          final extracted = _extractPaletteFromRgba(byteData);
          _cachePalette(uri, extracted);
          if (mounted && _resolvedUri == uri) {
            setState(() => _palette = extracted);
          }
        } catch (_) {
          // Ignore decode errors in headless/test environments.
        }
      },
      onError: (_, _) {
        // Ignore network/file image errors in offline or widget test environments.
      },
    );
    _listener = listener;
    stream.addListener(listener);
  }

  void _unsubscribe() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uri = ref.watch(catalogRepositoryProvider).artwork(widget.image);
    if (uri != _resolvedUri) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resolve();
      });
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(_palette),
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.duration(context, 520),
      curve: Curves.easeOutCubic,
      builder: (context, _, _) => widget.builder(context, _palette, uri),
    );
  }
}

class ArtworkBackdrop extends ConsumerWidget {
  const ArtworkBackdrop({super.key, this.image, this.hero = false});
  final String? image;
  final bool hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: ClipRect(
            child: ArtworkPaletteBuilder(
              image: image,
              builder: (context, palette, uri) => Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedContainer(
                    duration: AppMotion.duration(context, 520),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.48, 1.0],
                        colors: [
                          palette.dominant,
                          palette.deep,
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
                  if (uri != null)
                    AnimatedSwitcher(
                      duration: AppMotion.duration(context, 320),
                      child: SizedBox.expand(
                        key: ValueKey(uri),
                        child: hero
                            // Inline cards inside scroll views avoid GPU blur
                            // and Opacity saveLayers so scrolling stays locked at 60fps.
                            ? _buildBackdropImage(uri, opacity: 0.32)
                            : ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: 28,
                                  sigmaY: 28,
                                ),
                                child: _buildBackdropImage(uri, opacity: 0.42),
                              ),
                      ),
                    ),
                  AnimatedContainer(
                    duration: AppMotion.duration(context, 520),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.38, 0.78, 1.0],
                        colors: hero
                            ? [
                                palette.dominant.withValues(alpha: 0.72),
                                palette.deep.withValues(alpha: 0.85),
                                const Color(0xE6090A0D),
                                AppColors.background,
                              ]
                            : [
                                palette.dominant.withValues(alpha: 0.62),
                                palette.deep.withValues(alpha: 0.78),
                                const Color(0xEB090A0D),
                                AppColors.background,
                              ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackdropImage(Uri uri, {required double opacity}) {
    final modulateColor = Color.fromRGBO(255, 255, 255, opacity);
    if (uri.scheme == 'file') {
      return Image.file(
        File.fromUri(uri),
        fit: BoxFit.cover,
        cacheWidth: 180,
        color: modulateColor,
        colorBlendMode: BlendMode.modulate,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.expand(),
      );
    }
    return Image.network(
      uri.toString(),
      fit: BoxFit.cover,
      cacheWidth: 180,
      color: modulateColor,
      colorBlendMode: BlendMode.modulate,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.expand(),
    );
  }
}
