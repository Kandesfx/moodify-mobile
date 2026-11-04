import 'package:dio/dio.dart';

/// Infrastructure depends on this capability, not on a feature implementation.
abstract interface class AuthorizedSession {
  int get generation;
  CancelToken get cancelToken;
  Future<String> accessToken();
  Future<String> refreshAccessToken({String? failedToken});
  Future<String> deviceUuid();
  Future<void> expire(String message);
}
