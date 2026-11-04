import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/presentation/catalog_widgets.dart';
import 'search_controller.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchControllerProvider);
    final controller = ref.read(searchControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Bài hát'),
                      icon: Icon(Icons.search_rounded),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Cảm xúc'),
                      icon: Icon(Icons.mood_rounded),
                    ),
                  ],
                  selected: {state.mood},
                  onSelectionChanged: (s) => controller.mode(s.single),
                ),
                const SizedBox(height: 20),
                TextField(
                  onChanged: controller.change,
                  onSubmitted: (_) => controller.submit(),
                  textInputAction: TextInputAction.search,
                  maxLength: state.mood ? 500 : 100,
                  decoration: InputDecoration(
                    labelText: state.mood
                        ? 'Bạn đang cảm thấy thế nào?'
                        : 'Tên bài hát hoặc nghệ sĩ',
                    prefixIcon: const Icon(Icons.search_rounded),
                    counterText: '',
                    suffixIcon: IconButton(
                      tooltip: 'Tìm kiếm',
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        controller.submit();
                      },
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                if (!state.submitted)
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
                for (var i = 0; i < state.tracks.length; i++)
                  TrackTile(
                    track: state.tracks[i],
                    queue: state.tracks,
                    index: i,
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
            ),
          ),
        ],
      ),
    );
  }
}
