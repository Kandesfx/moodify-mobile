import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/offline/data/offline_access_repository.dart';
import 'package:moodify_flutter/features/auth/data/device_identity.dart';
import '../../support/auth_harness.dart';

void main() {
  test(
    'access uses both server entitlement and device quota, never premium name',
    () async {
      final devices = DeviceIdentityStore(MemoryStore(), platform: 'ANDROID');
      final uuid = (await devices.load()).uuid;
      var allowed = false;
      var failQuota = false;
      var corrupt = false;
      final dio = Dio()
        ..httpClientAdapter = TestAdapter((r) {
          if (r.path == 'subscriptions/me') {
            return jsonResponse({
              'packageName': 'Premium',
              'isPremium': true,
              'entitlements': {'offlineAllowed': allowed},
            });
          }
          expect(r.queryParameters['deviceUuid'], uuid);
          if (failQuota) return jsonResponse({}, status: 503);
          return jsonResponse({
            'isPremium': true,
            'quota': {'used': 3, 'max': corrupt ? -1 : 10},
          });
        });
      final repo = OfflineAccessRepository(dio, devices);
      expect((await repo.load()).allowed, false);
      allowed = true;
      final access = await repo.load();
      expect(access.allowed, true);
      expect(access.used, 3);
      expect(access.maximum, 10);
      expect(access.full, false);
      corrupt = true;
      await expectLater(repo.load(), throwsA(isA<FormatException>()));
      failQuota = true;
      await expectLater(repo.load(), throwsA(isA<DioException>()));
      dio.close();
    },
  );
}
