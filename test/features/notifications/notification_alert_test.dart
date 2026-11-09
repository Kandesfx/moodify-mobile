import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/notifications/data/notification_repository.dart';
import 'package:moodify_flutter/features/notifications/presentation/notification_screen.dart';

import '../../support/auth_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'new system notification triggers OS notification and Moodify brand chime once per unseen unread item',
    () async {
      final channelCalls = <MethodCall>[];
      const channel = MethodChannel('dev.moodify.moodify_flutter/test_notif');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            channelCalls.add(call);
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      var chimeCount = 0;
      final alertService = NotificationAlertService(
        channel: channel,
        customChimePlayer: () async {
          chimeCount++;
        },
      );

      var serverItems = <Map<String, dynamic>>[
        {
          'id': 'notif-1',
          'title': 'Nâng cấp gói thành công',
          'message': 'Chào mừng bạn đến với Moodify VIP.',
          'type': 'BILLING',
          'readAt': null,
          'createdAt': '2026-11-08T20:30:00',
        },
      ];

      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/'));
      dio.httpClientAdapter = TestAdapter((options) {
        return jsonResponse({'items': serverItems});
      });
      addTearDown(dio.close);

      final store = MemoryStore();
      final emittedAlerts = <InboxItem>[];
      final controller = InboxController(
        NotificationRepository(dio),
        true,
        userId: 'user-1',
        store: store,
        alertService: alertService,
        onNewAlert: emittedAlerts.add,
      );
      addTearDown(controller.dispose);

      // Lần tải đầu tiên: phát hiện thông báo chưa đọc mới -> phát chuông Moodify + thông báo hệ thống
      await controller.load();
      expect(chimeCount, 1);
      expect(emittedAlerts.length, 1);
      expect(emittedAlerts.single.id, 'notif-1');
      expect(emittedAlerts.single.typeLabel, 'GÓI DỊCH VỤ');
      expect(channelCalls.single.method, 'showNotification');
      expect(
        (channelCalls.single.arguments as Map)['title'],
        'Nâng cấp gói thành công',
      );

      // Lần tải thứ hai với cùng danh sách: không phát lặp lại chuông cho thông báo cũ
      await controller.load();
      expect(chimeCount, 1);
      expect(emittedAlerts.length, 1);

      // Hệ thống đẩy thêm một thông báo mới
      serverItems = [
        {
          'id': 'notif-2',
          'title': 'Thông báo hệ thống mới',
          'message': 'Cập nhật tính năng mới trên Moodify.',
          'type': 'SYSTEM',
          'readAt': null,
          'createdAt': '2026-11-08T20:35:00',
        },
        ...serverItems,
      ];
      await controller.load();
      expect(chimeCount, 2);
      expect(emittedAlerts.last.id, 'notif-2');
      expect(emittedAlerts.last.typeLabel, 'HỆ THỐNG');
    },
  );

  test(
    'markSeen suppresses re-alerting when FCM opened notification or content fingerprint matches',
    () async {
      final channelCalls = <MethodCall>[];
      const channel = MethodChannel('dev.moodify.moodify_flutter/test_notif2');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            channelCalls.add(call);
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      var chimeCount = 0;
      final alertService = NotificationAlertService(
        channel: channel,
        customChimePlayer: () async {
          chimeCount++;
        },
      );

      final serverItems = <Map<String, dynamic>>[
        {
          'id': 'fcm-opened-id',
          'title': 'Ưu đãi đặc biệt',
          'message': 'Giảm 50% gói Premium tháng này.',
          'type': 'PROMO',
          'readAt': null,
          'createdAt': '2026-11-10T01:00:00',
        },
      ];

      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/'));
      dio.httpClientAdapter = TestAdapter((options) {
        return jsonResponse({'items': serverItems});
      });
      addTearDown(dio.close);

      final store = MemoryStore();
      final emittedAlerts = <InboxItem>[];
      final controller = InboxController(
        NotificationRepository(dio),
        true,
        userId: 'user-2',
        store: store,
        alertService: alertService,
        onNewAlert: emittedAlerts.add,
      );
      addTearDown(controller.dispose);

      // Người dùng mở app qua FCM push notification -> markSeen được gọi trước khi load()
      controller.markSeen(
        id: 'fcm-opened-id',
        title: 'Ưu đãi đặc biệt',
        message: 'Giảm 50% gói Premium tháng này.',
      );

      // Khi load() chạy, thông báo đã được nhận diện là seen -> không re-alert
      await controller.load();
      expect(chimeCount, 0);
      expect(emittedAlerts.isEmpty, isTrue);
      expect(channelCalls.isEmpty, isTrue);
    },
  );

  test('trimmed Moodify brand chime asset exists without trailing slogan', () {
    final assetFile = File(moodifyNotificationChimeAsset);
    expect(assetFile.existsSync(), isTrue);
    // File gốc moodify_platform_ident.mp3 dài ~394 KB (9.81s);
    // bản lọc riêng tiếng "Moodify" đầu dài ~66 KB (~2.82s).
    final length = assetFile.lengthSync();
    expect(length, greaterThan(20 * 1024));
    expect(length, lessThan(150 * 1024));
  });
}
