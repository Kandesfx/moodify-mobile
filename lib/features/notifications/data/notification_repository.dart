import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../app/bootstrap.dart';
import '../../catalog/domain/catalog_models.dart';

const moodifyNotificationChimeAsset =
    'assets/audio/moodify_notification_chime.mp3';

final notificationRepositoryProvider = Provider(
  (ref) => NotificationRepository(ref.watch(apiDioProvider)),
);

final notificationAlertServiceProvider = Provider<NotificationAlertService>((
  ref,
) {
  final service = NotificationAlertService();
  ref.onDispose(service.dispose);
  return service;
});

class InboxItem {
  InboxItem({
    required this.id,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
    this.type = 'SYSTEM',
    this.link,
  });

  InboxItem.fromJson(Map<String, dynamic> json)
    : id = requiredText(json, 'id'),
      title = requiredText(json, 'title'),
      message = optionalText(json['message']) ?? '',
      type = (optionalText(json['type']) ?? 'SYSTEM').toUpperCase(),
      read = optionalText(json['readAt']) != null,
      link = optionalText(json['linkUrl']),
      createdAt = optionalText(json['createdAt']) ?? '';

  final String id, title, message, type, createdAt;
  final bool read;
  final String? link;

  String get typeLabel => switch (type) {
    'BILLING' => 'GÓI DỊCH VỤ',
    'PROMO' => 'ƯU ĐÃI',
    'ANNOUNCEMENT' => 'CÔNG BỐ',
    'MODERATION' => 'KIỂM DUYỆT',
    _ => 'HỆ THỐNG',
  };

  String? get destination {
    final uri = Uri.tryParse(link ?? '');
    if (uri == null || uri.hasScheme || uri.hasAuthority || uri.hasFragment) {
      return null;
    }
    return uri.path == '/dashboard/premium' ? '/subscriptions' : null;
  }
}

class NotificationRepository {
  NotificationRepository(this.dio);
  final Dio dio;
  Future<List<InboxItem>> load() async {
    final json = objectJson(
      (await dio.get<Object?>(
        'notifications/me',
        queryParameters: {'limit': 50},
      )).data,
    );
    if (json['items'] is! List) throw const FormatException('Invalid inbox');
    return (json['items'] as List)
        .map((e) => InboxItem.fromJson(objectJson(e)))
        .toList();
  }

  Future<void> read(String? id) async => dio.post<Object?>(
    id == null ? 'notifications/read-all' : 'notifications/${segment(id)}/read',
  );
}

/// Dịch vụ phát chuông thông báo nhận diện thương hiệu "Moodify" (đã lọc bỏ
/// câu thoại phía sau) và hiển thị thông báo hệ thống Android/iOS.
class NotificationAlertService {
  NotificationAlertService({
    MethodChannel? channel,
    Future<void> Function()? customChimePlayer,
  }) : _channel =
           channel ??
           const MethodChannel('dev.moodify.moodify_flutter/notifications'),
       _customChimePlayer = customChimePlayer;

  final MethodChannel _channel;
  final Future<void> Function()? _customChimePlayer;
  AudioPlayer? _chimePlayer;

  bool get _isWidgetTest {
    try {
      return const bool.fromEnvironment('FLUTTER_TEST') ||
          _bindingName.contains('Test');
    } catch (_) {
      return false;
    }
  }

  String get _bindingName {
    try {
      return ServicesBinding.instance.runtimeType.toString();
    } catch (_) {
      return '';
    }
  }

  Future<bool> ensurePermission() async {
    if (_isWidgetTest) return false;
    try {
      final granted = await _channel.invokeMethod<bool>('ensurePermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> showSystemNotification({
    required String id,
    required String title,
    required String message,
    bool silent = true,
  }) async {
    try {
      final shown = await _channel.invokeMethod<bool>('showNotification', {
        'id': id,
        'title': title,
        'message': message,
        'silent': silent,
      });
      return shown ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Phát âm thanh nhận diện thương hiệu "Moodify" (chỉ phần chữ Moodify đầu).
  /// Không chiếm quyền AudioSession của trình phát nhạc chính.
  Future<void> playBrandChime() async {
    if (_customChimePlayer != null) {
      await _customChimePlayer();
      return;
    }
    if (_isWidgetTest) return;
    try {
      final player = _chimePlayer ??= AudioPlayer(
        handleInterruptions: false,
        handleAudioSessionActivation: false,
      );
      await player.stop();
      await player.setAsset(moodifyNotificationChimeAsset);
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {
      // Bỏ qua nếu thiết bị không có đầu ra âm thanh khả dụng.
    }
  }

  /// Thông báo khi có thông báo mới từ hệ thống: đẩy lên thanh trạng thái OS
  /// kèm tiếng "Moodify" nhận diện thương hiệu.
  Future<void> alertNewNotification(InboxItem item) async {
    await showSystemNotification(
      id: item.id,
      title: item.title,
      message: item.message,
    );
    await playBrandChime();
  }

  Future<void> dispose() async {
    final player = _chimePlayer;
    _chimePlayer = null;
    if (player != null) {
      try {
        await player.dispose();
      } catch (_) {}
    }
  }
}
