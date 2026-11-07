import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig({
    required String apiBaseUrl,
    this.environment = 'development',
    String premiumWebUrl = '',
    bool release = kReleaseMode,
  }) : apiBaseUri = _validate(apiBaseUrl, release),
       premiumWebUri = _validatePremiumUrl(premiumWebUrl, release);

  static const defaultProductionApiBaseUrl = 'https://api.moodify.click/api';

  factory AppConfig.fromEnvironment() => AppConfig(
    apiBaseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: defaultProductionApiBaseUrl,
    ),
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
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      throw const FormatException(
        'PREMIUM_WEB_URL không đúng định dạng URL hoặc thiếu tên máy chủ (host).',
      );
    }
    if (!['https', 'http'].contains(uri.scheme)) {
      throw const FormatException(
        'PREMIUM_WEB_URL phải dùng giao thức HTTP hoặc HTTPS.',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'PREMIUM_WEB_URL không được chứa thông tin tài khoản hoặc mật khẩu trong URL.',
      );
    }
    if (uri.hasQuery) {
      throw const FormatException(
        'PREMIUM_WEB_URL không được chứa tham số truy vấn (query parameter).',
      );
    }
    if (uri.hasFragment) {
      throw const FormatException(
        'PREMIUM_WEB_URL không được chứa ký tự fragment (#).',
      );
    }
    if (release && uri.scheme != 'https') {
      throw const FormatException(
        'Bản release yêu cầu PREMIUM_WEB_URL phải dùng giao thức bảo mật HTTPS.',
      );
    }
    return uri;
  }

  static Uri _validate(String input, bool release) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FormatException(
        'Chưa cấu hình API_BASE_URL (chuỗi rỗng). Vui lòng cung cấp URL API hợp lệ (ví dụ: https://api.moodify.click/api).',
      );
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      throw const FormatException(
        'API_BASE_URL không đúng định dạng URL hoặc thiếu tên máy chủ (host).',
      );
    }
    if (!['https', 'http'].contains(uri.scheme)) {
      throw const FormatException(
        'API_BASE_URL phải sử dụng giao thức HTTP hoặc HTTPS.',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'API_BASE_URL không được chứa thông tin tài khoản người dùng hoặc mật khẩu trong URL.',
      );
    }
    if (uri.hasQuery) {
      throw const FormatException(
        'API_BASE_URL không được chứa tham số truy vấn (query parameter).',
      );
    }
    if (uri.hasFragment) {
      throw const FormatException(
        'API_BASE_URL không được chứa ký tự fragment (#).',
      );
    }
    if (release && uri.scheme != 'https') {
      throw const FormatException(
        'Bản release yêu cầu API_BASE_URL dùng giao thức bảo mật HTTPS.',
      );
    }
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (path.isNotEmpty && path != '/api') {
      throw const FormatException(
        'API_BASE_URL phải là origin (ví dụ: https://example.com) hoặc kết thúc bằng /api.',
      );
    }
    return uri.replace(path: '/api/');
  }

  bool contains(Uri uri) =>
      uri.origin == apiBaseUri.origin && uri.path.startsWith(apiBaseUri.path);
}
