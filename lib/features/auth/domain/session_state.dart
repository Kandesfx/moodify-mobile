import '../../../core/errors/app_failure.dart';
import 'auth_session.dart';

enum SessionPhase { restoring, restoreFailed, signedOut, signedIn }

class SessionState {
  const SessionState({
    this.phase = SessionPhase.restoring,
    this.session,
    this.isBusy = false,
    this.failure,
    this.notice,
    this.offlineUserId,
  });
  final SessionPhase phase;
  final AuthSession? session;
  final bool isBusy;
  final AppFailure? failure;
  final String? notice;
  // Identity scope only; never treats a cached profile as server-verified.
  final String? offlineUserId;

  SessionState withFeedback({
    bool? busy,
    AppFailure? failure,
    String? notice,
  }) => SessionState(
    phase: phase,
    session: session,
    isBusy: busy ?? isBusy,
    failure: failure,
    notice: notice,
    offlineUserId: offlineUserId,
  );
}
