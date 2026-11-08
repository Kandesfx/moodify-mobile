import '../../catalog/domain/catalog_models.dart';

class RecommendationItem {
  const RecommendationItem({
    required this.itemId,
    required this.entityType,
    required this.entityId,
    this.versionId,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.trackCount = 0,
    required this.reason,
    required this.reasonCode,
    this.score = 0.0,
    required this.attributionToken,
    this.track,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) =>
      RecommendationItem(
        itemId: requiredText(json, 'itemId'),
        entityType: requiredText(json, 'entityType'),
        entityId: requiredText(json, 'entityId'),
        versionId: optionalText(json['versionId']),
        title: requiredText(json, 'title'),
        subtitle: optionalText(json['subtitle']),
        imageUrl: optionalText(json['imageUrl']),
        trackCount: (json['trackCount'] as num?)?.toInt() ?? 0,
        reason: optionalText(json['reason']) ?? 'Dành cho bạn',
        reasonCode: optionalText(json['reasonCode']) ?? 'FOR_YOU',
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
        attributionToken: optionalText(json['attributionToken']) ?? '',
        track: json['track'] is Map<String, dynamic>
            ? Track.fromJson(json['track'] as Map<String, dynamic>)
            : null,
      );

  final String itemId;
  final String entityType;
  final String entityId;
  final String? versionId;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final int trackCount;
  final String reason;
  final String reasonCode;
  final double score;
  final String attributionToken;
  final Track? track;

  bool get isTrack => entityType == 'TRACK';
  bool get isPersonalizedMix => entityType == 'PERSONALIZED_PLAYLIST';
  bool get isPlaylist => entityType == 'PLAYLIST';
}

class RecommendationSection {
  const RecommendationSection({
    required this.id,
    required this.title,
    required this.description,
    required this.items,
  });

  factory RecommendationSection.fromJson(Map<String, dynamic> json) {
    final list = json['items'];
    return RecommendationSection(
      id: requiredText(json, 'id'),
      title: requiredText(json, 'title'),
      description: optionalText(json['description']) ?? '',
      items: list is List
          ? List.unmodifiable(
              list.whereType<Map<String, dynamic>>().map(
                RecommendationItem.fromJson,
              ),
            )
          : const [],
    );
  }

  final String id;
  final String title;
  final String description;
  final List<RecommendationItem> items;
}

class RecommendationHome {
  const RecommendationHome({
    required this.requestId,
    this.generatedAt,
    this.expiresAt,
    this.availabilityStatus,
    this.coldStart = false,
    required this.sections,
  });

  factory RecommendationHome.fromJson(Map<String, dynamic> json) {
    final list = json['sections'];
    return RecommendationHome(
      requestId: optionalText(json['requestId']) ?? '',
      generatedAt: optionalText(json['generatedAt']),
      expiresAt: optionalText(json['expiresAt']),
      availabilityStatus: optionalText(json['availabilityStatus']),
      coldStart: json['coldStart'] == true,
      sections: list is List
          ? List.unmodifiable(
              list.whereType<Map<String, dynamic>>().map(
                RecommendationSection.fromJson,
              ),
            )
          : const [],
    );
  }

  final String requestId;
  final String? generatedAt;
  final String? expiresAt;
  final String? availabilityStatus;
  final bool coldStart;
  final List<RecommendationSection> sections;
}
