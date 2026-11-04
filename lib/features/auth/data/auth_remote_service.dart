import 'package:dio/dio.dart';

import '../domain/auth_session.dart';
import '../domain/registration.dart';
import 'device_identity.dart';

class AuthRemoteService {
  const AuthRemoteService(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> login(
    String identifier,
    String password,
    DeviceIdentity device,
    CancelToken cancel,
  ) async => _object(
    await _dio.post<dynamic>(
      'auth/login',
      data: {
        'identifier': identifier.trim(),
        'password': password,
        ...device.toJson(),
      },
      cancelToken: cancel,
    ),
  );

  Future<Map<String, dynamic>> register(
    Registration input,
    CancelToken cancel,
  ) async => _object(
    await _dio.post<dynamic>(
      'auth/register',
      data: input.toJson(),
      cancelToken: cancel,
    ),
  );

  Future<Map<String, dynamic>> refresh(
    String refreshToken,
    CancelToken cancel,
  ) async => _object(
    await _dio.post<dynamic>(
      'auth/refresh',
      data: {'refreshToken': refreshToken},
      cancelToken: cancel,
    ),
  );

  Future<UserProfile> profile(
    String accessToken,
    DeviceIdentity device,
    CancelToken cancel,
  ) async => UserProfile.fromJson(
    _object(
      await _dio.get<dynamic>(
        'auth/me',
        options: _options(accessToken, device),
        cancelToken: cancel,
      ),
    ),
  );

  Future<void> registerDevice(
    String accessToken,
    DeviceIdentity device,
    CancelToken cancel,
  ) async {
    await _dio.post<dynamic>(
      'auth/devices/register',
      data: device.toJson(),
      options: _options(accessToken, device),
      cancelToken: cancel,
    );
  }

  Future<void> logout(String accessToken) async {
    await _dio.post<void>(
      'auth/logout',
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
  }

  Options _options(String token, DeviceIdentity device) => Options(
    headers: {'Authorization': 'Bearer $token', 'X-Device-Uuid': device.uuid},
  );

  Map<String, dynamic> _object(Response<dynamic> response) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }
    return data;
  }
}
