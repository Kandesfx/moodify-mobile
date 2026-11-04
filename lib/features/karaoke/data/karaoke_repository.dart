import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../../core/errors/app_failure.dart';

final karaokeRepositoryProvider = Provider<KaraokeRepository>(
  (ref) => KaraokeRepository(ref.watch(apiDioProvider)),
);

class KaraokeRepository {
  KaraokeRepository(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> tracks({String query = ''}) async {
    final response = await _dio.get<Object?>(
      'karaoke/tracks',
      queryParameters: {
        'page': 0,
        'size': 40,
        if (query.trim().isNotEmpty) 'query': query.trim(),
      },
    );
    final body = _map(response.data);
    final rows = body['content'];
    if (rows is! List) {
      throw const FormatException('Danh sách karaoke không hợp lệ.');
    }
    return rows.map(_map).toList(growable: false);
  }

  Future<Map<String, dynamic>> track(String id) async => _map(
    (await _dio.get<Object?>('karaoke/tracks/${Uri.encodeComponent(id)}')).data,
  );

  Future<Map<String, dynamic>> startSession(String songId) async => _map(
    (await _dio.post<Object?>(
      'karaoke/tracks/${Uri.encodeComponent(songId)}/sessions',
    )).data,
  );

  Future<Map<String, dynamic>> pitchReference(String sessionId) async => _map(
    (await _dio.get<Object?>(
      'karaoke/sessions/${Uri.encodeComponent(sessionId)}/pitch-reference',
    )).data,
  );

  Future<Map<String, dynamic>> submitPitchFeatures(
    String sessionId,
    Map<String, dynamic> features,
  ) async => _map(
    (await _dio.post<Object?>(
      'karaoke/sessions/${Uri.encodeComponent(sessionId)}/score/features',
      data: features,
    )).data,
  );

  Future<List<Map<String, dynamic>>> rooms() async {
    final response = await _dio.get<Object?>('karaoke/rooms');
    if (response.data is! List) {
      throw const FormatException('Danh sách phòng không hợp lệ.');
    }
    return (response.data as List).map(_map).toList(growable: false);
  }

  Future<Map<String, dynamic>> createRoom({
    required String name,
    required bool isPrivate,
  }) async => _map(
    (await _dio.post<Object?>(
      'karaoke/rooms',
      data: {
        'name': name,
        'maxMembers': 6,
        'visibility': isPrivate ? 'PRIVATE' : 'PUBLIC',
      },
    )).data,
  );

  Future<Map<String, dynamic>> joinRoom(int id, {String? inviteCode}) async =>
      _map(
        (await _dio.post<Object?>(
          'karaoke/rooms/$id/join',
          data: {
            if (inviteCode != null && inviteCode.trim().isNotEmpty)
              'inviteCode': inviteCode.trim(),
          },
        )).data,
      );

  Future<Map<String, dynamic>> room(int id) async =>
      _map((await _dio.get<Object?>('karaoke/rooms/$id')).data);

  Future<void> leaveRoom(int id) async =>
      _dio.post<void>('karaoke/rooms/$id/leave');

  Future<void> addQueue(int id, String trackId) async =>
      _dio.post<void>('karaoke/rooms/$id/queue', data: {'trackId': trackId});

  Future<void> removeQueue(int id, int itemId) async =>
      _dio.delete<void>('karaoke/rooms/$id/queue/$itemId');

  Future<void> closeRoom(int id) async =>
      _dio.post<void>('karaoke/rooms/$id/close');

  Future<Map<String, dynamic>> voiceTicket(int id) async =>
      _map((await _dio.post<Object?>('karaoke/rooms/$id/voice-ticket')).data);

  Future<void> playback(int id, String command, int version) async =>
      _dio.post<void>(
        'karaoke/rooms/$id/playback/$command',
        data: {'expectedVersion': version},
      );

  Future<Map<String, dynamic>> startRoomScoreSession(int roomId) async => _map(
    (await _dio.post<Object?>(
      'karaoke/rooms/$roomId/score-sessions/current',
    )).data,
  );

  Future<Map<String, dynamic>> registerRoomScoreParticipant(
    int roomId,
    String sessionId,
  ) async => _map(
    (await _dio.post<Object?>(
      'karaoke/rooms/$roomId/score-sessions/${Uri.encodeComponent(sessionId)}/participants/me',
    )).data,
  );

  Future<Map<String, dynamic>> submitRoomScoreContribution({
    required int roomId,
    required String sessionId,
    required List<Map<String, dynamic>> segments,
  }) async => _map(
    (await _dio.put<Object?>(
      'karaoke/rooms/$roomId/score-sessions/${Uri.encodeComponent(sessionId)}/contribution',
      data: {'segments': segments},
    )).data,
  );

  Future<Map<String, dynamic>> finishRoomScoreSession(
    int roomId,
    String sessionId,
  ) async => _map(
    (await _dio.post<Object?>(
      'karaoke/rooms/$roomId/score-sessions/${Uri.encodeComponent(sessionId)}/finish',
    )).data,
  );

  Future<Map<String, dynamic>> roomScoreSession(
    int roomId,
    String sessionId,
  ) async => _map(
    (await _dio.get<Object?>(
      'karaoke/rooms/$roomId/score-sessions/${Uri.encodeComponent(sessionId)}',
    )).data,
  );
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException('Dữ liệu karaoke không hợp lệ.');
}

String karaokeError(Object error) => AppFailure.from(error).message;
