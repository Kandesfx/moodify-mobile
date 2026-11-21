import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/app_update/data/app_update_service.dart';
import 'package:moodify_flutter/features/app_update/domain/app_version_info.dart';

import '../../support/auth_harness.dart';

void main() {
  group('AppVersionInfo parsing & comparison', () {
    test(
      'normalizeVersion, parseSemver and compareSemver handle tags and multi-digit segments',
      () {
        expect(AppVersionInfo.normalizeVersion(' v0.1.4 '), '0.1.4');
        expect(AppVersionInfo.normalizeVersion('V1.2.3+10'), '1.2.3+10');

        expect(AppVersionInfo.parseSemver('v0.1.4+5'), [0, 1, 4]);
        expect(AppVersionInfo.parseSemver('v1.2.0-rc1+9'), [1, 2, 0]);
        expect(AppVersionInfo.parseSemver('invalid'), isNull);

        expect(
          AppVersionInfo.compareSemver('v0.1.10', '0.1.9'),
          greaterThan(0),
        );
        expect(AppVersionInfo.compareSemver('0.2', '0.1.9'), greaterThan(0));
        expect(AppVersionInfo.compareSemver('v0.1.4', '0.1.4'), 0);
        expect(AppVersionInfo.compareSemver('0.1.2', '0.1.4'), lessThan(0));
      },
    );

    test(
      'cleanReleaseNotes removes markdown heading hashes while keeping bullets',
      () {
        const raw =
            '## Có gì mới trong bản v0.1.4:\r\n• Sửa lỗi trang chủ\r\n### Chi tiết';
        expect(
          AppVersionInfo.cleanReleaseNotes(raw),
          'Có gì mới trong bản v0.1.4:\n• Sửa lỗi trang chủ\nChi tiết',
        );
      },
    );

    test(
      'fromGitHubRelease prefers moodify-release.apk, skips draft/prerelease and invalid urls',
      () {
        final info = AppVersionInfo.fromGitHubRelease({
          'tag_name': 'v0.1.5',
          'draft': false,
          'prerelease': false,
          'body': '## Phát hành v0.1.5\n• Tự động đồng bộ từ GitHub',
          'assets': [
            {
              'name': 'app-release.apk',
              'browser_download_url': 'https://example.test/app-release.apk',
            },
            {
              'name': 'moodify-release.apk',
              'browser_download_url':
                  'https://example.test/moodify-release.apk',
            },
          ],
        });

        expect(info, isNotNull);
        expect(info!.latestVersion, '0.1.5');
        expect(info.latestBuildNumber, 0);
        expect(info.downloadUrl, 'https://example.test/moodify-release.apk');
        expect(
          info.releaseNotes,
          'Phát hành v0.1.5\n• Tự động đồng bộ từ GitHub',
        );

        expect(
          AppVersionInfo.fromGitHubRelease({
            'tag_name': 'v0.1.5',
            'draft': true,
            'assets': [
              {
                'name': 'moodify-release.apk',
                'browser_download_url':
                    'https://example.test/moodify-release.apk',
              },
            ],
          }),
          isNull,
        );

        expect(
          AppVersionInfo.fromGitHubRelease({
            'tag_name': 'v0.1.5-rc1',
            'prerelease': true,
            'assets': [
              {
                'name': 'moodify-release.apk',
                'browser_download_url':
                    'https://example.test/moodify-release.apk',
              },
            ],
          }),
          isNull,
        );

        final fallbackAppApk = AppVersionInfo.fromGitHubRelease({
          'tag_name': 'v0.1.5',
          'assets': [
            {
              'name': 'Moodify.ipa',
              'browser_download_url': 'https://example.test/Moodify.ipa',
            },
            {
              'name': 'app-release.apk',
              'browser_download_url': 'https://example.test/app-release.apk',
            },
          ],
        });
        expect(
          fallbackAppApk?.downloadUrl,
          'https://example.test/app-release.apk',
        );

        expect(
          AppVersionInfo.fromGitHubRelease({
            'tag_name': 'v0.1.5',
            'assets': [
              {
                'name': 'Moodify.ipa',
                'browser_download_url': 'https://example.test/Moodify.ipa',
              },
            ],
          }),
          isNull,
        );
      },
    );

    test(
      'isNewerThan avoids infinite update loop on same version even when buildNumber is 0',
      () {
        const githubReleaseSame = AppVersionInfo(
          latestVersion: '0.1.4',
          latestBuildNumber: 0,
          downloadUrl: 'https://example.test/moodify-release.apk',
          releaseNotes: '',
        );
        expect(
          githubReleaseSame.isNewerThan(
            currentVersion: '0.1.4',
            currentBuildNumber: 5,
          ),
          isFalse,
        );

        const githubReleaseNewer = AppVersionInfo(
          latestVersion: '0.1.5',
          latestBuildNumber: 0,
          downloadUrl: 'https://example.test/moodify-release.apk',
          releaseNotes: '',
        );
        expect(
          githubReleaseNewer.isNewerThan(
            currentVersion: '0.1.4',
            currentBuildNumber: 5,
          ),
          isTrue,
        );

        const sameVersionNewerBuild = AppVersionInfo(
          latestVersion: '0.1.4',
          latestBuildNumber: 6,
          downloadUrl: 'https://example.test/moodify-release.apk',
          releaseNotes: '',
        );
        expect(
          sameVersionNewerBuild.isNewerThan(
            currentVersion: '0.1.4',
            currentBuildNumber: 5,
          ),
          isTrue,
        );

        const olderVersion = AppVersionInfo(
          latestVersion: '0.1.2',
          latestBuildNumber: 99,
          downloadUrl: 'https://example.test/moodify-release.apk',
          releaseNotes: '',
        );
        expect(
          olderVersion.isNewerThan(
            currentVersion: '0.1.4',
            currentBuildNumber: 5,
          ),
          isFalse,
        );
      },
    );
  });

  group('AppUpdateService.checkForUpdate', () {
    test(
      'uses backend github-synced payload without calling GitHub directly',
      () async {
        final calledUris = <Uri>[];
        final dio = Dio()
          ..httpClientAdapter = TestAdapter((options) {
            calledUris.add(options.uri);
            return jsonResponse({
              'source': 'github',
              'latestVersion': '0.1.5',
              'latestBuildNumber': 6,
              'downloadUrl':
                  'https://github.com/Kandesfx/moodify-mobile/releases/download/v0.1.5/moodify-release.apk',
              'releaseNotes': 'Bản mới từ GitHub qua backend',
              'forceUpdate': true,
            });
          });

        final service = AppUpdateService(
          dio: dio,
          apiBaseUrl: 'https://api.example.test/api',
          currentVersionReader: () async =>
              (versionName: '0.1.4', versionCode: 5),
          isAndroidOverride: true,
        );

        final result = await service.checkForUpdate();
        expect(result, isNotNull);
        expect(result!.latestVersion, '0.1.5');
        expect(result.latestBuildNumber, 6);
        expect(result.forceUpdate, isTrue);
        expect(calledUris.length, 1);
        expect(
          calledUris.single.toString(),
          'https://api.example.test/api/app/version',
        );
      },
    );

    test(
      'falls back to GitHub latest release when backend returns legacy static version',
      () async {
        final calledUris = <String>[];
        final dio = Dio()
          ..httpClientAdapter = TestAdapter((options) {
            final url = options.uri.toString();
            calledUris.add(url);
            if (url == 'https://api.example.test/api/app/version') {
              return jsonResponse({
                'latestVersion': '0.1.2',
                'latestBuildNumber': 3,
                'downloadUrl': 'https://example.test/v0.1.2.apk',
                'releaseNotes': 'Old static config',
                'forceUpdate': false,
              });
            }
            if (url ==
                'https://api.github.com/repos/Kandesfx/moodify-mobile/releases/latest') {
              return jsonResponse({
                'tag_name': 'v0.1.4',
                'draft': false,
                'prerelease': false,
                'body': '## Bản v0.1.4\n• Fix guest HomeScreen',
                'assets': [
                  {
                    'name': 'moodify-release.apk',
                    'browser_download_url':
                        'https://github.com/Kandesfx/moodify-mobile/releases/download/v0.1.4/moodify-release.apk',
                  },
                ],
              });
            }
            return jsonResponse(null, status: 404);
          });

        final service = AppUpdateService(
          dio: dio,
          apiBaseUrl: 'https://api.example.test/api',
          currentVersionReader: () async =>
              (versionName: '0.1.3', versionCode: 4),
          isAndroidOverride: true,
        );

        final result = await service.checkForUpdate();
        expect(result, isNotNull);
        expect(result!.latestVersion, '0.1.4');
        expect(
          result.downloadUrl,
          'https://github.com/Kandesfx/moodify-mobile/releases/download/v0.1.4/moodify-release.apk',
        );
        expect(calledUris, [
          'https://api.example.test/api/app/version',
          'https://api.github.com/repos/Kandesfx/moodify-mobile/releases/latest',
        ]);
      },
    );

    test(
      'falls back to GitHub latest release when backend request fails',
      () async {
        final dio = Dio()
          ..httpClientAdapter = TestAdapter((options) {
            final url = options.uri.toString();
            if (url.startsWith('https://api.example.test/')) {
              return jsonResponse({'error': 'server error'}, status: 500);
            }
            return jsonResponse({
              'tag_name': 'v0.1.4',
              'draft': false,
              'prerelease': false,
              'body': 'Bản mới từ GitHub',
              'assets': [
                {
                  'name': 'moodify-release.apk',
                  'browser_download_url':
                      'https://github.com/Kandesfx/moodify-mobile/releases/download/v0.1.4/moodify-release.apk',
                },
              ],
            });
          });

        final service = AppUpdateService(
          dio: dio,
          apiBaseUrl: 'https://api.example.test/api',
          currentVersionReader: () async =>
              (versionName: '0.1.2', versionCode: 3),
          isAndroidOverride: true,
        );

        final result = await service.checkForUpdate();
        expect(result, isNotNull);
        expect(result!.latestVersion, '0.1.4');
      },
    );

    test(
      'returns null when device is already on latest GitHub release version',
      () async {
        final dio = Dio()
          ..httpClientAdapter = TestAdapter((options) {
            final url = options.uri.toString();
            if (url.startsWith('https://api.example.test/')) {
              return jsonResponse({
                'latestVersion': '0.1.2',
                'latestBuildNumber': 3,
                'downloadUrl': 'https://example.test/v0.1.2.apk',
              });
            }
            return jsonResponse({
              'tag_name': 'v0.1.4',
              'draft': false,
              'prerelease': false,
              'body': 'Latest release',
              'assets': [
                {
                  'name': 'moodify-release.apk',
                  'browser_download_url':
                      'https://github.com/Kandesfx/moodify-mobile/releases/download/v0.1.4/moodify-release.apk',
                },
              ],
            });
          });

        final service = AppUpdateService(
          dio: dio,
          apiBaseUrl: 'https://api.example.test/api',
          currentVersionReader: () async =>
              (versionName: '0.1.4', versionCode: 5),
          isAndroidOverride: true,
        );

        final result = await service.checkForUpdate();
        expect(result, isNull);
      },
    );
  });
}
