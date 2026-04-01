enum NetworkErrorType { noInternet, timeout, connectionError }

sealed class AppException implements Exception {
  const AppException();
  String get userMessage;
}

final class NetworkException extends AppException {
  final NetworkErrorType type;
  final dynamic cause;
  const NetworkException(this.type, {this.cause});

  @override
  String get userMessage => switch (type) {
        NetworkErrorType.noInternet => 'No internet connection.',
        NetworkErrorType.timeout => 'Request timed out. Please try again.',
        NetworkErrorType.connectionError => 'Could not reach the server.',
      };

  @override
  String toString() => 'NetworkException(${type.name})';
}

class HttpException extends AppException {
  final int statusCode;
  final dynamic body;
  const HttpException(this.statusCode, this.body);

  @override
  String get userMessage => 'Something went wrong (HTTP $statusCode).';

  @override
  String toString() => 'HttpException($statusCode)';
}

final class AuthException extends HttpException {
  final bool canRefresh;
  const AuthException(super.statusCode, super.body, {this.canRefresh = false});

  @override
  String get userMessage =>
      canRefresh ? 'Session expired. Please log in again.' : 'Access denied.';
}

final class ValidationException extends HttpException {
  final Map<String, List<String>> fieldErrors;

  ValidationException(super.statusCode, super.body, this.fieldErrors);

  /// Parses DRF-style errors: {"email": ["already exists"], "non_field_errors": ["..."]}
  factory ValidationException.fromDRF(int statusCode, dynamic body) {
    final Map<String, List<String>> errors = {};
    if (body is Map) {
      body.forEach((key, value) {
        if (value is List) {
          errors[key.toString()] = value.map((e) => e.toString()).toList();
        } else if (value is String) {
          errors[key.toString()] = [value];
        }
      });
    }
    return ValidationException(statusCode, body, errors);
  }

  String get firstError =>
      fieldErrors.values.firstOrNull?.firstOrNull ?? 'Validation error.';

  @override
  String get userMessage => firstError;
}

final class ServerException extends HttpException {
  const ServerException(super.statusCode, super.body);

  @override
  String get userMessage => 'Server error. Please try again later.';
}

final class ParseException extends AppException {
  final String detail;
  final dynamic cause;
  const ParseException(this.detail, {this.cause});

  @override
  String get userMessage => 'Failed to process server response.';

  @override
  String toString() => 'ParseException: $detail';
}

final class RequestCancelledException extends AppException {
  const RequestCancelledException();

  @override
  String get userMessage => 'Request was cancelled.';
}
