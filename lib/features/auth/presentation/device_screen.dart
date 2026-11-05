import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_failure.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../player/presentation/player_screen.dart';
import '../data/device_repository.dart';
import 'session_controller.dart';

class DeviceScreen extends ConsumerStatefulWidget {
  const DeviceScreen({super.key});
  @override
  ConsumerState<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends ConsumerState<DeviceScreen> {
  bool busy = false;
  AppFailure? failure;
  Future<void> revoke(String? id, {bool current = false}) async {
    final user = ref.read(sessionControllerProvider).session?.user.id;
    final repository = ref.read(deviceRepositoryProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          current
              ? 'Đăng xuất thiết bị này?'
              : id == null
              ? 'Thu hồi các thiết bị khác?'
              : 'Thu hồi thiết bị này?',
        ),
        content: const Text(
          'Thiết bị bị thu hồi sẽ phải đăng nhập lại để sử dụng tài khoản.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        ref.read(sessionControllerProvider).session?.user.id != user) {
      return;
    }
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await repository.revoke(id);
      if (!mounted ||
          ref.read(sessionControllerProvider).session?.user.id != user) {
        return;
      }
      if (current) {
        await ref.read(sessionControllerProvider.notifier).logout();
      } else {
        ref.invalidate(deviceListProvider);
      }
    } catch (error) {
      if (mounted &&
          ref.read(sessionControllerProvider).session?.user.id == user) {
        setState(() => failure = AppFailure.from(error));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionControllerProvider).session == null) {
      return const GuestPrompt(
        title: 'Thiết bị đăng nhập',
        message: 'Đăng nhập để quản lý thiết bị.',
        returnTo: '/devices',
      );
    }
    final data = ref.watch(deviceListProvider);
    return Scaffold(
      bottomNavigationBar: const MiniPlayer(),
      appBar: AppBar(
        title: const Text('Thiết bị đăng nhập'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: busy ? null : () => ref.invalidate(deviceListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LoadMessage(
          message: AppFailure.from(e).message,
          retry: () => ref.invalidate(deviceListProvider),
        ),
        data: (list) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('${list.active}/${list.maximum} thiết bị hoạt động'),
            ),
            if (busy) const LinearProgressIndicator(),
            if (failure != null) LoadMessage(message: failure!.message),
            if (list.devices.isEmpty)
              const LoadMessage(message: 'Chưa có thiết bị được ghi nhận.'),
            for (final device in list.devices)
              ListTile(
                leading: const Icon(Icons.devices),
                title: Text(
                  '${device.name}${device.uuid == list.currentUuid ? ' · Máy này' : ''}',
                ),
                subtitle: Text(
                  '${device.platform} · ${device.status == 'ACTIVE' ? 'Hoạt động' : 'Đã thu hồi'}${device.createdAt == null ? '' : '\nĐăng ký ${device.createdAt}'}',
                ),
                trailing: device.status != 'ACTIVE'
                    ? null
                    : IconButton(
                        tooltip: 'Thu hồi thiết bị',
                        onPressed: busy
                            ? null
                            : () => revoke(
                                device.id,
                                current: device.uuid == list.currentUuid,
                              ),
                        icon: const Icon(Icons.logout),
                      ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: OutlinedButton(
                onPressed: busy ? null : () => revoke(null),
                child: const Text('Thu hồi các thiết bị khác'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
