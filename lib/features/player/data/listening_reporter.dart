import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../app/bootstrap.dart';
import '../../auth/presentation/session_controller.dart';

final listeningReporterProvider = Provider<ListeningReporter?>((ref) {
  final user = ref.watch(
    sessionControllerProvider.select((s) => s.session?.user.id),
  );
  if (user == null) return null;
  final reporter = ListeningReporter(
    ref.watch(apiDioProvider),
    kIsWeb
        ? 'WEB'
        : defaultTargetPlatform == TargetPlatform.android
        ? 'ANDROID'
        : defaultTargetPlatform == TargetPlatform.iOS
        ? 'IOS'
        : 'OTHER',
  );
  ref.onDispose(reporter.dispose);
  return reporter;
});

typedef ListeningEvent = ({
  int generation,
  String trackId,
  String event,
  int positionMs,
  int targetPositionMs,
  String source,
});

/// Receives native playback observations, never synthetic elapsed listening time.
class ListeningReporter {
  ListeningReporter(this.dio, this.deviceType);
  final Dio dio;
  final String deviceType;
  Future<void> _serial = Future.value();
  int? _generation;
  String? _key;
  bool _terminal = false, _disposed = false;
  int _pending = 0;
  void record(ListeningEvent event) {
    if (_disposed) return;
    if (_generation != event.generation) {
      if (event.event != 'PLAY') return;
      _generation = event.generation;
      _key = const Uuid().v4();
      _terminal = false;
    }
    if (_terminal ||
        _key == null ||
        (_pending >= 8 && event.event == 'HEARTBEAT')) {
      return;
    }
    final body = <String, dynamic>{
      'trackId': event.trackId,
      'sessionKey': _key,
      'eventType': event.event,
      'positionMs': event.positionMs,
      'targetPositionMs': event.targetPositionMs,
      'source': event.source,
      'deviceType': deviceType,
    };
    if ({
      'COMPLETE',
      'TRACK_CHANGED',
      'PLAYBACK_STOPPED',
      'SKIP_NEXT',
      'SKIP_PREVIOUS',
    }.contains(event.event)) {
      _terminal = true;
    }
    _pending++;
    _serial = _serial.then((_) async {
      try {
        if (!_disposed) {
          final response = await dio.post<Object?>(
            'analytics/listening-session',
            data: body,
          );
          if (kDebugMode) {
            debugPrint(
              'Listening observation: ${event.event} HTTP ${response.statusCode}, accepted=${response.data is Map ? (response.data as Map)['success'] : 'unknown'}',
            );
          }
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            'Listening observation failed: ${event.event}, HTTP ${error is DioException ? error.response?.statusCode : 'unknown'}',
          );
        }
        /* No replay or fabricated listening after a failed observation. */
      } finally {
        _pending--;
      }
    });
    unawaited(_serial);
  }

  Future<void> get settled => _serial;
  void dispose() {
    _disposed = true;
    _key = null;
  }
}
