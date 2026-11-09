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

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      latestVersion: json['latestVersion'] as String? ?? '0.1.0',
      latestBuildNumber: (json['latestBuildNumber'] as num?)?.toInt() ?? 1,
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
