import 'package:api_service/token_storage.dart';
import 'package:dio/dio.dart';
import '../api_config.dart';
import '../api_exception.dart';

/// Uses [QueuedInterceptorsWrapper] so concurrent 401s are serialized.
///
/// Problem this solves:
///   Two requests get 401 simultaneously → both would refresh, but Django
///   rotates refresh tokens (ROTATE_REFRESH_TOKENS=True), so the second
///   refresh call uses an already-blacklisted token and returns 401.
///
/// Solution — two-phase handling:
///   Phase 1 (first queued 401): refresh runs, saves BOTH new access token
///   AND new refresh token, stores access in [_freshToken].
///   Phase 2 (subsequent queued 401s same cycle): [_freshToken] != null →
///   skip the refresh entirely, just retry with the cached fresh token.
///   [_freshToken] is cleared after a short window so the next real expiry
///   triggers a proper refresh again.
class AuthInterceptor extends QueuedInterceptorsWrapper {
  final ITokenStorage _storage;

  /// Plain Dio with no interceptors — avoids infinite 401 loop on the refresh
  /// call going back through the main interceptor chain.
  final Dio _refreshDio;

  AuthInterceptor(this._storage, this._refreshDio);

  String? _freshToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return super.onError(err, handler);
    }

    // Phase 2: another queued request already refreshed — reuse the token
    if (_freshToken != null) {
      return _retry(err.requestOptions, _freshToken!, handler);
    }

    // Phase 1: first 401 — perform the real token refresh
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _storage.clearAll();
      return handler.reject(_authExpiredError(err.requestOptions));
    }

    try {
      final response = await _refreshDio.post(
        '${ApiConfig.baseUrl}${ApiConfig.tokenRefreshEndpoint}',
        data: {'refresh': refreshToken},
      );

      final newAccess = response.data['access'] as String?;
      if (newAccess == null) throw Exception('Missing access token');

      await _storage.saveAccessToken(newAccess);

      // Save the rotated refresh token if Django returned one
      final newRefresh = response.data['refresh'] as String?;
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await _storage.saveRefreshToken(newRefresh);
      }

      _freshToken = newAccess;
      // Clear after a short window so the next real expiry triggers a fresh refresh
      Future.delayed(const Duration(seconds: 10), () => _freshToken = null);

      return _retry(err.requestOptions, newAccess, handler);
    } catch (_) {
      _freshToken = null;
      await _storage.clearAll();
      return handler.reject(_authExpiredError(err.requestOptions));
    }
  }

  Future<void> _retry(
    RequestOptions options,
    String token,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      options.headers['Authorization'] = 'Bearer $token';
      final response = await _refreshDio.fetch(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.reject(e);
    }
  }

  DioException _authExpiredError(RequestOptions options) => DioException(
        requestOptions: options,
        error: const AuthException(401, null, canRefresh: false),
        type: DioExceptionType.unknown,
      );
}
