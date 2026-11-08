import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/app_sheets.dart';
import '../../../core/widgets/studio_banners.dart';

import '../../auth/domain/session_state.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../offline/data/offline_repository.dart';
import '../../offline/presentation/offline_controller.dart';
import '../../subscriptions/application/premium_controller.dart';
import 'search_controller.dart';
import 'search_history_controller.dart';
import '../../auth/presentation/session_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ref.read(searchControllerProvider.notifier).submit(recordHistory: true);
  }

  void _quickSearch(String keyword, {bool mood = false}) {
    final controller = ref.read(searchControllerProvider.notifier);
    _text.text = keyword;
    controller.mode(mood);
    controller.change(keyword);
    _submit();
  }

  void _showMoodSignInPrompt(BuildContext context) {
    showAppModalSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        // Cuộn được để không tràn ở cỡ chữ lớn hoặc màn hình thấp.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        MoodifyWebAssets.moodBanner,
                        fit: BoxFit.cover,
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
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x55090A0D), Color(0xEB090A0D)],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Đăng nhập để tìm kiếm theo cảm xúc',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Mô tả tâm trạng của bạn để AI Mood Engine gợi ý những giai điệu đồng điệu nhất — miễn phí cho mọi tài khoản đã đăng nhập.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.push(
                    Uri(
                      path: '/sign-in',
                      queryParameters: const {'from': '/search'},
                    ).toString(),
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 20),
                label: const Text('Đăng nhập ngay'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final controller = ref.read(searchControllerProvider.notifier);
    final sessionState = ref.watch(sessionControllerProvider);
    final signedIn = sessionState.session != null;
    final hasOfflineScope = signedIn || sessionState.offlineUserId != null;
    final isOfflineSearch =
        hasOfflineScope &&
        (sessionState.phase == SessionPhase.restoreFailed ||
            state.failure != null);
    final offlineEntries = isOfflineSearch
        ? ref
              .watch(offlineControllerProvider)
              .entries
              .where((e) => !e.expired)
              .toList()
        : const <OfflineEntry>[];
    final normalizedQuery = state.query.trim().toLowerCase();
    final offlineMatches = offlineEntries
        .map((e) => e.track)
        .where(
          (track) =>
              normalizedQuery.isEmpty ||
              '${track.displayName} ${track.artist}'.toLowerCase().contains(
                normalizedQuery,
              ),
        )
        .toList(growable: false);
    final isPremium = ref.watch(premiumProvider.select((s) => s.isPremium));
    final history = ref.watch(searchHistoryProvider);
    // Phòng hờ: đang ở chế độ Cảm xúc mà đăng xuất → tự về chế độ Bài hát.
    if (!signedIn && state.mood) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(searchControllerProvider.notifier).mode(false);
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          // Ô tìm kiếm vào nhẹ một lần khi mở tab; gõ phím không chạy lại.
          SectionEntrance(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF13151B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          for (final mode in [false, true])
                            Expanded(
                              child: Semantics(
                                selected: state.mood == mode,
                                child: AnimatedContainer(
                                  duration: AppMotion.duration(context, 160),
                                  decoration: BoxDecoration(
                                    color: state.mood == mode
                                        ? const Color(0xFF222631)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: state.mood == mode
                                        ? Border.all(
                                            color: const Color(0x33FFFFFF),
                                          )
                                        : null,
                                  ),
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: Pressable(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        // Tìm kiếm theo cảm xúc chỉ yêu cầu đăng nhập
                                        // (đồng bộ với Backend /api/emotions/recommend & Web).
                                        if (mode && !signedIn) {
                                          _showMoodSignInPrompt(context);
                                          return;
                                        }
                                        controller.mode(mode);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 11,
                                          horizontal: 8,
                                        ),
                                        // FittedBox giữ nút không tràn khi
                                        // người dùng đặt cỡ chữ lớn.
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (mode && !signedIn) ...[
                                                const Icon(
                                                  Icons.lock_rounded,
                                                  size: 13,
                                                  color: AppColors.secondary,
                                                ),
                                                const SizedBox(width: 5),
                                              ],
                                              Text(
                                                mode ? 'Cảm xúc' : 'Bài hát',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: state.mood == mode
                                                      ? Colors.white
                                                      : AppColors.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _text,
                    onChanged: controller.change,
                    onSubmitted: (_) => _submit(),
                    textInputAction: TextInputAction.search,
                    maxLength: state.mood ? 500 : 100,
                    decoration: InputDecoration(
                      labelText: state.mood
                          ? 'Bạn đang cảm thấy thế nào?'
                          : 'Tên bài hát hoặc nghệ sĩ',
                      prefixIcon: const Icon(Icons.search_rounded),
                      counterText: '',
                      suffixIcon: state.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Xóa nội dung',
                              onPressed: () {
                                _text.clear();
                                controller.change('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  if (state.mood)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: state.loading || state.query.trim().isEmpty
                              ? null
                              : _submit,
                          icon: const Icon(Icons.graphic_eq_rounded),
                          label: const Text('Tìm nhạc theo cảm xúc'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (state.loading) const LinearProgressIndicator(),
          if (state.submitted && history.hasError)
            const LoadMessage(
              message:
                  'Kết quả tìm kiếm vẫn dùng được. Chưa lưu hoặc đồng bộ được lịch sử tìm kiếm.',
            ),
          if (state.moodResult?.emotion != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cảm xúc nhận diện: ${state.moodResult!.emotion}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _MoodVipTag(),
                ],
              ),
            ),
          ...[
            if (!state.submitted && signedIn && !state.mood) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tìm kiếm gần đây',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if ((history.valueOrNull ?? []).isNotEmpty)
                      TextButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Xóa lịch sử tìm kiếm?'),
                              content: const Text(
                                'Các tìm kiếm đã lưu trên tài khoản sẽ bị xóa.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Giữ lại'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && mounted) {
                            ref
                                .read(searchHistoryProvider.notifier)
                                .remove(null);
                          }
                        },
                        child: const Text('Xóa tất cả'),
                      ),
                  ],
                ),
              ),
              if (history.isLoading) const LinearProgressIndicator(),
              if (history.hasError)
                LoadMessage(
                  message: 'Chưa tải được lịch sử.',
                  retry: () => ref.read(searchHistoryProvider.notifier).load(),
                ),
              for (final entry in history.valueOrNull ?? [])
                ListTile(
                  leading: Icon(
                    entry.mood ? Icons.mood_rounded : Icons.history_rounded,
                  ),
                  title: Text(
                    entry.keyword,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    _text.text = entry.keyword;
                    controller.mode(entry.mood);
                    controller.change(entry.keyword);
                    _submit();
                  },
                  trailing: IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    onPressed: () => ref
                        .read(searchHistoryProvider.notifier)
                        .remove(entry.id),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
            ],
            if (!state.submitted &&
                (!signedIn ||
                    state.mood ||
                    (history.valueOrNull ?? []).isEmpty))
              LoadMessage(
                message: state.mood
                    ? 'Viết một vài câu về tâm trạng và nhấn tìm kiếm.'
                    : 'Tìm nhạc từ tên bài hát hoặc nghệ sĩ bạn yêu thích.',
              ),
            if (!state.submitted)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: state.mood
                    ? _MoodDiscoverySection(
                        onSelectPrompt: (prompt) =>
                            _quickSearch(prompt, mood: true),
                      )
                    : _TrackDiscoverySection(
                        signedIn: signedIn,
                        isPremium: isPremium,
                        onOpenMood: () {
                          if (!signedIn) {
                            _showMoodSignInPrompt(context);
                            return;
                          }
                          controller.mode(true);
                        },
                        onSelectGenre: (keyword) => _quickSearch(keyword),
                      ),
              ),
            if (state.failure != null)
              LoadMessage(
                message: state.failure!.message,
                retry: () => controller.submit(),
              ),
            if (isOfflineSearch && offlineMatches.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.offline_pin_rounded,
                      size: 18,
                      color: Color(0xFF4ADE80),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        normalizedQuery.isEmpty
                            ? 'Nhạc đã tải trên máy (${offlineMatches.length})'
                            : 'Kết quả trong nhạc đã tải (${offlineMatches.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < offlineMatches.length; i++)
                TrackTile(
                  track: offlineMatches[i],
                  queue: offlineMatches,
                  index: i,
                  offline: true,
                ),
            ],
            if (state.submitted &&
                !state.loading &&
                state.failure == null &&
                state.tracks.isEmpty)
              LoadMessage(
                message: state.mood
                    ? 'Chưa tìm thấy bài hát phù hợp với cảm xúc này.'
                    : 'Không tìm thấy bài hát phù hợp.',
              ),
            if (state.submitted && state.tracks.isNotEmpty)
              SectionEntrance(
                order: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Text(
                    state.mood ? 'Kết quả theo cảm xúc' : 'Kết quả bài hát',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            if (state.moodResult?.matchStatus == 'LIMITED')
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  'Chưa có bài đạt ngưỡng phù hợp. Đây là các bài gần nhất để bạn tham khảo.',
                ),
              ),
            for (var i = 0; i < state.tracks.length; i++)
              TrackTile(
                track: state.tracks[i],
                queue: state.tracks,
                index: i,
                onSelected: () => ref
                    .read(searchHistoryProvider.notifier)
                    .select(state.query, state.mood, state.tracks[i].id),
              ),
            if (state.hasMore)
              Padding(
                padding: const EdgeInsets.all(20),
                child: OutlinedButton(
                  onPressed: state.loading
                      ? null
                      : () => controller.submit(more: true),
                  child: const Text('Xem thêm kết quả'),
                ),
              ),
            if (state.submitted && state.tracks.isNotEmpty && !isPremium)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: StudioVipAdBanner(
                  title: 'Thưởng thức kết quả tìm kiếm không quảng cáo',
                  subtitle:
                      'Nâng cấp Moodify VIP để nghe liền mạch, chuyển bài không giới hạn và tải nhạc Offline.',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TrackDiscoverySection extends StatelessWidget {
  const _TrackDiscoverySection({
    required this.signedIn,
    required this.isPremium,
    required this.onOpenMood,
    required this.onSelectGenre,
  });

  final bool signedIn;
  final bool isPremium;
  final VoidCallback onOpenMood;
  final ValueChanged<String> onSelectGenre;

  static const _topics = [
    (
      title: 'V-Pop Thịnh Hành',
      subtitle: 'Giai điệu Việt cuốn hút',
      keyword: 'V-Pop',
      badge: 'XU HƯỚNG',
      asset: MoodifyWebAssets.tunedMomentBanner,
    ),
    (
      title: 'Lo-Fi & Tập Trung',
      subtitle: 'Nhạc nền học tập & làm việc',
      keyword: 'Lo-Fi',
      badge: 'FOCUS FLOW',
      asset: MoodifyWebAssets.coverFocusFlow,
    ),
    (
      title: 'Đêm Mưa Ballad',
      subtitle: 'Sâu lắng, trữ tình & tự sự',
      keyword: 'Ballad',
      badge: 'CHILL NIGHT',
      asset: MoodifyWebAssets.coverSaigonRain,
    ),
    (
      title: 'Indie & Acoustic',
      subtitle: 'Mộc mạc, gần gũi & tự do',
      keyword: 'Indie',
      badge: 'ACOUSTIC',
      asset: MoodifyWebAssets.coverEchoesSoul,
    ),
    (
      title: 'Remix & EDM',
      subtitle: 'Sôi động, bùng nổ năng lượng',
      keyword: 'EDM',
      badge: 'NEON PULSE',
      asset: MoodifyWebAssets.coverNeonPulse,
    ),
    (
      title: 'Hip-Hop & Rap',
      subtitle: 'Cá tính, nhịp điệu hiện đại',
      keyword: 'Rap',
      badge: 'MIRAGE BEAT',
      asset: MoodifyWebAssets.coverMidnightMirage,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudioBannerShowcase(
          slides: [
            StudioBannerSlide(
              eyebrow: 'MOODIFY ORIGINALS',
              title: 'Tìm giai điệu theo đúng tâm trạng',
              subtitle:
                  'Chia sẻ cảm xúc của bạn để hệ thống chọn lọc những bản nhạc đồng điệu nhất.',
              ctaLabel: signedIn ? 'Mở tìm theo cảm xúc' : 'Đăng nhập để mở',
              imageAsset: MoodifyWebAssets.moodBanner,
              onTap: onOpenMood,
            ),
            StudioBannerSlide(
              eyebrow: 'TRẢI NGHIỆM STUDIO',
              title: 'Không gian âm nhạc chuẩn phòng thu',
              subtitle:
                  'Đắm chìm trong chất âm sắc nét, lời bài hát đồng bộ và bộ sưu tập chọn lọc.',
              ctaLabel: 'Nghe V-Pop nổi bật',
              imageAsset: MoodifyWebAssets.audioExperienceBanner,
              onTap: () => onSelectGenre('V-Pop'),
            ),
            StudioBannerSlide(
              eyebrow: 'KHÁM PHÁ MỖI NGÀY',
              title: 'Bắt nhịp xu hướng âm nhạc mới',
              subtitle:
                  'Từ Ballad sâu lắng, Indie mộc mạc đến những bản Remix tràn đầy năng lượng.',
              ctaLabel: 'Khám phá Indie',
              imageAsset: MoodifyWebAssets.tunedMomentBanner,
              onTap: () => onSelectGenre('Indie'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              width: 3.5,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Khám phá theo chủ đề',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final twoColumns = constraints.maxWidth >= 300 && scale <= 1.35;
            final cardWidth = twoColumns
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final topic in _topics)
                  SizedBox(
                    width: cardWidth,
                    child: StudioCoverTopicCard(
                      title: topic.title,
                      subtitle: topic.subtitle,
                      badge: topic.badge,
                      imageAsset: topic.asset,
                      onTap: () => onSelectGenre(topic.keyword),
                    ),
                  ),
              ],
            );
          },
        ),
        if (!isPremium) ...[
          const SizedBox(height: 22),
          const StudioVipAdBanner(),
        ],
      ],
    );
  }
}

class _MoodDiscoverySection extends StatelessWidget {
  const _MoodDiscoverySection({required this.onSelectPrompt});
  final ValueChanged<String> onSelectPrompt;

  static const _prompts = [
    (
      title: 'Đêm mưa lắng đọng',
      subtitle: 'Nhẹ nhàng, sâu lắng bên khung cửa sổ',
      prompt: 'Đêm mưa nhẹ nhàng sâu lắng nhiều tâm sự',
      asset: MoodifyWebAssets.coverSaigonRain,
    ),
    (
      title: 'Tập trung làm việc',
      subtitle: 'Giai điệu êm dịu giúp giữ nhịp suy nghĩ',
      prompt: 'Tập trung học tập và làm việc yên tĩnh',
      asset: MoodifyWebAssets.coverFocusFlow,
    ),
    (
      title: 'Năng lượng bùng nổ',
      subtitle: 'Sôi động, hứng khởi cho ngày mới',
      prompt: 'Tràn đầy năng lượng sôi động và hứng khởi',
      asset: MoodifyWebAssets.coverNeonPulse,
    ),
    (
      title: 'Chữa lành tâm hồn',
      subtitle: 'Bình yên, ấm áp sau ngày dài',
      prompt: 'Thư giãn bình yên ấm áp chữa lành tâm hồn',
      asset: MoodifyWebAssets.coverEchoesSoul,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StudioHeroBanner(
          imageAsset: MoodifyWebAssets.moodBanner,
          eyebrow: 'AI MOOD ENGINE',
          eyebrowIcon: Icons.auto_awesome_rounded,
          title: 'Giai điệu đồng điệu cảm xúc',
          subtitle:
              'Mô tả tâm trạng, khung cảnh hoặc câu chuyện của bạn để Moodify chọn lọc những bản nhạc chạm đúng tâm tư.',
          tags: [
            'Phân tích ngữ cảnh',
            'Độ tương thích cảm xúc',
            'Gợi ý cá nhân hóa',
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Gợi ý tâm trạng mẫu',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final twoColumns = constraints.maxWidth >= 300 && scale <= 1.35;
            final cardWidth = twoColumns
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in _prompts)
                  SizedBox(
                    width: cardWidth,
                    child: StudioCoverTopicCard(
                      title: item.title,
                      subtitle: item.subtitle,
                      badge: 'CHẠM ĐỂ TÌM',
                      imageAsset: item.asset,
                      onTap: () => onSelectPrompt(item.prompt),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Nhãn đánh dấu kết quả được phân tích bởi AI Mood Engine.
class _MoodVipTag extends StatelessWidget {
  const _MoodVipTag();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF1E2433),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0x38FFFFFF)),
    ),
    child: const Text(
      'AI Cảm xúc',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}
