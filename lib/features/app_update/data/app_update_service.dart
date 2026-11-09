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

class AppUpdateService {
  static const MethodChannel _channel =
      MethodChannel('dev.moodify.moodify_flutter/app_update');

  /// Phiên bản hiện tại của app (khớp với pubspec.yaml: version: 0.1.0+1)
  static const String currentVersion = '0.1.0';
  static const int currentBuildNumber = 1;

  final Dio _dio;

  AppUpdateService({Dio? dio}) : _dio = dio ?? Dio();

  /// Kiểm tra có bản cập nhật mới hay không
  Future<AppVersionInfo?> checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return null;

    try {
      final config = AppConfig.fromEnvironment();
      final url = '${config.apiBaseUri.toString()}/app/version';

      final response = await _dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final info =
            AppVersionInfo.fromJson(response.data as Map<String, dynamic>);
        if (info.latestBuildNumber > currentBuildNumber &&
            info.downloadUrl.isNotEmpty) {
          return info;
        }
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
      final result = await _channel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Lỗi khởi chạy cài đặt APK: $e');
      }
      return false;
    }
  }
}
