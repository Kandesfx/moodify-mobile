import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bootstrap.dart';
import '../../auth/data/device_identity.dart';
import '../../auth/presentation/session_controller.dart';
import '../../catalog/domain/catalog_models.dart';

class OfflineAccess {
  const OfflineAccess({
    required this.packageName,
    required this.allowed,
    required this.used,
    required this.maximum,
    required this.checkedAt,
    this.expiresAt,
  });
  final String packageName;
  final bool allowed;
  final int used, maximum;
  final DateTime checkedAt;
  final String? expiresAt;
  bool get full => used >= maximum;
}

class OfflineAccessRepository {
  OfflineAccessRepository(this.api, this.devices);
  final Dio api;
  final DeviceIdentityStore devices;
  Future<OfflineAccess> load() async {
    final device = await devices.load();
    final responses = await Future.wait([
      api.get<Object?>('subscriptions/me'),
      api.get<Object?>(
        'offline/my-downloads',
        queryParameters: {'deviceUuid': device.uuid},
      ),
    ]);
    final subscription = objectJson(responses[0].data);
    final downloads = objectJson(responses[1].data);
    final entitlement = objectJson(subscription['entitlements']);
    final quota = objectJson(downloads['quota']);
    final max = quota['max'], used = quota['used'];
    if (max is! num ||
        used is! num ||
        max < 0 ||
        used < 0 ||
        max != max.toInt() ||
        used != used.toInt() ||
        entitlement['offlineAllowed'] is! bool ||
        subscription['isPremium'] is! bool ||
        downloads['isPremium'] is! bool) {
      throw const FormatException('Invalid offline access');
    }
    return OfflineAccess(
      packageName: requiredText(subscription, 'packageName'),
      allowed:
          subscription['isPremium'] == true &&
          downloads['isPremium'] == true &&
          entitlement['offlineAllowed'] == true &&
          max > 0,
      used: used.toInt(),
      maximum: max.toInt(),
      expiresAt: optionalText(subscription['expiresAt']),
      checkedAt: DateTime.now(),
    );
  }
}

final offlineAccessRepositoryProvider = Provider(
  (ref) => OfflineAccessRepository(
    ref.watch(apiDioProvider),
    ref.watch(deviceIdentityProvider),
  ),
);
final offlineAccessProvider = FutureProvider<OfflineAccess?>((ref) async {
  if (ref.watch(sessionControllerProvider.select((s) => s.session?.user.id)) ==
      null) {
    return null;
  }
  return ref.watch(offlineAccessRepositoryProvider).load();
});
