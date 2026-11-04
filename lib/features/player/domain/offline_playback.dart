import '../../catalog/domain/catalog_models.dart';

typedef OfflineSource = ({Uri uri, DateTime expiresAt});

abstract interface class OfflinePlaybackAccess {
  Future<OfflineSource?> playback(Track track, {bool required = false});
  Future<void> releasePlayback();
}
