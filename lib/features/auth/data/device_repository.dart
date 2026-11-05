import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bootstrap.dart';
import '../../../core/errors/app_failure.dart';
import '../../catalog/domain/catalog_models.dart';
import '../presentation/session_controller.dart';
import 'device_identity.dart';

class DeviceSummary {
  DeviceSummary.fromJson(Map<String, dynamic> json)
    : id = requiredText(json, 'id'),
      uuid = requiredText(json, 'deviceUuid'),
      name = optionalText(json['deviceName']) ?? 'Thiết bị',
      platform = optionalText(json['platform']) ?? '',
      status = requiredText(json, 'status'),
      createdAt = optionalText(json['createdAt']);
  final String id, uuid, name, platform, status;
  final String? createdAt;
}

class DeviceList {
  DeviceList.fromJson(Map<String, dynamic> json, this.currentUuid)
    : devices = (json['devices'] as List)
          .map((e) => DeviceSummary.fromJson(objectJson(e)))
          .toList(),
      active = (json['activeCount'] as num).toInt(),
      maximum = (json['maxDevices'] as num).toInt();
  final List<DeviceSummary> devices;
  final String currentUuid;
  final int active, maximum;
}

class DeviceRepository {
  DeviceRepository(this.dio, this.identity);
  final Dio dio;
  final DeviceIdentityStore identity;
  Future<DeviceList> load() async => DeviceList.fromJson(
    objectJson((await dio.get<Object?>('auth/devices')).data),
    (await identity.load()).uuid,
  );
  Future<void> revoke(String? id) async {
    if (id == null) {
      await dio.post<Object?>(
        'auth/devices/revoke-others',
        data: {'deviceUuid': (await identity.load()).uuid},
      );
    } else {
      final json = objectJson(
        (await dio.patch<Object?>('auth/devices/${segment(id)}/revoke')).data,
      );
      if (json['success'] != true) {
        throw const AppFailure(
          'Thiết bị chưa được thu hồi. Hãy tải lại danh sách để kiểm tra.',
        );
      }
    }
  }
}

final deviceRepositoryProvider = Provider(
  (ref) => DeviceRepository(
    ref.watch(apiDioProvider),
    ref.watch(deviceIdentityProvider),
  ),
);
final deviceListProvider = FutureProvider.autoDispose<DeviceList>((ref) {
  final user = ref.watch(
    sessionControllerProvider.select((s) => s.session?.user.id),
  );
  if (user == null) throw const AppFailure('Đăng nhập để xem thiết bị.');
  return ref.watch(deviceRepositoryProvider).load();
});
