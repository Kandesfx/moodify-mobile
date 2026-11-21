class AppVersionInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;

  const AppVersionInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    this.forceUpdate = false,
  });

  static String normalizeVersion(String raw) =>
      raw.trim().replaceFirst(RegExp(r'^[vV]+'), '').trim();

  static List<int>? parseSemver(String raw) {
    final normalized = normalizeVersion(raw);
    if (normalized.isEmpty) return null;
    final core = normalized.split('+').first.split('-').first.trim();
    if (core.isEmpty) return null;
    final parts = core.split('.');
    if (parts.isEmpty || parts.length > 4) return null;
    final parsed = <int>[];
    for (final part in parts) {
      if (part.isEmpty) return null;
      final value = int.tryParse(part);
      if (value == null || value < 0) return null;
      parsed.add(value);
    }
    return parsed;
  }

  static int? compareSemver(String a, String b) {
    final pa = parseSemver(a);
    final pb = parseSemver(b);
    if (pa == null || pb == null) return null;
    final maxLen = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < maxLen; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  static String cleanReleaseNotes(String raw) {
    if (raw.trim().isEmpty) return '';
    return raw
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^\s*#{1,6}\s*'), ''))
        .join('\n')
        .trim();
  }

  static AppVersionInfo? fromGitHubRelease(Map<String, dynamic> json) {
    if (json['draft'] == true || json['prerelease'] == true) {
      return null;
    }
    final latestVersion = normalizeVersion(json['tag_name'] as String? ?? '');
    if (latestVersion.isEmpty) return null;

    final rawAssets = json['assets'];
    if (rawAssets is! List) return null;

    String? moodifyUrl;
    String? appReleaseUrl;
    String? firstApkUrl;

    for (final rawAsset in rawAssets) {
      if (rawAsset is! Map) continue;
      final name = (rawAsset['name'] as String? ?? '').trim().toLowerCase();
      final url = (rawAsset['browser_download_url'] as String? ?? '').trim();
      final uri = Uri.tryParse(url);
      final isValidHttpsApk =
          name.endsWith('.apk') &&
          uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty;
      if (!isValidHttpsApk) continue;

      if (name == 'moodify-release.apk') {
        moodifyUrl = url;
        break;
      } else if (name == 'app-release.apk') {
        appReleaseUrl ??= url;
      } else {
        firstApkUrl ??= url;
      }
    }

    final downloadUrl = moodifyUrl ?? appReleaseUrl ?? firstApkUrl;
    if (downloadUrl == null) return null;

    return AppVersionInfo(
      latestVersion: latestVersion,
      latestBuildNumber: 0,
      downloadUrl: downloadUrl,
      releaseNotes: cleanReleaseNotes(json['body'] as String? ?? ''),
      forceUpdate: false,
    );
  }

  bool isNewerThan({
    required String currentVersion,
    required int currentBuildNumber,
  }) {
    if (downloadUrl.trim().isEmpty) return false;
    final cmp = compareSemver(latestVersion, currentVersion);
    if (cmp != null) {
      if (cmp > 0) return true;
      if (cmp < 0) return false;
      return latestBuildNumber > currentBuildNumber;
    }
    return latestBuildNumber > currentBuildNumber;
  }

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    final normalized = normalizeVersion(
      json['latestVersion'] as String? ?? '0.1.0',
    );
    return AppVersionInfo(
      latestVersion: normalized.isEmpty ? '0.1.0' : normalized,
      latestBuildNumber: (json['latestBuildNumber'] as num?)?.toInt() ?? 0,
      downloadUrl: json['downloadUrl'] as String? ?? '',
      releaseNotes: json['releaseNotes'] as String? ?? '',
      forceUpdate: json['forceUpdate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'latestVersion': latestVersion,
    'latestBuildNumber': latestBuildNumber,
    'downloadUrl': downloadUrl,
    'releaseNotes': releaseNotes,
    'forceUpdate': forceUpdate,
  };
}
