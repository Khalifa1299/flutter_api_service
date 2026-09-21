import 'package:api_service/connectivity_service.dart';
import 'package:api_service/interceptors/connectivity_interceptors.dart';
import 'package:api_service/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

class NetworkClient {
  late final Dio dio;

  NetworkClient(
    ITokenStorage tokenStorage,
    ConnectivityService connectivity, {
    List<Interceptor> extraInterceptors = const [],
    Map<String, String> defaultHeaders = const {},
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        contentType: 'application/json',
        responseType: ResponseType.json,
        headers: defaultHeaders,
      ),
    );

    // Plain Dio for refresh calls (no interceptors — avoids infinite loop)
    // Must have its own timeouts — a hung refresh freezes the entire QueuedInterceptorsWrapper queue.
    final refreshDio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
    ));

    dio.interceptors.addAll([
      ConnectivityInterceptor(connectivity),
      AuthInterceptor(tokenStorage, refreshDio),
      RetryInterceptor(dio),
      if (kDebugMode) LoggingInterceptor(),
      ...extraInterceptors,
    ]);
  }
}
