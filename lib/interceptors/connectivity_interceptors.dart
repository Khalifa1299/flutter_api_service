import 'package:api_service/api_exception.dart';
import 'package:api_service/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

class ConnectivityInterceptor extends Interceptor {
  final ConnectivityService _connectivity;
  ConnectivityInterceptor(this._connectivity);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final connectivityResult = await _connectivity.checkConnectivity();
    final isConnected = connectivityResult != ConnectivityResult.none;

    if (!isConnected) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: const NetworkException(NetworkErrorType.noInternet),
        ),
        true,
      );
    }
    super.onRequest(options, handler);
  }
}
