import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/subscriptions/data/subscription_repository.dart';
import 'package:moodify_flutter/features/subscriptions/presentation/subscription_controller.dart';
import 'package:moodify_flutter/features/subscriptions/domain/subscription_models.dart';

class _Repository extends SubscriptionRepository {
  _Repository() : super(Dio());
  int checkouts = 0, checks = 0, loads = 0;
  String paymentStatus = 'PENDING';
  Completer<void>? pending;
  bool failCheckout = false;
  List<ManagedSubscription> managed = [];
  @override
  Future<SubscriptionInfo> current() async {
    loads++;
    return SubscriptionInfo.fromJson({
      'packageName': 'Test plan',
      'isPremium': paymentStatus == 'SUCCESS',
    });
  }

  @override
  Future<List<PackageQuote>> quotes() async => [];
  @override
  Future<List<ManagedSubscription>> management() async => managed;
  @override
  Future<PaymentOrder> checkout(String id) async {
    checkouts++;
    if (failCheckout) throw TimeoutException('Test connection lost');
    await pending?.future;
    return PaymentOrder.fromJson({
      'success': true,
      'orderCode': 'test-order',
      'packageName': 'Test plan',
      'amount': 10000,
      'qrUrl': 'https://qr.example.test/image',
      'bankAccount': 'test-account',
      'bankName': 'Test bank',
      'accountName': 'Test recipient',
      'transferContent': 'test-only',
    });
  }

  @override
  Future<Map<String, dynamic>> status(String code) async {
    checks++;
    await pending?.future;
    return {'orderCode': code, 'amount': 10000, 'status': paymentStatus};
  }
}

void main() {
  late _Repository repository;
  late SubscriptionController controller;
  setUp(() {
    repository = _Repository();
    controller = SubscriptionController(repository, true);
    controller.active(false);
  });
  tearDown(() {
    controller.dispose();
    repository.dio.close();
  });
  test(
    'double taps create one pending order and never activate premium',
    () async {
      repository.pending = Completer<void>();
      final first = controller.checkout('1');
      await controller.checkout('1');
      expect(repository.checkouts, 1);
      expect(controller.state.order, isNull);
      repository.pending!.complete();
      await first;
      expect(controller.state.status, 'PENDING');
      expect(controller.state.current, isNull);
      await controller.checkout('1');
      expect(repository.checkouts, 1);
    },
  );
  test(
    'only server success refreshes entitlements and stops further payment checks',
    () async {
      await controller.checkout('1');
      await controller.check();
      expect(controller.state.status, 'PENDING');
      expect(repository.loads, 0);
      repository.paymentStatus = 'SUCCESS';
      await controller.check();
      expect(controller.state.current!.premium, true);
      final count = repository.checks;
      await controller.check();
      expect(repository.checks, count);
    },
  );
  test(
    'a late status response cannot resurrect a dismissed checkout',
    () async {
      await controller.checkout('1');
      repository.pending = Completer<void>();
      final pending = controller.check();
      controller.closeCheckout();
      repository.paymentStatus = 'SUCCESS';
      repository.pending!.complete();
      await pending;
      expect(controller.state.order, isNull);
      expect(controller.state.status, '');
      expect(controller.state.checking, false);
    },
  );
  test(
    'invalid financial numbers are rejected rather than rendered as zero',
    () {
      expect(() => paymentAmount('unknown'), throwsFormatException);
      expect(() => paymentAmount(double.nan), throwsFormatException);
      expect(() => paymentAmount(-1), throwsFormatException);
    },
  );
  test(
    'ambiguous checkout requires a successful history read before another attempt',
    () async {
      repository.failCheckout = true;
      await controller.checkout('1');
      expect(controller.state.needsReview, true);
      await controller.checkout('1');
      expect(repository.checkouts, 1);
      repository.managed = [
        ManagedSubscription.fromJson({
          'id': '1',
          'packageName': 'Test plan',
          'status': 'PENDING',
          'payments': [
            {'orderCode': 'test-order', 'status': 'PENDING', 'amount': 10000},
          ],
        }),
      ];
      await controller.load();
      expect(controller.state.needsReview, false);
      expect(controller.state.hasPendingPayment, true);
      await controller.checkout('1');
      expect(repository.checkouts, 1);
      repository.managed = [];
      await controller.load();
      repository.failCheckout = false;
      await controller.checkout('1');
      expect(repository.checkouts, 2);
    },
  );
}
