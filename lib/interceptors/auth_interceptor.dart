import 'package:dio/dio.dart';
import '../token_storage.dart';
import '../api_config.dart';
import '../api_exception.dart';

/// Uses QueuedInterceptorsWrapper so concurrent 401s are serialized —
/// only one refresh attempt runs; all others wait and then replay.
class AuthInterceptor extends QueuedInterceptorsWrapper {
  final ITokenStorage _storage;
  final Dio _dio; // a plain Dio instance (no interceptors) for refresh calls

  AuthInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Token $token';
    }
    super.onRequest(options, handler);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        await _storage.clearAll();
        return handler.reject(err);
      }

      try {
        final response = await _dio.post(
          '${ApiConfig.baseUrl}${ApiConfig.tokenRefreshEndpoint}',
          data: {'refresh': refreshToken},
        );
        final newAccess = response.data['access'] as String?;
        if (newAccess == null)
          throw Exception('No access token in refresh response');

        await _storage.saveAccessToken(newAccess);

        // Retry the original request with the new token
        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Token $newAccess';
        final retryResponse = await _dio.fetch(retryOptions);
        return handler.resolve(retryResponse);
      } catch (_) {
        await _storage.clearAll();
        // Optionally: fire an auth-expired event via GetIt / event bus here
        return handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: const AuthException(401, null, canRefresh: false),
            type: DioExceptionType.unknown,
          ),
        );
      }
    }
    super.onError(err, handler);
  }
}
