# api_service

A production-grade, reusable Flutter network layer built on [Dio](https://pub.dev/packages/dio).
Drop it into any Flutter project as a local path dependency and get a fully wired HTTP client in minutes.

---

## Features

- **Dio-based** — full interceptor chain, cancel tokens, multipart uploads
- **Auth interceptor** — automatically injects the access token; on 401 silently refreshes the token and replays the original request; on refresh failure clears storage and rejects
- **Retry interceptor** — exponential back-off retries for network errors and 5xx responses (configurable count & delay)
- **Connectivity interceptor** — pre-flight check before every request; rejects immediately with `NetworkException` instead of waiting for a timeout
- **Logging interceptor** — pretty-prints every request/response with elapsed time; active only in debug mode; redacts the `Authorization` header
- **Secure token storage** — access & refresh tokens stored via `flutter_secure_storage` (Android Keystore / iOS Keychain)
- **Sealed `Result<T>` type** — `Success<T>` / `Failure<T>` — no raw try/catch needed in repositories
- **`PaginatedResult<T>`** — wraps paginated list responses with `hasNextPage`, `totalPages`
- **Rich exception hierarchy** — `NetworkException`, `HttpException`, `AuthException`, `ValidationException` (parses DRF field errors), `ServerException`, `ParseException`, `RequestCancelledException`
- **Response envelope normalisation** — handles `{success, data}`, `{count, results}`, and raw object/array responses automatically
- **Environment-aware base URL** — configured via `--dart-define=API_BASE_URL=https://api.example.com`
- **Legacy `ApiResponse<T>` shim** — backward-compatible wrapper so existing API service subclasses need zero changes

---

## Getting started

Add to your app's `pubspec.yaml`:

```yaml
dependencies:
  api_service:
    path: ../api_service   # adjust relative path as needed
```

Run:
```bash
flutter pub get
```

---

## Usage

### 1. Extend `BaseApiService`

```dart
class ProductApiService extends BaseApiService {
  ProductApiService() : super(NetworkClient(SecureTokenStorage(), ConnectivityService()));

  Future<Result<List<Product>>> getProducts() {
    return get('/api/products/', fromJson: (json) =>
      (json as List).map((e) => Product.fromJson(e)).toList(),
    );
  }
}
```

### 2. Use `Result<T>` in repositories

```dart
final result = await _api.getProducts();

result.fold(
  onSuccess: (products) => emit(ProductsLoaded(products)),
  onFailure: (e) => emit(ProductsError(e.userMessage)),
);
```

### 3. Handle validation errors (DRF field errors)

```dart
if (e is ValidationException) {
  final emailError = e.fieldErrors['email']?.first;
}
```

### 4. Configure base URL per environment

```bash
flutter run --dart-define=API_BASE_URL=https://staging.api.example.com
```

---

## Package structure

```
lib/
├── api_service.dart              # Barrel export
├── api_config.dart               # Base URL, timeouts, retry config
├── api_exception.dart            # Sealed exception hierarchy
├── api_response.dart             # Result<T>, PaginatedResult<T>, ApiResponse<T>
├── base_api_service.dart         # Abstract base — get/post/put/patch/delete/upload
├── network_client.dart           # Dio instance + interceptor wiring
├── token_storage.dart            # ITokenStorage interface + SecureTokenStorage impl
├── connectivity_service.dart     # Network connectivity checker
├── logger.dart                   # Shared logger instance
└── interceptors/
    ├── auth_interceptor.dart
    ├── retry_interceptor.dart
    ├── logging_interceptor.dart
    └── connectivity_interceptors.dart
```

---

## Dependencies

| Package | Purpose |
|---|---|
| `dio` | HTTP client |
| `flutter_secure_storage` | Encrypted token storage |
| `connectivity_plus` | Network status detection |
| `logger` | Debug logging |
