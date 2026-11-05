import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/catalog/data/artist_repository.dart';
import 'package:moodify_flutter/features/auth/data/device_repository.dart';
import 'package:moodify_flutter/features/auth/data/device_identity.dart';
import '../../support/auth_harness.dart';

void main() {
  test('artist profile keeps real metadata and followed artist IDs', () async {
    final dio = Dio()
      ..httpClientAdapter = TestAdapter(
        (request) => jsonResponse(
          request.path.endsWith('followed')
              ? [
                  {
                    'artistId': 'artist-a',
                    'name': 'Artist A',
                    'imageUrl': null,
                  },
                ]
              : {
                  'artistId': 'artist-a',
                  'name': 'Artist A',
                  'isFollowed': true,
                  'followersCount': 3,
                  'bio': 'Artist biography',
                  'albums': [],
                },
        ),
      );
    final repo = ArtistRepository(dio);
    final profile = await repo.profile('artist-a');
    expect(profile.followed, true);
    expect(profile.followers, 3);
    expect(profile.bio, 'Artist biography');
    expect((await repo.followed()).single.id, 'artist-a');
    dio.close();
  });
  test(
    'follow double tap has a single mutation; late completion cannot update disposed account',
    () async {
      final pending = Completer<ResponseBody>();
      final reached = Completer<void>();
      var requests = 0, updates = 0;
      final dio = Dio()
        ..httpClientAdapter = TestAdapter((request) {
          requests++;
          if (!reached.isCompleted) reached.complete();
          return pending.future;
        });
      final action = ArtistFollowAction(
        ArtistRepository(dio),
        'artist-a',
        () => updates++,
      );
      final work = action.run();
      await action.run();
      await reached.future;
      expect(requests, 1);
      action.dispose();
      pending.complete(jsonResponse({'isFollowed': true}));
      await work;
      expect(updates, 0);
      dio.close();
    },
  );
  test(
    'device requests use real current device UUID and require revoke success',
    () async {
      final requests = <RequestOptions>[];
      final store = MemoryStore();
      final identity = DeviceIdentityStore(store, platform: 'ANDROID');
      final current = await identity.load();
      final dio = Dio()
        ..httpClientAdapter = TestAdapter((r) {
          requests.add(r);
          return jsonResponse(
            r.method == 'GET'
                ? {
                    'devices': [
                      {
                        'id': 1,
                        'deviceUuid': current.uuid,
                        'status': 'ACTIVE',
                        'deviceName': 'Phone',
                      },
                    ],
                    'activeCount': 1,
                    'maxDevices': 2,
                  }
                : r.method == 'PATCH'
                ? {'success': false}
                : {'revokedCount': 1},
          );
        });
      final repo = DeviceRepository(dio, identity);
      final devices = await repo.load();
      expect(devices.currentUuid, current.uuid);
      expect(devices.devices.single.name, 'Phone');
      await repo.revoke(null);
      expect(requests.last.data, {'deviceUuid': current.uuid});
      await expectLater(repo.revoke('1'), throwsA(isNotNull));
      dio.close();
    },
  );
}
