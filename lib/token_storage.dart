import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ITokenStorage {
  Future<void> saveAccessToken(String token);
  Future<void> saveRefreshToken(String token);
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<bool> hasToken();
  Future<void> clearAll();
}

/// Hybrid token storage applying the correct security strategy per token type:
///
/// - **Access token** → in-memory only.
///   Short-lived (~5–15 min), never written to disk. Cleared automatically
///   when the process is killed. On cold start [getAccessToken] returns null,
///   causing [AuthInterceptor] to silently refresh before retrying the request.
///
/// - **Refresh token** → encrypted persistent storage (Android Keystore / iOS Keychain).
///   Long-lived, must survive app restarts and process kills.
class SecureTokenStorage implements ITokenStorage {
  static const _refreshKey = 'refresh_token';

  /// In-memory access token — never written to disk.
  String? _accessToken;

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Stores the access token in memory only — no disk I/O.
  @override
  Future<void> saveAccessToken(String token) async {
    _accessToken = token;
  }

  /// Returns the in-memory access token.
  /// Returns `null` on cold start — [AuthInterceptor] will trigger a silent refresh.
  @override
  Future<String?> getAccessToken() async => _accessToken;

  /// Persists the refresh token to encrypted storage (Keystore / Keychain).
  @override
  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshKey, value: token);

  /// Reads the refresh token from encrypted storage.
  @override
  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  /// Returns true when the user has an active session:
  /// either an in-memory access token OR a persisted refresh token is present.
  @override
  Future<bool> hasToken() async {
    if (_accessToken != null && _accessToken!.isNotEmpty) return true;
    final refresh = await _storage.read(key: _refreshKey);
    return refresh != null && refresh.isNotEmpty;
  }

  /// Clears the in-memory access token and deletes the persisted refresh token.
  @override
  Future<void> clearAll() async {
    _accessToken = null;
    await _storage.delete(key: _refreshKey);
  }
}
