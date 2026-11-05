import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/core/errors/app_failure.dart';
import 'package:moodify_flutter/features/player/data/ad_policy.dart';

import '../../support/auth_harness.dart';

void main() {
  Map<String, dynamic> policy(
    String tier,
    String kind,
    int limit,
    int interval,
  ) => {
    'tier': tier,
    'entitlements': {
      'adPolicy': kind,
      'adFreeDailyLimit': limit,
      'adIntervalAfterLimit': interval,
    },
  };

  test(
    'server NO_ADS avoids ads; daily quota and skip follow server',
    () async {
      var body = policy('INDIVIDUAL_FULL', 'NO_ADS', 0, 0);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/'));
      dio.httpClientAdapter = TestAdapter((_) => jsonResponse(body));
      final ads = AdPolicyService(
        dio,
        MemoryStore(),
        'test',
        random: Random(1),
      );
      expect((await ads.decide('1')).show, false);
      body = policy('INDIVIDUAL_BASIC', 'DAILY_QUOTA', 1, 2);
      expect((await ads.decide('1')).show, false);
      final decision = await ads.decide('1');
      expect(decision.show, true);
      expect(decision.canSkip, true);
      dio.close();
    },
  );

  test('subscription failure does not grant ad-free playback', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/'));
    dio.httpClientAdapter = TestAdapter((_) => jsonResponse(null, status: 503));
    final ads = AdPolicyService(dio, MemoryStore(), 'test');
    await expectLater(ads.decide('1'), throwsA(isA<AppFailure>()));
    dio.close();
  });

  test('quota counters are scoped to account and local day', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/'));
    dio.httpClientAdapter = TestAdapter(
      (_) => jsonResponse(policy('INDIVIDUAL_BASIC', 'DAILY_QUOTA', 0, 2)),
    );
    final store = MemoryStore();
    var today = DateTime(2026, 11, 5);
    final ads = AdPolicyService(dio, store, 'test', clock: () => today);
    expect((await ads.decide('1')).show, false);
    expect((await ads.decide('2')).show, false);
    expect((await ads.decide('1')).show, true);
    today = DateTime(2026, 11, 6);
    expect((await ads.decide('1')).show, false);
    dio.close();
  });
}
