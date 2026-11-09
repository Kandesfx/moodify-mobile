import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/notifications/data/notification_repository.dart';
import 'package:moodify_flutter/features/notifications/presentation/notification_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'NotificationToastOverlay animates in when alert is set, shows styled card and can be dismissed via close button',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var opened = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: NotificationToastOverlay(
                onOpenNotifications: () => opened = true,
                child: const Center(child: Text('Main Content')),
              ),
            ),
          ),
        ),
      );

      // Ban đầu không có thông báo -> chỉ hiển thị nội dung chính
      expect(find.text('Main Content'), findsOneWidget);
      expect(find.text('Nâng cấp gói thành công'), findsNothing);

      // Phát một thông báo VIP/BILLING mới
      final testAlert = InboxItem(
        id: 'notif-vip-1',
        title: 'Nâng cấp gói thành công',
        message: 'Chào mừng bạn đến với Moodify VIP.',
        read: false,
        createdAt: '2026-11-10T00:00:00',
        type: 'BILLING',
      );
      container.read(latestNotificationAlertProvider.notifier).state =
          testAlert;

      // Pump animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Đã hiển thị tiêu đề, nội dung và badge loại gói dịch vụ
      expect(find.text('Nâng cấp gói thành công'), findsOneWidget);
      expect(find.text('Chào mừng bạn đến với Moodify VIP.'), findsOneWidget);
      expect(find.text('GÓI DỊCH VỤ'), findsOneWidget);
      expect(find.text('· MOODIFY'), findsOneWidget);

      // Bấm nút Đóng thông báo
      final closeButton = find.byTooltip('Đóng thông báo');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);

      // Animation trượt ra
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Provider đã được reset về null và thông báo đã biến mất
      expect(container.read(latestNotificationAlertProvider), isNull);
      expect(find.text('Nâng cấp gói thành công'), findsNothing);
      expect(opened, isFalse);
    },
  );

  testWidgets(
    'NotificationToastOverlay dismisses on vertical swipe up gesture',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationToastOverlay(
                child: Center(child: Text('App View')),
              ),
            ),
          ),
        ),
      );

      final systemAlert = InboxItem(
        id: 'notif-sys-2',
        title: 'Bảo trì hệ thống định kỳ',
        message: 'Hệ thống hoạt động bình thường.',
        read: false,
        createdAt: '2026-11-10T00:01:00',
        type: 'SYSTEM',
      );
      container.read(latestNotificationAlertProvider.notifier).state =
          systemAlert;

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Bảo trì hệ thống định kỳ'), findsOneWidget);

      // Thực hiện thao tác vuốt lên trên thẻ thông báo
      await tester.drag(
        find.text('Bảo trì hệ thống định kỳ'),
        const Offset(0, -100),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Thông báo đã được đóng bởi cử chỉ vuốt lên
      expect(container.read(latestNotificationAlertProvider), isNull);
      expect(find.text('Bảo trì hệ thống định kỳ'), findsNothing);
    },
  );

  testWidgets(
    'Tapping on toast card opens notifications and dismisses banner',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var opened = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: NotificationToastOverlay(
                onOpenNotifications: () => opened = true,
                child: const Center(child: Text('Home View')),
              ),
            ),
          ),
        ),
      );

      final promoAlert = InboxItem(
        id: 'notif-promo-3',
        title: 'Ưu đãi đặc quyền cuối tuần',
        message: 'Nhận ngay tháng đầu ưu đãi.',
        read: false,
        createdAt: '2026-11-10T00:02:00',
        type: 'PROMO',
      );
      container.read(latestNotificationAlertProvider.notifier).state =
          promoAlert;

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Ưu đãi đặc quyền cuối tuần'), findsOneWidget);
      expect(find.text('ƯU ĐÃI'), findsOneWidget);

      // Chạm vào thẻ thông báo
      await tester.tap(find.text('Ưu đãi đặc quyền cuối tuần'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(opened, isTrue);
      expect(container.read(latestNotificationAlertProvider), isNull);
    },
  );
}
