import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import 'app_motion.dart';

/// Danh sách tài nguyên ảnh banner, quảng cáo và cover từ dự án Web Moodify.
abstract final class MoodifyWebAssets {
  static const moodBanner = 'assets/banners/mood_banner.jpg';
  static const audioExperienceBanner =
      'assets/banners/audio_experience_banner.jpg';
  static const tunedMomentBanner = 'assets/banners/tuned_moment_banner.jpg';
  static const creatorStudio = 'assets/banners/creator_studio.jpg';
  static const heroBannerWide = 'assets/banners/moodify_hero_banner_wide.webp';
  static const soundwaveDark = 'assets/banners/moodify_soundwave_dark.webp';

  static const adBrandIdent = 'assets/ads/moodify_brand_ident_art.jpg';
  static const adVipPremium = 'assets/ads/moodify_vip_premium_art.jpg';

  static const coverEchoesSoul = 'assets/covers/echoes-soul.jpg';
  static const coverFocusFlow = 'assets/covers/focus-flow.jpg';
  static const coverMidnightMirage = 'assets/covers/midnight-mirage.jpg';
  static const coverNeonPulse = 'assets/covers/neon-pulse.jpg';
  static const coverSaigonRain = 'assets/covers/saigon-rain.jpg';
}

/// Banner Hero chuẩn Studio Dark có nền ảnh từ dự án Web, lớp phủ chuyển sắc
/// sâu và chiều cao tự co giãn theo nội dung (an toàn với chữ lớn 1.8x & màn 320px).
class StudioHeroBanner extends StatelessWidget {
  const StudioHeroBanner({
    super.key,
    required this.imageAsset,
    this.eyebrow,
    this.eyebrowIcon,
    required this.title,
    required this.subtitle,
    this.tags = const [],
    this.footer,
    this.onTap,
    this.borderColor,
    this.imageAlignment = Alignment.centerRight,
    this.imageOpacity = 0.52,
  });

  final String imageAsset;
  final String? eyebrow;
  final IconData? eyebrowIcon;
  final String title;
  final String subtitle;
  final List<String> tags;
  final Widget? footer;
  final VoidCallback? onTap;
  final Color? borderColor;
  final AlignmentGeometry imageAlignment;
  final double imageOpacity;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    final body = Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            imageAsset,
            fit: BoxFit.cover,
            alignment: imageAlignment,
            cacheWidth: 640,
            color: Color.fromRGBO(255, 255, 255, imageOpacity),
            colorBlendMode: BlendMode.modulate,
            filterQuality: FilterQuality.low,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: AppColors.surfaceRaised),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xF2090A0D),
                  Color(0xCC0D0F16),
                  Color(0x9412151E),
                ],
                stops: [0.0, 0.58, 1.0],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x26090A0D), Color(0xD9090A0D)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eyebrow != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x28FFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x2EFFFFFF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (eyebrowIcon != null) ...[
                        Icon(eyebrowIcon, size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          eyebrow!,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Color(0xFFD0D3DF),
                ),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x22FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x1EFFFFFF)),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (footer != null) ...[const SizedBox(height: 16), footer!],
            ],
          ),
        ),
      ],
    );

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: borderColor ?? const Color(0x28FFFFFF)),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: onTap == null
            ? body
            : Material(
                color: AppColors.surfaceRaised,
                child: Pressable(
                  borderRadius: radius,
                  onTap: onTap,
                  child: body,
                ),
              ),
      ),
    );
  }
}

