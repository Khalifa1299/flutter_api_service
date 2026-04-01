class ApiConfig {
  ApiConfig._();
  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://192.168.100.2:8000');

  static const Duration timeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  static const int retryBaseDelayMs = 300;
  static const String tokenRefreshEndpoint = '/api/auth/token/refresh/';
}
