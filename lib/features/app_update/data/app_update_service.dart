import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_config.dart';
import '../domain/app_version_info.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

final appVersionProvider =
    FutureProvider<({String versionName, int versionCode})>((ref) {
      return ref.watch(appUpdateServiceProvider).getCurrentVersion();
    });

class AppUpdateService {
  static const defaultGithubRepo = 'Kandesfx/moodify-mobile';
  static const MethodChannel _channel = MethodChannel(
    'dev.moodify.moodify_flutter/app_update',
  );

  final Dio _dio;
  final String? _apiBaseUrlOverride;
  final String _githubRepo;
  final Future<({String versionName, int versionCode})> Function()?
  _currentVersionReader;
  final bool? _isAndroidOverride;
  ({String versionName, int versionCode})? _cachedVersion;

  AppUpdateService({
    Dio? dio,
    String? apiBaseUrl,
    String? githubRepo,
    Future<({String versionName, int versionCode})> Function()?
    currentVersionReader,
    bool? isAndroidOverride,
  }) : _dio = dio ?? Dio(),
       _apiBaseUrlOverride = apiBaseUrl,
       _githubRepo = _resolveGithubRepo(githubRepo),
       _currentVersionReader = currentVersionReader,
       _isAndroidOverride = isAndroidOverride;

  static String _resolveGithubRepo(String? override) {
    final trimmed = (override ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    const fromEnv = String.fromEnvironment(
      'APP_UPDATE_GITHUB_REPO',
      defaultValue: defaultGithubRepo,
    );
    final envTrimmed = fromEnv.trim();
    return envTrimmed.isNotEmpty ? envTrimmed : defaultGithubRepo;
  }

  /// Lấy thông tin phiên bản thật sự đang cài đặt trên thiết bị từ Android PackageManager hoặc iOS Bundle
  Future<({String versionName, int versionCode})> getCurrentVersion() async {
    if (_cachedVersion != null) return _cachedVersion!;
    if (kIsWeb) {
      return (versionName: '0.1.4', versionCode: 5);
    }
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'getAppVersion',
      );
      if (res != null) {
        final versionName = res['versionName'] as String? ?? '0.1.4';
        final versionCode = (res['versionCode'] as num?)?.toInt() ?? 5;
        _cachedVersion = (versionName: versionName, versionCode: versionCode);
        return _cachedVersion!;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Lỗi lấy phiên bản app từ PackageManager: $e');
      }
    }
    return (versionName: '0.1.4', versionCode: 5);
  }

  Future<({AppVersionInfo info, bool fromGitHub})?> _fetchFromBackend() async {
    try {
      final base =
          (_apiBaseUrlOverride ??
                  AppConfig.fromEnvironment().apiBaseUri.toString())
              .replaceAll(RegExp(r'/+$'), '');
      final url = '$base/app/version';

      final response = await _dio.get<Object?>(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final fromGitHub =
            (data['source'] as String?)?.trim().toLowerCase() == 'github';
        return (info: AppVersionInfo.fromJson(data), fromGitHub: fromGitHub);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Lỗi kiểm tra bản cập nhật từ backend: $e');
      }
    }
    return null;
  }

  Future<AppVersionInfo?> _fetchFromGitHub() async {
    try {
      final url = 'https://api.github.com/repos/$_githubRepo/releases/latest';
      final response = await _dio.get<Object?>(
        url,
        options: Options(
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'Moodify-Flutter',
          },
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        return AppVersionInfo.fromGitHubRelease(data);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Lỗi kiểm tra bản cập nhật từ GitHub: $e');
      }
    }
    return null;
  }

  AppVersionInfo _pickNewer(AppVersionInfo a, AppVersionInfo b) {
    final cmp = AppVersionInfo.compareSemver(a.latestVersion, b.latestVersion);
    if (cmp != null) {
      if (cmp > 0) return a;
      if (cmp < 0) return b;
    }
    return b.latestBuildNumber > a.latestBuildNumber ? b : a;
  }

  /// Kiểm tra có bản cập nhật mới hay không (ưu tiên backend đồng bộ Git, fallback trực tiếp GitHub Releases)
  Future<AppVersionInfo?> checkForUpdate() async {
    if (kIsWeb || !(_isAndroidOverride ?? Platform.isAndroid)) return null;

    try {
      final current = _currentVersionReader != null
          ? await _currentVersionReader()
          : await getCurrentVersion();

      final backend = await _fetchFromBackend();
      AppVersionInfo? candidate = backend?.info;

      if (backend == null || !backend.fromGitHub) {
        final github = await _fetchFromGitHub();
        if (github != null) {
          candidate = candidate == null
              ? github
              : _pickNewer(candidate, github);
        }
      }

      if (candidate != null &&
          candidate.isNewerThan(
            currentVersion: current.versionName,
            currentBuildNumber: current.versionCode,
          )) {
        return candidate;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Lỗi kiểm tra bản cập nhật: $e');
      }
    }
    return null;
  }

  /// Kiểm tra quyền cài đặt từ nguồn ngoài trên Android
  Future<bool> canInstallPackage() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('canInstallPackage');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Mở màn hình cài đặt cấp quyền cài đặt ứng dụng không rõ nguồn gốc
  Future<void> openInstallPermissionSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openInstallPermissionSettings');
    } catch (_) {}
  }

  /// Tải file APK với tiến trình %
  Future<File?> downloadApk(
    String downloadUrl, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final apkPath = '${cacheDir.path}/moodify_update.apk';
      final file = File(apkPath);
      if (await file.exists()) {
        await file.delete();
      }

      await _dio.download(
        downloadUrl,
        apkPath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );

      return file;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Lỗi tải file APK: $e');
      }
      return null;
    }
  }

  /// Gọi hệ thống Android cài đặt file APK
  Future<bool> installApk(String filePath) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Lỗi khởi chạy cài đặt APK: $e');
      }
      return false;
    }
  }
}
