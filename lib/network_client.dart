import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'interceptors/connectivity_interceptors.dart';
import 'token_storage.dart';
import 'connectivity_service.dart';
import 'api_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

class NetworkClient {
  late final Dio dio;

  NetworkClient(ITokenStorage tokenStorage, ConnectivityService connectivity) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        contentType: 'application/json',
        responseType: ResponseType.json,
      ),
    );

    // Plain Dio for refresh calls (no interceptors — avoids infinite loop)
    final refreshDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

    dio.interceptors.addAll([
      ConnectivityInterceptor(connectivity),
      AuthInterceptor(tokenStorage, refreshDio),
      RetryInterceptor(dio),
      if (kDebugMode) LoggingInterceptor(),
    ]);
  }
}
