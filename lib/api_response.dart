import 'api_exception.dart';

// ─── Result<T> ───────────────────────────────────────────────────────────────

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T get dataOrThrow {
    final self = this;
    if (self is Success<T>) return self.data;
    throw (this as Failure<T>).exception;
  }

  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(AppException error) onFailure,
  }) {
    final self = this;
    if (self is Success<T>) return onSuccess(self.data);
    return onFailure((self as Failure<T>).exception);
  }

  /// Transform the data type if successful.
  Result<U> map<U>(U Function(T) transform) {
    final self = this;
    if (self is Success<T>) {
      return Success(transform(self.data),
          message: self.message, statusCode: self.statusCode);
    }
    return Failure((self as Failure<T>).exception);
  }
}

final class Success<T> extends Result<T> {
  final T data;
  final String? message;
  final int? statusCode;

  const Success(this.data, {this.message, this.statusCode});
}

final class Failure<T> extends Result<T> {
  final AppException exception;
  const Failure(this.exception);
}

// ─── PaginatedResult<T> ──────────────────────────────────────────────────────

class PaginatedResult<T> {
  final List<T> items;
  final int count;
  final String? next;
  final String? previous;
  final int pageSize;

  const PaginatedResult({
    required this.items,
    required this.count,
    this.next,
    this.previous,
    this.pageSize = 10,
  });

  bool get hasNextPage => next != null;
  bool get hasPreviousPage => previous != null;
  int get totalPages => pageSize > 0 ? (count / pageSize).ceil() : 0;
}

// ─── Legacy ApiResponse<T> — kept for backward compatibility ─────────────────

class ApiResponse<T> {
  final T? data;
  final String? message;
  final bool success;
  final int? statusCode;

  const ApiResponse({
    this.data,
    this.message,
    required this.success,
    this.statusCode,
  });

  factory ApiResponse.success(T data, {String? message, int? statusCode}) =>
      ApiResponse(
          data: data, message: message, success: true, statusCode: statusCode);

  factory ApiResponse.error(String message, {int? statusCode}) =>
      ApiResponse(message: message, success: false, statusCode: statusCode);
}
