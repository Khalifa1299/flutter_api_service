class ApiConfig {
  ApiConfig._();
  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://mostafakhalifa.cloud');

  static const Duration timeout = Duration(seconds: 15);
  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const int maxRetries = 1;
  static const int retryBaseDelayMs = 300;
  static const String tokenRefreshEndpoint = '/api/auth/token/refresh/';
}
