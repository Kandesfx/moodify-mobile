import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/storage/key_value_store.dart';

class AdPolicy {
  const AdPolicy({
    required this.policy,
    required this.tier,
    required this.dailyLimit,
    required this.interval,
  });
  final String policy, tier;
  final int dailyLimit, interval;
  bool get canSkip => tier == 'INDIVIDUAL_BASIC';

  static const guest = AdPolicy(
    policy: 'FULL_ADS',
    tier: 'FREE',
    dailyLimit: 0,
    interval: 2,
  );

  factory AdPolicy.fromJson(Object? value) {
    if (value is! Map || value['entitlements'] is! Map) {
      throw const FormatException('Missing subscription entitlements');
    }
    final ent = value['entitlements'] as Map;
    final policy = ent['adPolicy'];
    final tier = value['tier'];
    final limit = ent['adFreeDailyLimit'];
    final interval = ent['adIntervalAfterLimit'];
    if (policy is! String ||
        !['NO_ADS', 'DAILY_QUOTA', 'FULL_ADS'].contains(policy) ||
        tier is! String ||
        limit is! num ||
        interval is! num ||
        limit < 0 ||
        interval < 0) {
      throw const FormatException('Invalid subscription entitlements');
    }
    return AdPolicy(
      policy: policy,
      tier: tier,
      dailyLimit: limit.toInt(),
      interval: max(1, interval.toInt()),
    );
  }
}

class AdDecision {
  const AdDecision(this.show, this.canSkip);
  final bool show, canSkip;
}

/// Playback policy is read from the server for each selection; daily counters
/// are local to the installation, API environment, account and calendar day.
class AdPolicyService {
  AdPolicyService(
    this.dio,
    this.store,
    this.scope, {
    Random? random,
    DateTime Function()? clock,
  }) : random = random ?? Random(),
       clock = clock ?? DateTime.now;
  final Dio dio;
  final KeyValueStore store;
  final String scope;
  final Random random;
  final DateTime Function() clock;
  int _sinceAd = 0;
  int? _threshold;
  String? _user;

  Future<AdDecision> decide(String? userId) async {
    AdPolicy policy;
    if (userId == null) {
      policy = AdPolicy.guest;
    } else {
      try {
        final response = await dio.get<dynamic>('subscriptions/me');
        policy = AdPolicy.fromJson(response.data);
      } catch (_) {
        throw const AppFailure(
          'Không thể kiểm tra quyền nghe nhạc. Vui lòng kết nối mạng và thử lại.',
          code: 'AD_POLICY',
        );
      }
    }
    if (_user != userId) {
      _user = userId;
      _sinceAd = 0;
      _threshold = null;
    }
    final now = clock();
    final day = '${now.year}-${now.month}-${now.day}';
    final key =
        'ad_stats_v1_${Uri.encodeComponent(scope)}_${Uri.encodeComponent(userId ?? 'guest')}';
    var count = 0;
    try {
      final raw = await store.read(key);
      if (raw != null) {
        final value = jsonDecode(raw);
        if (value is Map && value['day'] == day && value['tracks'] is int) {
          count = value['tracks'] as int;
        }
      }
      count++;
      await store.write(key, jsonEncode({'day': day, 'tracks': count}));
    } catch (_) {
      throw const AppFailure(
        'Không thể lưu hạn mức nghe nhạc trên thiết bị. Vui lòng thử lại.',
        code: 'AD_COUNTER',
      );
    }
    if (policy.policy == 'NO_ADS') return const AdDecision(false, false);
    if (policy.policy == 'DAILY_QUOTA') {
      final after = count - policy.dailyLimit;
      return AdDecision(
        after > 0 && after % policy.interval == 0,
        policy.canSkip,
      );
    }
    _threshold ??= random.nextInt(3) + 1;
    _sinceAd++;
    final show = _sinceAd >= _threshold!;
    if (show) {
      _sinceAd = 0;
      _threshold = random.nextInt(policy.interval) + 1;
    }
    return AdDecision(show, policy.canSkip);
  }
}
