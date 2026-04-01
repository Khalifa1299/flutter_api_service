import 'dart:io';
import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'api_response.dart';
import 'network_client.dart';

abstract class BaseApiService {
  final NetworkClient networkClient;
  BaseApiService(this.networkClient);

  Dio get _dio => networkClient.dio;

  // ── Core request methods ──────────────────────────────────────────────────

  Future<Result<T>> get<T>(
    String path, {
    T Function(dynamic)? fromJson,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
  }) =>
      _request('GET', path,
          fromJson: fromJson,
          queryParams: queryParams,
          cancelToken: cancelToken);

  Future<Result<T>> post<T>(
    String path, {
    dynamic body,
    T Function(dynamic)? fromJson,
    CancelToken? cancelToken,
  }) =>
      _request('POST', path,
          body: body, fromJson: fromJson, cancelToken: cancelToken);

  Future<Result<T>> put<T>(
    String path, {
    dynamic body,
    T Function(dynamic)? fromJson,
    CancelToken? cancelToken,
  }) =>
      _request('PUT', path,
          body: body, fromJson: fromJson, cancelToken: cancelToken);

  Future<Result<T>> patch<T>(
    String path, {
    dynamic body,
    T Function(dynamic)? fromJson,
    CancelToken? cancelToken,
  }) =>
      _request('PATCH', path,
          body: body, fromJson: fromJson, cancelToken: cancelToken);

  Future<Result<T>> delete<T>(
    String path, {
    T Function(dynamic)? fromJson,
    CancelToken? cancelToken,
  }) =>
      _request('DELETE', path, fromJson: fromJson, cancelToken: cancelToken);

  /// Multipart file upload with optional progress callback.
  Future<Result<T>> upload<T>(
    String path,
    FormData formData, {
    T Function(dynamic)? fromJson,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: formData,
        onSendProgress: onProgress,
        cancelToken: cancelToken,
      );
      return _parseResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return Failure(_mapDioException(e));
    } catch (e) {
      return Failure(ParseException(e.toString(), cause: e));
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<Result<T>> _request<T>(
    String method,
    String path, {
    dynamic body,
    T Function(dynamic)? fromJson,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.request(
        path,
        data: body,
        queryParameters: queryParams,
        cancelToken: cancelToken,
        options: Options(method: method),
      );
      return _parseResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return Failure(_mapDioException(e));
    } catch (e) {
      return Failure(ParseException(e.toString(), cause: e));
    }
  }

  Result<T> _parseResponse<T>(
      Response response, T Function(dynamic)? fromJson) {
    final statusCode = response.statusCode ?? 200;
    try {
      final normalized = _normalizeBody(response.data);
      if (fromJson != null) {
        return Success(fromJson(normalized), statusCode: statusCode);
      }
      return Success(normalized as T, statusCode: statusCode);
    } catch (e) {
      return Failure(ParseException('Failed to parse response: $e', cause: e));
    }
  }

  /// Normalizes the three Django response envelope formats.
  dynamic _normalizeBody(dynamic body) {
    if (body is Map) {
      // { success, data: {...|[...]} }
      if (body.containsKey('success') && body.containsKey('data')) {
        return body['data'];
      }
      // Paginated: { count, results: [...] }
      if (body.containsKey('results')) {
        return body; // caller handles PaginatedResult if needed
      }
    }
    return body;
  }

  AppException _mapDioException(DioException e) {
    if (e.error is AppException) return e.error as AppException;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(NetworkErrorType.timeout);
      case DioExceptionType.sendTimeout:
        return const NetworkException(NetworkErrorType.timeout);
      case DioExceptionType.connectionError:
        if (e.error is SocketException) {
          return const NetworkException(NetworkErrorType.noInternet);
        }
        return const NetworkException(NetworkErrorType.connectionError);
      case DioExceptionType.cancel:
        return const RequestCancelledException();
      case DioExceptionType.badResponse:
        return _mapHttpError(e.response!);
      default:
        return NetworkException(NetworkErrorType.connectionError, cause: e);
    }
  }

  AppException _mapHttpError(Response response) {
    final statusCode = response.statusCode!;
    final body = response.data;

    if (statusCode == 401)
      return AuthException(statusCode, body, canRefresh: true);
    if (statusCode == 403)
      return AuthException(statusCode, body, canRefresh: false);
    if (statusCode == 422 || statusCode == 400) {
      if (body is Map) return ValidationException.fromDRF(statusCode, body);
    }
    if (statusCode >= 500) return ServerException(statusCode, body);
    return HttpException(statusCode, body);
  }

  // ── Legacy helpers (kept for ApiService shim) ─────────────────────────────

  List<dynamic> parseResults(dynamic data) {
    if (data is Map && data.containsKey('results')) {
      final r = data['results'];
      return r is List ? r : [];
    }
    if (data is List) return data;
    if (data is Map) return [data];
    return [];
  }

  Map<String, String> buildQueryParams({
    int? page,
    int? pageSize,
    String? search,
    String? category,
    String? sortBy,
    String? sortOrder,
    String? status,
    bool? isResolved,
    double? minPrice,
    double? maxPrice,
    Map<String, dynamic>? additionalParams,
  }) {
    final q = <String, String>{};
    if (page != null) q['page'] = '$page';
    if (pageSize != null) q['page_size'] = '$pageSize';
    if (search != null) q['search'] = search;
    if (category != null) q['category'] = category;
    if (sortBy != null) q['sort_by'] = sortBy;
    if (sortOrder != null) q['sort_order'] = sortOrder;
    if (status != null) q['status'] = status;
    if (isResolved != null) q['is_resolved'] = '$isResolved';
    if (minPrice != null) q['min_price'] = '$minPrice';
    if (maxPrice != null) q['max_price'] = '$maxPrice';
    additionalParams?.forEach((k, v) {
      if (v != null) q[k] = '$v';
    });
    return q;
  }
}
