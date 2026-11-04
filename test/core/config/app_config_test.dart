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
}
