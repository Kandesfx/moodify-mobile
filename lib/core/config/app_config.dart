import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig({
    required String apiBaseUrl,
    this.environment = 'development',
    String premiumWebUrl = '',
    bool release = kReleaseMode,
  }) : apiBaseUri = _validate(apiBaseUrl, release),
       premiumWebUri = _validatePremiumUrl(premiumWebUrl, release);

  factory AppConfig.fromEnvironment() => AppConfig(
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    premiumWebUrl: const String.fromEnvironment('PREMIUM_WEB_URL'),
    environment: const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    ),
  );

  final Uri apiBaseUri;
  final Uri? premiumWebUri;
  final String environment;

  static Uri? _validatePremiumUrl(String input, bool release) {
    if (input.trim().isEmpty) return null;
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (release && uri.scheme != 'https')) {
      throw const FormatException(
        'PREMIUM_WEB_URL phải là URL HTTP(S) hợp lệ; bản release yêu cầu HTTPS.',
      );
    }
    return uri;
  }

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
