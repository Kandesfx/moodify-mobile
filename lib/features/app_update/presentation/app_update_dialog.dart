import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../data/app_update_service.dart';
import '../domain/app_version_info.dart';

class AppUpdateDialog extends StatefulWidget {
  final AppVersionInfo info;
  final AppUpdateService service;

  const AppUpdateDialog({super.key, required this.info, required this.service});

  static Future<void> show(
    BuildContext context,
    AppVersionInfo info, {
    AppUpdateService? service,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) =>
          AppUpdateDialog(info: info, service: service ?? AppUpdateService()),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _downloading = false;
  double _progress = 0.0;
  String _progressText = '';
  File? _downloadedFile;
  String? _errorMessage;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _progressText = 'Đang kết nối...';
      _cancelToken = CancelToken();
    });

    final file = await widget.service.downloadApk(
      widget.info.downloadUrl,
      cancelToken: _cancelToken,
      onProgress: (received, total) {
        if (!mounted) return;
        if (total > 0) {
          final p = received / total;
          final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
          final totMb = (total / (1024 * 1024)).toStringAsFixed(1);
          setState(() {
            _progress = p;
            _progressText = '${(p * 100).toInt()}% ($recMb MB / $totMb MB)';
          });
        } else {
          final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
          setState(() {
            _progress = 0.5;
            _progressText = '$recMb MB';
          });
        }
      },
    );

    if (!mounted) return;

    if (file != null) {
      setState(() {
        _downloading = false;
        _downloadedFile = file;
        _progressText = 'Tải hoàn tất! Chuẩn bị cài đặt...';
      });
      await _install(file);
    } else {
      setState(() {
        _downloading = false;
        _errorMessage = 'Tải bản cập nhật thất bại. Vui lòng thử lại sau.';
      });
    }
  }

  Future<void> _install(File file) async {
    final canInstall = await widget.service.canInstallPackage();
    if (!canInstall) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          title: const Text(
            'Cấp quyền cài đặt',
            style: TextStyle(color: AppColors.text),
          ),
          content: const Text(
            'Hệ điều hành Android yêu cầu bạn cho phép Moodify cài đặt ứng dụng. Hãy bật "Cho phép từ nguồn này" trong màn hình cài đặt tiếp theo.',
            style: TextStyle(color: AppColors.secondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppColors.secondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Mở Cài đặt',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (proceed == true) {
        await widget.service.openInstallPermissionSettings();
      }
      return;
    }

    final success = await widget.service.installApk(file.path);
    if (!success && mounted) {
      setState(() {
        _errorMessage = 'Không thể mở trình cài đặt Android. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;

    return PopScope(
      canPop: !info.forceUpdate && !_downloading,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Badge & Title
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.liked],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CẬP NHẬT MOODIFY',
                          style: TextStyle(
                            color: AppColors.lavender,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Phiên bản mới v${info.latestVersion}',
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Release notes box
              if (info.releaseNotes.isNotEmpty) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      info.releaseNotes,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Downloading progress indicator
              if (_downloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: AppColors.surface,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _progressText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Error message
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
              ],

              // Action Buttons
              if (!_downloading) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    if (_downloadedFile != null) {
                      _install(_downloadedFile!);
                    } else {
                      _startDownload();
                    }
                  },
                  child: Text(
                    _downloadedFile != null ? 'Cài đặt ngay' : 'Cập nhật ngay',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!info.forceUpdate) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Để sau',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    _cancelToken?.cancel();
                    setState(() {
                      _downloading = false;
                      _errorMessage = 'Đã hủy tải bản cập nhật.';
                    });
                  },
                  child: const Text(
                    'Hủy tải',
                    style: TextStyle(color: AppColors.secondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
