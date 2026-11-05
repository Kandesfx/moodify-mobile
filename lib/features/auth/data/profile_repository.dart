import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../domain/auth_session.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiDioProvider)),
);

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  Future<UserProfile> update({
    required String fullName,
    required String phone,
  }) async {
    final response = await _dio.patch<Object?>(
      'auth/me',
      data: {'fullName': fullName, 'phone': phone},
    );
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile');
    }
    return UserProfile.fromJson(body);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _dio.post<Object?>(
      'auth/change-password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    final body = response.data;
    if (body is! Map<String, dynamic> || body['success'] != true) {
      throw const FormatException('Invalid change-password response');
    }
  }
}
