import 'dart:async';
import 'package:dio/dio.dart';
import '../api_config.dart';

class RetryInterceptor extends Interceptor {
  final Dio _dio;
  final int maxRetries;
  final int baseDelayMs;

  RetryInterceptor(
    this._dio, {
    this.maxRetries = ApiConfig.maxRetries,
    this.baseDelayMs = ApiConfig.retryBaseDelayMs,
  });

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final attempt = err.requestOptions.extra['_retryCount'] as int? ?? 0;

    final shouldRetry = attempt < maxRetries &&
        (err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout ||
            err.type == DioExceptionType.connectionError ||
            (err.response?.statusCode != null &&
                err.response!.statusCode! >= 500));

    if (!shouldRetry) return super.onError(err, handler);

    final delay = Duration(milliseconds: baseDelayMs * (1 << attempt));
    await Future.delayed(delay);

    err.requestOptions.extra['_retryCount'] = attempt + 1;
    try {
      final response = await _dio.fetch(err.requestOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      return super.onError(e, handler);
    }
  }
}
