import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../auth/presentation/session_controller.dart';

class PendingTrackAction {
  PendingTrackAction(this.track, this.action, this.returnTo)
    : expiresAt = DateTime.now().add(const Duration(minutes: 10));
  final Track track;
  final String action, returnTo;
  final DateTime expiresAt;
}

final pendingTrackActionProvider = StateProvider<PendingTrackAction?>((ref) {
  ref.listen(sessionControllerProvider.select((s) => s.session?.user.id), (
    previous,
    next,
  ) {
    if (previous != null && previous != next) ref.controller.state = null;
  });
  return null;
});
