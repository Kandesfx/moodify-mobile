import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bootstrap.dart';
import '../../catalog/domain/catalog_models.dart';
import '../domain/subscription_models.dart';

final subscriptionRepositoryProvider = Provider(
  (ref) => SubscriptionRepository(ref.watch(apiDioProvider)),
);

class SubscriptionRepository {
  SubscriptionRepository(this.dio);
  final Dio dio;
  Future<Map<String, dynamic>> get(String path) async =>
      objectJson((await dio.get<Object?>(path)).data);
  Future<List<Map<String, dynamic>>> list(String path) async {
    final json = (await dio.get<Object?>(path)).data;
    if (json is! List) throw const FormatException('Invalid subscriptions');
    return json.map(objectJson).toList();
  }

  Future<SubscriptionInfo> current() async =>
      SubscriptionInfo.fromJson(await get('subscriptions/me'));
  Future<List<PackageQuote>> quotes() async => (await list(
    'subscriptions/package-quotes',
  )).map(PackageQuote.fromJson).toList();
  Future<List<ManagedSubscription>> management() async => (await list(
    'subscriptions/me/management',
  )).map(ManagedSubscription.fromJson).toList();
  Future<PaymentOrder> checkout(String id) async => PaymentOrder.fromJson(
    objectJson(
      (await dio.post<Object?>(
        'subscriptions/checkout',
        data: {'packageId': id},
      )).data,
    ),
  );
  Future<Map<String, dynamic>> status(String code) =>
      get('subscriptions/payment-status/${segment(code)}');
  Future<void> cancel(String id) async =>
      dio.post<Object?>('subscriptions/me/${segment(id)}/cancel');
}
