import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ITokenStorage {
  Future<void> saveAccessToken(String token);
  Future<void> saveRefreshToken(String token);
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<bool> hasToken();
  Future<void> clearAll();
}

class SecureTokenStorage implements ITokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true, // Use Keystore
      resetOnError: true, // Prevents crashes if Keystore is corrupted
    ),
    iOptions: IOSOptions(
      accessibility:
          KeychainAccessibility.first_unlock, // Secure but accessible
    ), // Prevents crashes if Keystore is corrupted),
  );

  @override
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessKey, value: token);

  @override
  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshKey, value: token);

  @override
  Future<String?> getAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<bool> hasToken() async {
    final t = await _storage.read(key: _accessKey);
    return t != null && t.isNotEmpty;
  }

  @override
  Future<void> clearAll() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
