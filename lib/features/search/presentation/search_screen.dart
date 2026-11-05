import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_motion.dart';

import '../../catalog/presentation/catalog_widgets.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final controller = ref.read(searchControllerProvider.notifier);
    final signedIn = ref.watch(
      sessionControllerProvider.select((s) => s.session != null),
    );
    final history = ref.watch(searchHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
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
                                duration: AppMotion.duration(context, 180),
                                decoration: BoxDecoration(
                                  color: state.mood == mode
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: Pressable(
                                    onTap: () => controller.mode(mode),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 13,
                                        horizontal: 8,
                                      ),
                                      child: Text(
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
          if (state.loading) const LinearProgressIndicator(),
          if (state.submitted && history.hasError)
            const LoadMessage(
              message:
                  'Kết quả tìm kiếm vẫn dùng được. Chưa lưu hoặc đồng bộ được lịch sử tìm kiếm.',
            ),
          if (state.moodResult?.emotion != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('Cảm xúc nhận diện: ${state.moodResult!.emotion}'),
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
            if (state.failure != null)
              LoadMessage(
                message: state.failure!.message,
                retry: () => controller.submit(),
              ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  state.mood ? 'Kết quả theo cảm xúc' : 'Kết quả bài hát',
                  style: Theme.of(context).textTheme.titleMedium,
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
          ],
        ],
      ),
    );
  }
}
