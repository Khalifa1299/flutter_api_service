# api_service — Flutter HTTP Network Layer
## Technical Documentation

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Technology Stack](#technology-stack)
3. [Architecture](#architecture)
4. [Project Structure](#project-structure)
5. [Interceptor Chain](#interceptor-chain)
6. [Error Handling](#error-handling)
7. [Result Type](#result-type)
8. [Pagination](#pagination)
9. [Usage as Dependency](#usage-as-dependency)

---

## Project Overview

**api_service** is a production-grade, reusable Flutter network layer built on top of the Dio HTTP client. It is designed to be consumed as a local path dependency by other Flutter projects in the ecosystem (e.g., `auth_framework`, `admin_dashboard`).

| Property | Value |
|----------|-------|
| **Type** | Dart package (local dependency) |
| **Dart SDK** | ^3.10.4 |
| **Primary Dependency** | Dio ^5.9.2 |

### Problem Solved
Every Flutter app in the ecosystem needs consistent HTTP behavior: token refresh on 401, retry on network errors, connectivity checks before requests, and safe error handling. `api_service` provides all of this in one shared package so each app doesn't reimplement it.

---

## Technology Stack

| Technology | Version | Role |
|-----------|---------|------|
| **Dart** | ^3.10.4 | Language |
| **Dio** | ^5.9.2 | HTTP client |
| **flutter_secure_storage** | ^10.0.0 | Token persistence (Keystore/Keychain) |
| **connectivity_plus** | ^7.1.0 | Network state detection |
| **logger** | ^2.6.1 | Structured debug logging |

---

## Architecture

```
Caller (Repository / UseCase)
        │
        ▼
  ApiService (Dio client)
        │
        ├── ConnectivityInterceptor   ← pre-flight: abort if offline
        ├── AuthInterceptor           ← attach Bearer token, refresh on 401
        ├── RetryInterceptor          ← retry on transient errors / 5xx
        └── LoggingInterceptor        ← debug-only, redacts Authorization
        │
        ▼
  Remote Server (REST API)
        │
        ▼
  ResponseEnvelope normalizer
        │
        ▼
  Result<T> (Success | Failure)
```

### Design Principles
- **Interceptor chain** handles cross-cutting concerns transparently.
- **Sealed `Result<T>`** forces callers to handle both success and failure paths.
- **No business logic** — the package only handles transport and parsing.

---

## Project Structure

```
api_service/
├── lib/
│   ├── api_service.dart              # Public barrel export
│   ├── api_client.dart               # Dio instance factory & interceptor wiring
│   ├── result.dart                   # Sealed Result<T> type (Success / Failure)
│   ├── paginated_result.dart         # PaginatedResult<T> wrapper
│   ├── exceptions/
│   │   └── api_exceptions.dart       # Exception hierarchy
│   └── interceptors/
│       ├── auth_interceptor.dart     # Token attachment + 401 refresh
│       ├── retry_interceptor.dart    # Exponential backoff retry
│       ├── connectivity_interceptor.dart
│       └── logging_interceptor.dart
├── test/
└── pubspec.yaml
```

---

## Interceptor Chain

### AuthInterceptor
- Reads the stored JWT access token from `flutter_secure_storage` and attaches it as `Authorization: Bearer <token>`.
- On a **401** response, attempts a silent token refresh, retries the original request once, then emits `AuthException` if refresh also fails.

### RetryInterceptor
- Retries failed requests using **exponential backoff**.
- Triggered by: network errors (`DioExceptionType.connectionError`) and 5xx server responses.
- Does **not** retry 4xx client errors (except 401 which is handled by `AuthInterceptor`).

### ConnectivityInterceptor
- Uses `connectivity_plus` to check network availability **before** dispatching each request.
- Immediately rejects with `NetworkException` if the device is offline, avoiding unnecessary timeouts.

### LoggingInterceptor
- Active in **debug builds only** (`kDebugMode`).
- Logs request method, URL, headers (redacting the `Authorization` value), body, response status, and response body.

---

## Error Handling

All exceptions extend a sealed `ApiException` base class:

| Exception | Trigger |
|-----------|---------|
| `NetworkException` | No connectivity / connection error |
| `HttpException` | 4xx responses (non-auth) |
| `AuthException` | 401 after failed token refresh |
| `ValidationException` | 422 validation errors from server |
| `ServerException` | 5xx responses after retries exhausted |
| `ParseException` | JSON deserialization failure |
| `RequestCancelledException` | Request cancelled via CancelToken |

---

## Result Type

```dart
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final ApiException exception;
  const Failure(this.exception);
}
```

Callers use pattern matching:
```dart
switch (result) {
  case Success(:final data) => // handle data
  case Failure(:final exception) => // handle error
}
```

---

## Pagination

`PaginatedResult<T>` wraps list responses that include pagination metadata:

```dart
class PaginatedResult<T> {
  final List<T> items;
  final int count;       // total items available
  final String? next;    // URL of next page (null if last)
  final String? previous;
}
```

The response normalizer handles three envelope shapes: `{success, data}`, `{count, results}`, and raw JSON arrays/objects.

---

## Usage as Dependency

Add to `pubspec.yaml`:
```yaml
dependencies:
  api_service:
    path: ../api_service
```

Initialize and inject:
```dart
final apiClient = ApiClient(
  baseUrl: 'https://api.example.com',
  tokenStorage: SecureTokenStorage(),
);
```
