class Track {
  const Track({
    required this.id,
    required this.spotifyId,
    required this.name,
    required this.artist,
    this.artistId,
    this.image,
    this.localPath,
    this.durationMs = 0,
    this.lyrics,
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: requiredText(json, 'id'),
    spotifyId: optionalText(json['spotifyId']) ?? requiredText(json, 'id'),
    name: requiredText(json, 'name'),
    artist: optionalText(json['artistName']) ?? 'Chưa rõ nghệ sĩ',
    artistId: optionalText(json['artistSpotifyId']),
    image: optionalText(json['imageUrl']),
    localPath: optionalText(json['localPath']),
    durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
    lyrics: optionalText(json['lyricsPlain']),
  );
  final String id, spotifyId, name, artist;
  final String? artistId, image, localPath, lyrics;
  final int durationMs;
  bool get hasTitle => !RegExp(r'^[a-fA-F0-9]{32,}$').hasMatch(name);
  String get displayName => hasTitle ? name : 'Chưa có tên bài hát';
  bool get hasAudio => localPath != null && localPath!.trim().isNotEmpty;
}

class TrackPage {
  const TrackPage(this.tracks, this.page, this.totalPages, this.total);
  factory TrackPage.fromJson(
    Map<String, dynamic> json, {
    bool library = false,
  }) {
    final items = json[library ? 'tracks' : 'content'];
    if (items is! List ||
        json['totalPages'] is! num ||
        json[library ? 'currentPage' : 'page'] is! num ||
        json['totalElements'] is! num) {
      throw const FormatException('Invalid track page');
    }
    return TrackPage(
      List.unmodifiable(items.map((e) => Track.fromJson(objectJson(e)))),
      (json[library ? 'currentPage' : 'page'] as num).toInt(),
      (json['totalPages'] as num).toInt(),
      (json['totalElements'] as num).toInt(),
    );
  }
  final List<Track> tracks;
  final int page, totalPages, total;
  bool get hasMore => page + 1 < totalPages;
}

class MusicCollection {
  const MusicCollection({
    required this.id,
    required this.title,
    this.image,
    this.author,
    this.description,
    this.trackCount = 0,
    this.tracks = const [],
  });
  factory MusicCollection.fromJson(
    Map<String, dynamic> json, {
    bool album = false,
  }) {
    var image = optionalText(json['coverUrl']);
    // This URL is a server-side stock fallback, not an album's artwork.
    if (image?.contains('photo-1514525253161-7a46d19cd819') ?? false) {
      image = null;
    }
    return MusicCollection(
      id: requiredText(json, 'id'),
      title: requiredText(json, album ? 'title' : 'name'),
      image: image,
      author: optionalText(json[album ? 'authorName' : 'username']),
      description: optionalText(json['description']),
      trackCount: (json['trackCount'] as num?)?.toInt() ?? 0,
      tracks: List.unmodifiable(
        (json['tracks'] as List? ?? []).map(
          (e) => Track.fromJson(objectJson(e)),
        ),
      ),
    );
  }
  final String id, title;
  final String? image, author, description;
  final int trackCount;
  final List<Track> tracks;
}

class Artist {
  Artist.fromJson(Map<String, dynamic> json)
    : id = optionalText(json['spotifyId']) ?? requiredText(json, 'id'),
      name = requiredText(json, 'name'),
      image = optionalText(json['imageUrl']);
  final String id, name;
  final String? image;
}

Map<String, dynamic> objectJson(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected object');
  }
  return value;
}

String? optionalText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String requiredText(Map<String, dynamic> json, String key) =>
    optionalText(json[key]) ?? (throw FormatException('Missing $key'));

String segment(String id) => Uri.encodeComponent(id);
