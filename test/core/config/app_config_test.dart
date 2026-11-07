import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/core/config/app_config.dart';

void main() {
  test(
    'normalizes API exactly once with trailing slash for relative Dio paths',
    () {
      for (final value in [
        'https://api.example.test',
        'https://api.example.test/',
        'https://api.example.test/api/',
      ]) {
        expect(
          AppConfig(apiBaseUrl: value).apiBaseUri.toString(),
          'https://api.example.test/api/',
        );
      }
    },
  );

  test(
    'rejects credentials, unknown prefixes, missing URL and insecure release',
    () {
      for (final value in [
        '',
        'https://user:password@api.example.test',
        'https://api.example.test/api/api',
        'https://api.example.test?token=private',
        'file:///tmp',
      ]) {
        expect(() => AppConfig(apiBaseUrl: value), throwsFormatException);
      }
      expect(
        () => AppConfig(apiBaseUrl: 'http://localhost:8088', release: true),
        throwsFormatException,
      );
      expect(
        AppConfig(
          apiBaseUrl: 'http://localhost:8088',
          release: false,
        ).apiBaseUri.scheme,
        'http',
      );
    },
  );
  test('upgrade page requires an HTTP URL and HTTPS in release', () {
    expect(
      AppConfig(apiBaseUrl: 'https://api.example.test').premiumWebUri,
      isNull,
    );
    expect(
      AppConfig(
        apiBaseUrl: 'https://api.example.test',
        premiumWebUrl: 'https://example.test/dashboard/premium',
        release: true,
      ).premiumWebUri!.host,
      'example.test',
    );
    for (final value in [
      'http://example.test',
      'https://user:pass@example.test',
      'https://example.test?token=x',
      'file:///test',
    ]) {
      expect(
        () => AppConfig(
          apiBaseUrl: 'https://api.example.test',
          premiumWebUrl: value,
          release: true,
        ),
        throwsFormatException,
      );
    }
  });

  test('fromEnvironment provides production default when not specified', () {
    final config = AppConfig.fromEnvironment();
    expect(config.apiBaseUri.toString(), 'https://api.moodify.click/api/');
  });

  test('provides precise and actionable error messages for constraints', () {
    expect(
      () => AppConfig(apiBaseUrl: ''),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Chưa cấu hình API_BASE_URL'),
        ),
      ),
    );
    expect(
      () => AppConfig(apiBaseUrl: 'https://user:pass@api.example.com'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('thông tin tài khoản'),
        ),
      ),
    );
    expect(
      () => AppConfig(apiBaseUrl: 'https://api.example.com?query=1'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('tham số truy vấn'),
        ),
      ),
    );
    expect(
      () => AppConfig(apiBaseUrl: 'https://api.example.com#section'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('fragment (#)'),
        ),
      ),
    );
    expect(
      () => AppConfig(apiBaseUrl: 'http://api.example.com', release: true),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('HTTPS'),
        ),
      ),
    );
    expect(
      () => AppConfig(apiBaseUrl: 'https://api.example.com/v1/custom'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('origin'),
        ),
      ),
    );
  });
}
