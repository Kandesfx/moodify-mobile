import 'package:dio/dio.dart';

import '../config/app_config.dart';

Dio createDio(AppConfig config) => Dio(
  BaseOptions(
    baseUrl: config.apiBaseUri.toString(),
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 20),
    followRedirects: false,
    headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
  ),
);
