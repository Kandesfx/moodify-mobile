import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../errors/app_failure.dart';
import 'authorized_session.dart';

class SessionInterceptor extends Interceptor {
  SessionInterceptor(this._dio, this._session, this._config);
  final Dio _dio;
  final AuthorizedSession _session;
  final AppConfig _config;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final scope = _session.generation;
    try {
      if (!_config.contains(options.uri)) {
        throw const AppFailure(
          'Yêu cầu nằm ngoài API được cấu hình.',
          code: 'ORIGIN',
        );
      }
      final token = await _session.accessToken();
      final device = await _session.deviceUuid();
      if (scope != _session.generation) throw AppFailure.sessionChanged;
      options.headers['Authorization'] = 'Bearer $token';
      options.headers['X-Device-Uuid'] = device;
      options.extra['sessionGeneration'] = scope;
      options.extra['sessionToken'] = token;
      options.cancelToken ??= _session.cancelToken;
      handler.next(options);
    } catch (error) {
      handler.reject(_exception(options, AppFailure.from(error)));
    }
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (response.requestOptions.extra['sessionGeneration'] !=
        _session.generation) {
      handler.reject(
        _exception(response.requestOptions, AppFailure.sessionChanged),
      );
    } else {
      handler.next(response);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (options.extra['sessionGeneration'] != null &&
        options.extra['sessionGeneration'] != _session.generation) {
      handler.next(_exception(options, AppFailure.sessionChanged));
      return;
    }
    final failure = AppFailure.from(err);
    if (failure.code == 'DEVICE_REVOKED') {
      await _session.expire(failure.message);
      handler.next(err);
      return;
    }
    if (err.response?.statusCode != 401 ||
        options.extra['authRetried'] == true) {
      // A retried 401 is terminal; never loop refresh on login/refresh or forbidden responses.
      if (err.response?.statusCode == 401 &&
          options.extra['authRetried'] == true) {
        await _session.expire(
          'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
        );
      }
      handler.next(err);
      return;
    }
    final scope = _session.generation;
    try {
      await _session.refreshAccessToken(
        failedToken: options.extra['sessionToken'] as String?,
      );
      if (scope != _session.generation) throw AppFailure.sessionChanged;
      final response = await _dio.fetch<dynamic>(
        options.copyWith(extra: {...options.extra, 'authRetried': true}),
      );
      handler.resolve(response);
    } catch (refreshError) {
      handler.next(_exception(options, AppFailure.from(refreshError)));
    }
  }

  DioException _exception(RequestOptions options, AppFailure failure) =>
      DioException(
        requestOptions: options,
        error: failure,
        type: failure.code == 'SESSION_CHANGED'
            ? DioExceptionType.cancel
            : DioExceptionType.unknown,
      );
}
