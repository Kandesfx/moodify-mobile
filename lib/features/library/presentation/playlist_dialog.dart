import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/feedback_panel.dart';
import '../../catalog/domain/catalog_models.dart';
import 'library_controller.dart';

Future<MusicCollection?> showCreatePlaylist(BuildContext context) =>
    showDialog<MusicCollection>(
      context: context,
      builder: (_) => const _CreatePlaylist(),
    );

class _CreatePlaylist extends ConsumerStatefulWidget {
  const _CreatePlaylist();
  @override
  ConsumerState<_CreatePlaylist> createState() => _CreatePlaylistState();
}

class _CreatePlaylistState extends ConsumerState<_CreatePlaylist> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryControllerProvider);
    return AlertDialog(
      title: const Text('Tạo playlist'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Tên playlist'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nhập tên playlist.'
                    : null,
              ),
              const SizedBox(height: 12),
              const Text('Playlist mới chỉ hiển thị với bạn.'),
              if (state.failure != null)
                FeedbackPanel(message: state.failure!.message),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: state.busy
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  final success = await ref
                      .read(libraryControllerProvider.notifier)
                      .create(_name.text);
                  if (context.mounted && success) {
                    Navigator.pop(
                      context,
                      ref
                          .read(libraryControllerProvider.notifier)
                          .createdPlaylist,
                    );
                  }
                },
          child: Text(state.busy ? 'Đang tạo…' : 'Tạo playlist'),
        ),
      ],
    );
  }
}
