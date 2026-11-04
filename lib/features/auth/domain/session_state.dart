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
  });
  final SessionPhase phase;
  final AuthSession? session;
  final bool isBusy;
  final AppFailure? failure;
  final String? notice;

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
  );
}
