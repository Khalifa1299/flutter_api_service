import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../api_exception.dart';
import '../connectivity_service.dart';

class ConnectivityInterceptor extends Interceptor {
  final ConnectivityService _connectivity;
  ConnectivityInterceptor(this._connectivity);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
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
