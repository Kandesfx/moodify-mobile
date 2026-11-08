import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_motion.dart';
import '../../../core/widgets/studio_banners.dart';
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
        data: (list) => SectionEntrance(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            MoodifyWebAssets.soundwaveDark,
                            fit: BoxFit.cover,
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
                                  Color(0xD8090A0D),
                                  Color(0xED0C0E14),
                                  Color(0xF611131A),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceGlass,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.borderSoft,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.devices_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${list.active}/${list.maximum} thiết bị hoạt động',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Quản lý các phiên đang được cấp quyền',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.secondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: list.maximum > 0
                                      ? (list.active / list.maximum).clamp(
                                          0.0,
                                          1.0,
                                        )
                                      : 0.0,
                                  minHeight: 5,
                                  color: Colors.white,
                                  backgroundColor: const Color(0x22FFFFFF),
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
              if (busy) const LinearProgressIndicator(),
              if (failure != null) LoadMessage(message: failure!.message),
              if (list.devices.isEmpty)
                const LoadMessage(message: 'Chưa có thiết bị được ghi nhận.'),
              for (final device in list.devices)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: device.uuid == list.currentUuid
                          ? const Color(0xFF1A1E27)
                          : const Color(0xFF12141A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: device.uuid == list.currentUuid
                            ? const Color(0x38FFFFFF)
                            : const Color(0x10FFFFFF),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGlass,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: const Icon(
                          Icons.smartphone_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        '${device.name}${device.uuid == list.currentUuid ? ' · Máy này' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '${device.platform} · ${device.status == 'ACTIVE' ? 'Hoạt động' : 'Đã thu hồi'}${device.createdAt == null ? '' : '\nĐăng ký ${device.createdAt}'}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.secondary,
                            height: 1.4,
                          ),
                        ),
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
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: AppColors.secondary,
                              ),
                            ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: OutlinedButton(
                  onPressed: busy ? null : () => revoke(null),
                  style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                  child: const Text('Thu hồi các thiết bị khác'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
