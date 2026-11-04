import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig({
    required String apiBaseUrl,
    this.environment = 'development',
    bool release = kReleaseMode,
  }) : apiBaseUri = _validate(apiBaseUrl, release);

  factory AppConfig.fromEnvironment() => AppConfig(
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    environment: const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    ),
  );

  final Uri apiBaseUri;
  final String environment;

  static Uri _validate(String input, bool release) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'API_BASE_URL phải là URL HTTP(S) hợp lệ, không chứa tài khoản hoặc tham số.',
      );
    }
    if (release && uri.scheme != 'https') {
      throw const FormatException(
        'Bản release yêu cầu API_BASE_URL dùng HTTPS.',
      );
    }
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (path.isNotEmpty && path != '/api') {
      throw const FormatException(
        'API_BASE_URL phải là origin hoặc kết thúc bằng /api.',
      );
    }
    return uri.replace(path: '/api/');
  }

  bool contains(Uri uri) =>
      uri.origin == apiBaseUri.origin && uri.path.startsWith(apiBaseUri.path);
}
