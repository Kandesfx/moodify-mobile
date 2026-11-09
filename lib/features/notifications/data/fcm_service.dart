import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_repository.dart';

/// Top-level background message handler for FCM.
/// Must be annotated with `@pragma('vm:entry-point')` so Flutter's AOT compiler
/// does not tree-shake it when the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If the app is killed or backgrounded, Firebase automatically displays
  // notification messages on Android if message.notification is present.
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService();
  return service;
});

class FcmService {
  FcmService();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  static bool get _isWidgetTest {
    try {
      return const bool.fromEnvironment('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Khởi tạo Firebase Cloud Messaging an toàn.
  /// Nếu chưa có file `google-services.json` hoặc chạy trong môi trường test/unsupported,
  /// hàm sẽ bắt ngoại lệ và bỏ qua một cách êm ái, không làm crash ứng dụng.
  Future<void> initialize({
    NotificationAlertService? alertService,
    void Function(InboxItem item)? onNewAlert,
    void Function(String? destination)? onOpenDestination,
    void Function({String? id, String? title, String? message})? onMarkSeen,
  }) async {
    if (_isWidgetTest || kIsWeb) return;
    if (_initialized) return;

    try {
      // Khởi tạo Firebase Core nếu chưa được khởi tạo
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      // Đăng ký Background Message Handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // Xin quyền thông báo FCM trên Android 13+ & iOS
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Khi app đang ở tiền cảnh (Foreground), Flutter xử lý qua NotificationToastOverlay
      // và NotificationAlertService; tắt alert/sound mặc định của Firebase SDK
      // để tránh hệ thống đẩy thêm một thông báo nữa gây hiện tượng nhân đôi.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      // Tự động đăng ký chủ đề nhận thông báo chung cho toàn bộ thiết bị
      try {
        await messaging.subscribeToTopic('all_users');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Subscribe topic all_users error: $e');
        }
      }

      // Lấy FCM Device Token để gửi lên server hoặc ghi nhận thiết bị
      _fcmToken = await messaging.getToken();
      if (kDebugMode) {
        debugPrint('Moodify FCM Token: $_fcmToken');
      }

      // Lắng nghe khi token thay đổi
      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        if (kDebugMode) {
          debugPrint('Moodify FCM Token refreshed: $newToken');
        }
      });

      // Lắng nghe thông báo khi ứng dụng đang mở ở tiền cảnh (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final data = message.data;
        final title = notification?.title ?? data['title'] ?? 'Moodify';
        final body = notification?.body ?? data['message'] ?? '';
        final id =
            message.messageId ??
            data['id'] ??
            'fcm_${DateTime.now().millisecondsSinceEpoch}';
        final link = data['linkUrl'] ?? data['link'];

        final item = InboxItem(
          id: id,
          title: title,
          message: body,
          read: false,
          createdAt: DateTime.now().toIso8601String(),
          link: link,
        );

        onMarkSeen?.call(id: id, title: title, message: body);
        onNewAlert?.call(item);
        alertService?.alertNewNotification(item);
      });

      // Lắng nghe khi người dùng bấm vào thông báo từ thanh trạng thái
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final data = message.data;
        final notification = message.notification;
        final id = message.messageId ?? data['id'];
        final title = notification?.title ?? data['title'];
        final body = notification?.body ?? data['message'];
        onMarkSeen?.call(id: id, title: title, message: body);
        final link = data['linkUrl'] ?? data['link'];
        onOpenDestination?.call(link);
      });

      // Kiểm tra xem ứng dụng có được mở từ việc chạm vào thông báo lúc app bị tắt không
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        final data = initialMessage.data;
        final notification = initialMessage.notification;
        final id = initialMessage.messageId ?? data['id'];
        final title = notification?.title ?? data['title'];
        final body = notification?.body ?? data['message'];
        onMarkSeen?.call(id: id, title: title, message: body);
        final link = data['linkUrl'] ?? data['link'];
        onOpenDestination?.call(link);
      }

      _initialized = true;
    } catch (e) {
      // Firebase chưa cấu hình google-services.json hoặc không khả dụng:
      // Tiếp tục hoạt động bằng Local Notification Polling bình thường.
      if (kDebugMode) {
        debugPrint('FCM init skipped or failed (safe fallback): $e');
      }
    }
  }
}
