import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../logger.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      options.extra['_startTime'] = DateTime.now().millisecondsSinceEpoch;
      final headers = Map<String, dynamic>.from(options.headers);
      if (headers.containsKey('Authorization')) {
        headers['Authorization'] = 'Token [redacted]';
      }
      logger.d(
        '→ ${options.method} ${options.uri}\n'
        '  Headers: $headers\n'
        '  Body: ${_truncate(options.data)}',
      );
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final start = response.requestOptions.extra['_startTime'] as int?;
      final elapsed = start != null
          ? '${DateTime.now().millisecondsSinceEpoch - start}ms'
          : '?ms';
      logger.d(
        '← ${response.statusCode} ${response.requestOptions.uri} [$elapsed]\n'
        '  Body: ${_truncate(response.data)}',
      );
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      logger.e(
        '✕ ${err.requestOptions.method} ${err.requestOptions.uri}\n'
        '  ${err.type.name}: ${err.message}',
      );
    }
    super.onError(err, handler);
  }

  String _truncate(dynamic data, {int maxLength = 500}) {
    final s = data?.toString() ?? 'null';
    return s.length > maxLength ? '${s.substring(0, maxLength)}…' : s;
  }
}