/// Quảng cáo / Banner nâng cấp Moodify VIP đồng bộ từ thiết kế Web
/// (`moodify_vip_premium_art.jpg` + `audio_experience_banner.jpg`).
class StudioVipAdBanner extends StatelessWidget {
  const StudioVipAdBanner({
    super.key,
    this.badge = 'SPONSORED · MOODIFY VIP',
    this.title = 'Mở khóa trải nghiệm âm nhạc chuẩn Studio',
    this.subtitle =
        'Nghe nhạc không quảng cáo, chuyển bài không giới hạn và tải bài hát nghe offline.',
    this.ctaLabel = 'Khám phá VIP',
    this.artworkAsset = MoodifyWebAssets.adVipPremium,
    this.backdropAsset = MoodifyWebAssets.audioExperienceBanner,
    this.onTap,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String artworkAsset;
  final String backdropAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    final action = onTap ?? () => context.push('/subscriptions');
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: AppColors.vipBorder),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: AppColors.surfaceRaised,
          child: Pressable(
            borderRadius: radius,
            onTap: action,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    backdropAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    cacheWidth: 640,
                    color: const Color.fromRGBO(255, 255, 255, 0.36),
                    colorBlendMode: BlendMode.modulate,
                    filterQuality: FilterQuality.low,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xEE18140E),
                          Color(0xD812131A),
                          Color(0xCC1B160F),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: DecoratedBox(
                              position: DecorationPosition.foreground,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0x44F59E0B),
                                ),
                              ),
                              child: Image.asset(
                                artworkAsset,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low,
                                excludeFromSemantics: true,
                                errorBuilder: (_, _, _) => const SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: Icon(
                                    Icons.workspace_premium_rounded,
                                    color: AppColors.vipGold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x29F59E0B),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.vipBorder,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.workspace_premium_rounded,
                                        size: 12,
                                        color: AppColors.vipGold,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          badge,
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.vipGold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.28,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: Color(0xFFCACDD8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  ctaLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF14110A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_outward_rounded,
                                size: 15,
                                color: Color(0xFF14110A),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

/// Dữ liệu 1 slide chiến dịch trên `StudioBannerShowcase`.
class StudioBannerSlide {
  const StudioBannerSlide({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.imageAsset,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String imageAsset;
  final VoidCallback onTap;
}

/// Bộ trình chiếu Banner chiến dịch từ dự án Web (`HeroCarousel` parity),
/// tự động co giãn chiều cao theo cỡ chữ, không dùng chiều cao cứng.
class StudioBannerShowcase extends StatefulWidget {
  const StudioBannerShowcase({super.key, required this.slides});
  final List<StudioBannerSlide> slides;

  @override
  State<StudioBannerShowcase> createState() => _StudioBannerShowcaseState();
}

class _StudioBannerShowcaseState extends State<StudioBannerShowcase> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();
    final current = widget.slides[_index % widget.slides.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -120) {
              setState(() => _index = (_index + 1) % widget.slides.length);
            } else if (velocity > 120) {
              setState(
                () => _index =
                    (_index - 1 + widget.slides.length) % widget.slides.length,
              );
            }
          },
          child: AnimatedSwitcher(
            duration: AppMotion.duration(context, 260),
            child: StudioHeroBanner(
              key: ValueKey(_index),
              imageAsset: current.imageAsset,
              eyebrow: current.eyebrow,
              eyebrowIcon: Icons.auto_awesome_rounded,
              title: current.title,
              subtitle: current.subtitle,
              onTap: current.onTap,
              footer: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            current.ctaLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.background,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: AppColors.background,
                        ),
                      ],
                    ),
                  ),
                  if (widget.slides.length > 1)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < widget.slides.length; i++)
                          GestureDetector(
                            onTap: () => setState(() => _index = i),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                                vertical: 6,
                              ),
                              child: AnimatedContainer(
                                duration: AppMotion.duration(context, 180),
                                width: i == _index ? 20 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: i == _index
                                      ? Colors.white
                                      : const Color(0x55FFFFFF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Thẻ chủ đề / tâm trạng có hình nền từ bộ cover của Web (`assets/covers/*`).
class StudioCoverTopicCard extends StatelessWidget {
  const StudioCoverTopicCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String imageAsset;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: AppColors.surfaceRaised,
          child: Pressable(
            borderRadius: radius,
            onTap: onTap,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    cacheWidth: 360,
                    color: const Color.fromRGBO(255, 255, 255, 0.55),
                    colorBlendMode: BlendMode.modulate,
                    filterQuality: FilterQuality.low,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x55090A0D),
                          Color(0xCC090A0D),
                          Color(0xF2090A0D),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (badge != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x2EFFFFFF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else
                        const SizedBox(height: 22),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: Color(0xFFD0D4E0),
                        ),
                      ),
                    ],
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
